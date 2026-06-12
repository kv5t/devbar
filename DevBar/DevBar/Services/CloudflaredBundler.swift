import Foundation

/// Service de detection et telechargement de cloudflared
/// Modele: tony-roslund/tunnelbar CloudflaredLocator.swift
final class CloudflaredBundler: Sendable {
    static let shared = CloudflaredBundler()

    private init() {}

    /// Erreur si cloudflared introuvable
    enum LocatorError: LocalizedError {
        case missingCloudflared

        var errorDescription: String? {
            "cloudflared was not found. Please install it: brew install cloudflared"
        }
    }

    /// Retourne l'URL du binaire cloudflared executable
    func findCloudflared() -> String? {
        // 1. Bundle de l'application (cloudflared-arm64 ou cloudflared-amd64)
        if let bundledURL = bundledExecutableURL() {
            makeExecutableIfNeeded(bundledURL)
            return bundledURL.path
        }

        // 2. PATH systeme
        if let pathURL = findOnPath("cloudflared") {
            return pathURL.path
        }

        // 3. Emplacements courants (fallback)
        let commonPaths = [
            "/usr/local/bin/cloudflared",
            "/opt/homebrew/bin/cloudflared",
            "/usr/bin/cloudflared"
        ]
        for path in commonPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        return nil
    }

    /// Trouve ou telecharge cloudflared automatiquement
    func ensureCloudflared() async throws -> String {
        if let existingPath = findCloudflared() {
            return existingPath
        }

        Log.tunnel.info("cloudflared non trouve, installation automatique...")

        // Installer via brew si disponible
        if isBrewAvailable() {
            Log.tunnel.info("Installation via Homebrew...")
            try await installViaBrew()
            if let path = findCloudflared() {
                Log.tunnel.info("cloudflared installe via Homebrew: \(path)")
                return path
            }
        }

        // Telecharger directement depuis GitHub
        Log.tunnel.info("Telechargement depuis GitHub Releases...")
        try await downloadFromGitHub()
        if let path = findCloudflared() {
            Log.tunnel.info("cloudflared telecharge: \(path)")
            return path
        }

        throw LocatorError.missingCloudflared
    }

    /// Detecte l'architecture actuelle
    func currentArchitecture() -> String {
        #if arch(arm64)
        return "arm64"
        #else
        return "amd64"
        #endif
    }

    // MARK: - Private

    /// Nom du binaire bundle selon l'architecture
    private var bundledResourceName: String {
        #if arch(arm64)
        "cloudflared-arm64"
        #else
        "cloudflared-amd64"
        #endif
    }

    /// Repertoire d'installation local (~/.devbar/bin)
    private var localInstallDir: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".devbar/bin")
    }

    /// Cherche le binaire dans le bundle de l'application
    private func bundledExecutableURL() -> URL? {
        if let url = Bundle.main.url(forResource: bundledResourceName, withExtension: nil) {
            return url
        }
        // Fallback: chercher "cloudflared" sans suffixe arch
        if let url = Bundle.main.url(forResource: "cloudflared", withExtension: nil) {
            return url
        }
        return nil
    }

    /// Cherche un executable dans le PATH
    private func findOnPath(_ name: String) -> URL? {
        let paths = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)

        for path in paths {
            let candidate = URL(fileURLWithPath: path).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    /// Rend un fichier executable si necessaire et retire la quarantaine
    private func makeExecutableIfNeeded(_ url: URL) {
        guard !FileManager.default.isExecutableFile(atPath: url.path) else {
            removeQuarantine(from: url)
            return
        }
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: url.path
        )
        removeQuarantine(from: url)
    }

    /// Retire l'attribut de quarantaine macOS Gatekeeper
    private func removeQuarantine(from url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        process.arguments = ["-d", "com.apple.quarantine", url.path]
        try? process.run()
        process.waitUntilExit()
    }

    /// Verifie si brew est disponible
    private func isBrewAvailable() -> Bool {
        findOnPath("brew") != nil
    }

    /// Installe cloudflared via brew
    private func installViaBrew() async throws {
        guard let brewPath = findOnPath("brew")?.path else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: brewPath)
        process.arguments = ["install", "cloudflared"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()

        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                process.waitUntilExit()
                continuation.resume()
            }
        }
    }

    /// Telecharge cloudflared depuis GitHub Releases
    private func downloadFromGitHub() async throws {
        let arch = currentArchitecture()
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("devbar-cloudflared-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Recuperer la derniere version
        let releaseURL = URL(string: "https://api.github.com/repos/cloudflare/cloudflared/releases/latest")!
        let (releaseData, _) = try await URLSession.shared.data(from: releaseURL)
        let release = try JSONSerialization.jsonObject(with: releaseData) as? [String: Any]
        guard let tagName = release?["tag_name"] as? String else {
            throw LocatorError.missingCloudflared
        }

        Log.tunnel.info("Derniere version cloudflared: \(tagName)")

        // Telecharger l'archive
        let archiveName = "cloudflared-darwin-\(arch).tgz"
        let archiveURL = URL(string: "https://github.com/cloudflare/cloudflared/releases/download/\(tagName)/\(archiveName)")!
        let archivePath = tmpDir.appendingPathComponent(archiveName)

        let (archiveData, _) = try await URLSession.shared.data(from: archiveURL)
        try archiveData.write(to: archivePath)

        // Extraire
        let extractProcess = Process()
        extractProcess.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        extractProcess.arguments = ["-xzf", archivePath.path, "-C", tmpDir.path]
        try extractProcess.run()
        extractProcess.waitUntilExit()

        // Trouver le binaire
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: tmpDir, includingPropertiesForKeys: nil) else {
            throw LocatorError.missingCloudflared
        }
        guard let binaryURL = files.first(where: { $0.lastPathComponent == "cloudflared" }) else {
            throw LocatorError.missingCloudflared
        }

        // Copier vers ~/.devbar/bin/
        try fm.createDirectory(at: localInstallDir, withIntermediateDirectories: true)
        let destURL = localInstallDir.appendingPathComponent("cloudflared")
        if fm.fileExists(atPath: destURL.path) {
            try fm.removeItem(at: destURL)
        }
        try fm.copyItem(at: binaryURL, to: destURL)
        makeExecutableIfNeeded(destURL)
    }
}
