import Foundation

/// Nettoie les processus cloudflared orphelins au demarrage de l'application
/// Modele: tony-roslund/tunnelbar CloudflaredProcessCleaner.swift
enum CloudflaredProcessCleaner {

    /// Tue tous les processus cloudflared lances par cette app au demarrage
    static func cleanOrphanedProcesses() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["pkill", "-f", "cloudflared tunnel"]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
            Log.lifecycle.info("Nettoyage des processus cloudflared orphelins termine")
        } catch {
            Log.lifecycle.error("Echec du nettoyage des processus cloudflared: \(error.localizedDescription)")
        }
    }
}
