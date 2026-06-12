import Foundation
import AppKit
import SwiftUI

/// Service de gestion des tunnels Cloudflare via cloudflared
/// Modele: tony-roslund/tunnelbar TunnelManager.swift
@MainActor
final class TunnelManager: ObservableObject {
    @Published var activeTunnels: [Tunnel] = []

    /// Maps processContextID → Process/Pipes/CapturedURL
    private var tunnelProcesses: [UUID: Process] = [:]
    private var tunnelPipes: [UUID: (stdout: Pipe, stderr: Pipe)] = [:]
    private var capturedURLs: [UUID: String] = [:]

    private let startupTimeoutSeconds: UInt64 = 40

    var aggregatedState: TunnelStatus {
        if activeTunnels.contains(where: { $0.status == .starting }) { return .starting }
        if activeTunnels.contains(where: { $0.status == .running }) { return .running }
        if activeTunnels.contains(where: { $0.status == .failed }) { return .failed }
        return .stopped
    }

    var activeCount: Int {
        activeTunnels.filter({ $0.status == .running }).count
    }

    // MARK: - Start Tunnel

    func startTunnel(for port: UInt16) async throws -> Tunnel {
        if activeTunnels.contains(where: { $0.serverPort == port && $0.status == .running }) {
            throw TunnelError.alreadyTunneled(port)
        }

        let cloudflaredPath = try await CloudflaredBundler.shared.ensureCloudflared()

        let ctxID = UUID()
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: cloudflaredPath)
        process.arguments = ["tunnel", "--no-autoupdate", "--url", "http://localhost:\(port)"]
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in
                self?.handleCloudflaredOutput(text, ctxID: ctxID, port: port)
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in
                self?.handleCloudflaredOutput(text, ctxID: ctxID, port: port)
            }
        }

        process.terminationHandler = { [weak self] process in
            Task { @MainActor [weak self] in
                self?.handleTermination(ctxID: ctxID, process: process)
            }
        }

        do {
            try process.run()
        } catch {
            throw TunnelError.launchFailed(error.localizedDescription)
        }

        let pendingTunnel = Tunnel(serverPort: port, processID: process.processIdentifier, processContextID: ctxID)
        let pendingID = pendingTunnel.id

        withAnimation(.easeInOut(duration: 0.3)) {
            activeTunnels.append(pendingTunnel)
        }

        tunnelProcesses[ctxID] = process
        tunnelPipes[ctxID] = (stdoutPipe, stderrPipe)

        // Poll loop — attend la capture de l'URL (max 40 secondes)
        for _ in 0..<Int(startupTimeoutSeconds) {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            if let url = capturedURLs[ctxID] {
                if let idx = activeTunnels.firstIndex(where: { $0.id == pendingID }) {
                    let old = activeTunnels[idx]
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        activeTunnels[idx] = Tunnel(
                            id: old.id,
                            processContextID: ctxID,
                            serverPort: port,
                            cloudflareURL: url,
                            processID: process.processIdentifier,
                            startTime: old.startTime
                        )
                    }
                }

                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url, forType: .string)

                return activeTunnels.first { $0.id == pendingID } ?? pendingTunnel
            }
        }

        // Timeout
        process.terminate()
        cleanupContext(ctxID)
        throw TunnelError.timeout
    }

    // MARK: - Output Handling

    private func handleCloudflaredOutput(_ text: String, ctxID: UUID, port: UInt16) {
        guard capturedURLs[ctxID] == nil else { return }
        if let url = Self.extractCloudflareURLStatic(from: text) {
            capturedURLs[ctxID] = url
            Log.tunnel.info("URL capturee pour le port \(port): \(url)")
        }
    }

    private func handleTermination(ctxID: UUID, process: Process) {
        guard tunnelProcesses[ctxID] != nil else { return }
        let status = process.terminationStatus
        Log.tunnel.info("Processus cloudflared termine (status: \(status))")

        // Mettre a jour le tunnel associe si le process crash/est tue
        if let idx = activeTunnels.firstIndex(where: { $0.processContextID == ctxID }) {
            if activeTunnels[idx].status != .stopped {
                withAnimation {
                    activeTunnels[idx].status = .stopped
                    activeTunnels[idx].lastError = "Processus termine (status: \(status))"
                }
            }
        }

        cleanupContext(ctxID)
    }

    // MARK: - Stop

    func stopTunnel(id: UUID) {
        guard let tunnel = activeTunnels.first(where: { $0.id == id }) else { return }
        let ctxID = tunnel.processContextID

        Log.tunnel.info("Arret du tunnel port \(tunnel.serverPort) (ctx \(ctxID))")

        if let process = tunnelProcesses[ctxID] {
            Log.tunnel.info("Termination du process PID \(process.processIdentifier)")
            process.terminate()
        }

        withAnimation(.easeOut(duration: 0.25)) {
            activeTunnels.removeAll { $0.id == id }
        }
        cleanupContext(ctxID)
    }

    func stopAllTunnels() {
        Log.tunnel.info("Arret de tous les tunnels (\(self.activeTunnels.count) actifs)")

        // Nettoyer les readabilityHandlers avant de supprimer les pipes
        for (_, pipes) in tunnelPipes {
            pipes.stdout.fileHandleForReading.readabilityHandler = nil
            pipes.stderr.fileHandleForReading.readabilityHandler = nil
        }

        for (_, process) in tunnelProcesses {
            Log.tunnel.info("Termination du process PID \(process.processIdentifier)")
            process.terminate()
        }
        tunnelProcesses.removeAll()
        tunnelPipes.removeAll()
        activeTunnels.removeAll()
        capturedURLs.removeAll()
    }

    // MARK: - Query

    func hasTunnel(for port: UInt16) -> Bool {
        activeTunnels.contains { $0.serverPort == port && $0.status == .running }
    }

    func tunnelURL(for port: UInt16) -> String? {
        activeTunnels.first { $0.serverPort == port && $0.status == .running }?.cloudflareURL
    }

    func tunnelForPort(_ port: UInt16) -> Tunnel? {
        activeTunnels.first { $0.serverPort == port }
    }

    // MARK: - Cleanup

    private func cleanupContext(_ ctxID: UUID) {
        if let pipes = tunnelPipes.removeValue(forKey: ctxID) {
            pipes.stdout.fileHandleForReading.readabilityHandler = nil
            pipes.stderr.fileHandleForReading.readabilityHandler = nil
        }
        tunnelProcesses.removeValue(forKey: ctxID)
        capturedURLs.removeValue(forKey: ctxID)
    }

    // MARK: - Static

    nonisolated static func extractCloudflareURLStatic(from output: String) -> String? {
        let pattern = /https:\/\/[a-z0-9\-]+\.trycloudflare\.com/
        if let match = output.firstMatch(of: pattern) {
            return String(match.output)
        }
        return nil
    }
}

// MARK: - Errors

enum TunnelError: LocalizedError {
    case cloudflaredNotFound
    case alreadyTunneled(UInt16)
    case launchFailed(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .cloudflaredNotFound:
            return "Cloudflared non trouve. Installez-le via: brew install cloudflared"
        case .alreadyTunneled(let port):
            return "Un tunnel existe deja pour le port \(port)."
        case .launchFailed(let reason):
            return "Echec du lancement du tunnel: \(reason)"
        case .timeout:
            return "Delai d'attente depasse pour la detection du tunnel. Verifiez que cloudflared fonctionne."
        }
    }
}
