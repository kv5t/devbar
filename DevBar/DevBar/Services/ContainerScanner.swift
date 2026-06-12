import Foundation

/// Service de detection des conteneurs Docker
final class ContainerScanner: Sendable {

    /// Chemins de recherche pour docker
    private let dockerPaths = [
        "/usr/local/bin/docker",
        "/opt/homebrew/bin/docker",
        "/usr/bin/docker",
        "\(NSHomeDirectory())/.docker/bin/docker"
    ]

    /// Trouve le binaire docker
    func findDocker() -> String? {
        // 1. Verifier les chemins connus
        for path in dockerPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // 2. Utiliser which comme fallback
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "which docker 2>/dev/null"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return path.isEmpty ? nil : path
        } catch {
            return nil
        }
    }

    /// Verifie si Docker est disponible
    func isDockerAvailable() -> Bool {
        findDocker() != nil
    }

    /// Lance un scan des conteneurs Docker en cours d'execution
    func scan() async -> [Container] {
        guard let dockerPath = findDocker() else {
            return []
        }
        let output = await executeDockerPs(dockerPath: dockerPath)
        return parseDockerPsOutput(output)
    }

    /// Execute docker ps et retourne la sortie JSON
    private func executeDockerPs(dockerPath: String) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()

                process.executableURL = URL(fileURLWithPath: dockerPath)
                process.arguments = [
                    "ps", "-a",
                    "--format", "{{json .}}"
                ]
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice

                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(returning: "")
                }
            }
        }
    }

    /// Parse la sortie JSON de docker ps
    func parseDockerPsOutput(_ output: String) -> [Container] {
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var containers: [Container] = []

        for line in lines {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            let id = json["ID"] as? String ?? ""
            let name = json["Names"] as? String ?? ""
            let image = json["Image"] as? String ?? ""
            let status = json["Status"] as? String ?? ""
            let ports = json["Ports"] as? String ?? ""

            let containerStatus = parseContainerStatus(status)
            let portList = ports.isEmpty ? [] : [ports]

            let container = Container(
                id: id,
                name: name,
                image: image,
                ports: portList,
                status: containerStatus,
                isRunning: containerStatus.isActive
            )
            containers.append(container)
        }

        return containers
    }

    /// Parse le statut d'un conteneur
    private func parseContainerStatus(_ status: String) -> ContainerStatus {
        let lower = status.lowercased()
        if lower.hasPrefix("up") { return .running }
        if lower.contains("exited") { return .exited }
        if lower.contains("paused") { return .paused }
        if lower.contains("restarting") { return .restarting }
        if lower.contains("created") { return .created }
        return .exited
    }
}
