import Foundation
import os

/// Service de detection des ports TCP en ecoute via lsof
/// Modele: wieandteduard/port-menu PortScanning.swift
final class PortScanner: Sendable {

    private static let allowedFallbackProcessNames: Set<String> = [
        "air", "beam.smp", "bun", "cargo", "deno", "dotnet", "elixir", "erl",
        "go", "gunicorn", "http-server", "java", "mix", "node", "npm", "parcel",
        "php", "puma", "python", "python3", "reflex", "ruby", "serve",
        "swift", "uvicorn", "vite", "webpack-dev-server"
    ]

    private static let ignoredDirNames = Set(["_build", "build", "tmp", "dist", "deps"])

    func scan() async -> [DevServer] {
        let output = await executeLsof()
        guard !output.isEmpty else { return [] }

        let parsed = parseLsofOutput(output)
        guard !parsed.isEmpty else { return [] }

        let pids = Set(parsed.map(\.pid))
        let cwds = await resolveCWDs(pids: pids)
        let startTimes = await resolveStartTimes(pids: pids)

        return resolveServers(parsed: parsed, cwds: cwds, startTimes: startTimes)
    }

    // MARK: - lsof Execution

    private func executeLsof() async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()
                let errPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
                process.arguments = ["-iTCP", "-sTCP:LISTEN", "-n", "-P"]
                process.standardOutput = pipe
                process.standardError = errPipe

                do {
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(returning: "")
                }
            }
        }
    }

    // MARK: - Column Parsing

    struct ParsedPort {
        let port: UInt16
        let pid: Int32
        let processName: String
    }

    func parseLsofOutput(_ output: String) -> [ParsedPort] {
        var seen = Set<UInt16>()
        var results: [ParsedPort] = []

        let lines = output.split(separator: "\n", omittingEmptySubsequences: true)
        for line in lines.dropFirst() {
            let cols = line.split(separator: " ", omittingEmptySubsequences: true)
            guard cols.count >= 9 else { continue }

            let processName = String(cols[0])
            guard let pid = Int32(cols[1]) else { continue }

            let nameCol = String(cols[cols.count - 2])
            let stateCol = String(cols[cols.count - 1])

            guard stateCol == "(LISTEN)" else { continue }

            guard let colonIdx = nameCol.lastIndex(of: ":"),
                  let port = UInt16(nameCol[nameCol.index(after: colonIdx)...])
            else { continue }

            guard port >= 1024, port < 49152 else { continue }
            guard seen.insert(port).inserted else { continue }

            results.append(ParsedPort(port: port, pid: pid, processName: processName))
        }

        return results.sorted { $0.port < $1.port }
    }

    // MARK: - CWD Resolution (batch)

    private func resolveCWDs(pids: Set<Int32>) async -> [Int32: String] {
        guard !pids.isEmpty else { return [:] }
        let pidList = pids.map(String.init).joined(separator: ",")

        guard let output = try? await runShell(
            "/usr/sbin/lsof", args: ["-a", "-p", pidList, "-d", "cwd", "-Fn"],
            timeout: 10
        ) else { return [:] }

        var result: [Int32: String] = [:]
        var currentPID: Int32?

        for line in output.split(separator: "\n") {
            if line.hasPrefix("p"), let pid = Int32(line.dropFirst()) {
                currentPID = pid
            } else if line.hasPrefix("n/"), let pid = currentPID {
                result[pid] = String(line.dropFirst())
            }
        }
        return result
    }

    // MARK: - Start Time Resolution (batch)

    private func resolveStartTimes(pids: Set<Int32>) async -> [Int32: Date] {
        guard !pids.isEmpty else { return [:] }
        let pidList = pids.map(String.init).joined(separator: ",")

        guard let output = try? await runShell(
            "/bin/ps", args: ["-p", pidList, "-o", "pid=,lstart="],
            timeout: 5,
            environment: ["LC_ALL": "C"]
        ) else { return [:] }

        var result: [Int32: Date] = [:]
        let strategy = Date.ParseStrategy(
            format: "\(weekday: .abbreviated) \(month: .abbreviated) \(day: .twoDigits) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits) \(year: .defaultDigits)",
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: .current
        )

        for line in output.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2, let pid = Int32(parts[0]) else { continue }
            let normalized = parts[1]
                .split(separator: " ", omittingEmptySubsequences: true)
                .joined(separator: " ")
            if let date = try? Date(normalized, strategy: strategy) {
                result[pid] = date
            }
        }
        return result
    }

    // MARK: - Server Resolution (with filtering)

    private func resolveServers(
        parsed: [ParsedPort],
        cwds: [Int32: String],
        startTimes: [Int32: Date]
    ) -> [DevServer] {
        return parsed.compactMap { info -> DevServer? in
            let cwd = cwds[info.pid] ?? ""

            let gitRoot = findGitRoot(from: cwd)
            if gitRoot == nil && !Self.shouldKeepFallbackProcess(processName: info.processName, cwd: cwd) {
                Log.scanner.debug("Ignore processus '\(info.processName)' (pas de git root, pas dans la liste blanche)")
                return nil
            }

            let projectName = Self.displayName(processName: info.processName, cwd: cwd, gitRoot: gitRoot)
            let gitBranch = gitRoot.map { findGitBranch(at: $0.path()) } ?? ""
            let serverType = detectServerType(processName: info.processName, cwd: cwd)

            return DevServer(
                id: "\(info.port)",
                port: info.port,
                pid: info.pid,
                processName: info.processName,
                projectName: projectName,
                gitBranch: gitBranch,
                serverType: serverType,
                startTime: startTimes[info.pid] ?? Date()
            )
        }
    }

    // MARK: - Filtering Logic (from port-menu)

    static func shouldKeepFallbackProcess(processName: String, cwd: String?) -> Bool {
        let normalized = processName.lowercased()

        if allowedFallbackProcessNames.contains(normalized) {
            return true
        }

        if isDockerProcess(normalized) {
            return true
        }

        if normalized.hasPrefix("python"),
           normalized.dropFirst("python".count).allSatisfy({ $0.isNumber || $0 == "." }) {
            return true
        }

        if let cwd {
            let basename = URL(filePath: cwd).lastPathComponent
            if isMeaningfulDirectoryName(basename),
               allowedFallbackProcessNames.contains(basename.lowercased()) {
                return true
            }
        }

        return false
    }

    static func isDockerProcess(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.contains("docker") || lower.hasPrefix("com.dock") || lower.hasPrefix("vpnkit")
    }

    static func isMeaningfulDirectoryName(_ name: String) -> Bool {
        guard !name.isEmpty, name != "/", !name.hasPrefix(".") else { return false }
        return !ignoredDirNames.contains(name)
    }

    static func displayName(processName: String, cwd: String?, gitRoot: URL?) -> String {
        if let gitRoot {
            return gitRoot.lastPathComponent
        }

        if isDockerProcess(processName) {
            return "Docker"
        }

        if let cwd {
            let basename = URL(filePath: cwd).lastPathComponent
            if isMeaningfulDirectoryName(basename) {
                return basename
            }
        }

        return processName
    }

    // MARK: - Git Resolution

    func findGitRoot(from path: String) -> URL? {
        var current = URL(filePath: path)
        let fm = FileManager.default
        while current.path() != "/" {
            if fm.fileExists(atPath: current.appending(path: ".git").path()) {
                return current
            }
            current = current.deletingLastPathComponent()
        }
        return nil
    }

    private func findGitBranch(at gitRoot: String) -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", gitRoot, "rev-parse", "--abbrev-ref", "HEAD"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch {
            return ""
        }
    }

    // MARK: - Shell Execution

    private func runShell(
        _ executable: String,
        args: [String],
        timeout: TimeInterval,
        environment: [String: String]? = nil
    ) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await Self.runProcess(
                    executable: executable,
                    args: args,
                    environment: environment
                )
            }

            group.addTask {
                try await Task.sleep(for: .seconds(timeout))
                throw PortScannerError.timeout
            }

            defer { group.cancelAll() }
            let result = try await group.next()!
            return result
        }
    }

    private static func runProcess(
        executable: String,
        args: [String],
        environment: [String: String]?
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdout = Pipe()
            let stderr = Pipe()

            process.executableURL = URL(filePath: executable)
            process.arguments = args
            process.standardOutput = stdout
            process.standardError = stderr

            if let env = environment {
                var combined = ProcessInfo.processInfo.environment
                for (k, v) in env { combined[k] = v }
                process.environment = combined
            }

            do {
                try process.run()
                let data = stdout.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                if process.terminationStatus != 0 {
                    continuation.resume(throwing: PortScannerError.processFailed(
                        "\(executable) exited with \(process.terminationStatus)"))
                    return
                }

                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: output)
            } catch {
                continuation.resume(throwing: PortScannerError.processFailed(error.localizedDescription))
            }
        }
    }

    // MARK: - ServerType Detection

    func detectServerType(processName: String, cwd: String) -> ServerType {
        let name = processName.lowercased()

        if name.contains("next") { return .nextjs }
        if name.contains("vite") { return .vite }
        if name.contains("rails") || name.contains("ruby") || name.contains("puma") { return .rails }
        if name.contains("python") || name.contains("python3") { return .python }
        if name.contains("node") || name.contains("bun") { return .express }
        if name.contains("django") { return .django }
        if name.contains("flask") { return .flask }
        if name.contains("uvicorn") || name.contains("gunicorn") { return .fastapi }
        if name.contains("php") { return .laravel }

        guard !cwd.isEmpty else { return .unknown }

        let fm = FileManager.default
        if fm.fileExists(atPath: cwd + "/package.json") {
            let content = (try? String(contentsOfFile: cwd + "/package.json")) ?? ""
            if content.contains("next") { return .nextjs }
            if content.contains("vite") { return .vite }
            return .express
        }
        if fm.fileExists(atPath: cwd + "/Gemfile") { return .rails }
        if fm.fileExists(atPath: cwd + "/requirements.txt") || fm.fileExists(atPath: cwd + "/pyproject.toml") {
            return .python
        }
        if fm.fileExists(atPath: cwd + "/manage.py") { return .django }
        if fm.fileExists(atPath: cwd + "/wsgi.py") { return .django }

        return .unknown
    }
}

// MARK: - Errors

enum PortScannerError: Error, LocalizedError {
    case timeout
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .timeout: return "Process timed out"
        case .processFailed(let msg): return msg
        }
    }
}
