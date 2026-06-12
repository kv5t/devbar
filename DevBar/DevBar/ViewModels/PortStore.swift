import SwiftUI
import os

/// Intervalle de rafraichissement du scan
enum RefreshInterval: Double, CaseIterable, Sendable {
    case fast = 2
    case normal = 5
    case relaxed = 10
    case slow = 30

    static let `default`: RefreshInterval = .normal
}

/// Magasin de ports detectes - source unique de verite
/// Modele inspire de wieandteduard/port-menu + tony-roslund/tunnelbar
@MainActor
@Observable
final class PortStore {
    static let shared = PortStore()

    var entries: [DevServer] = []
    var activeTunnels: [Tunnel] = []
    var allContainers: [Container] = []
    var lastError: String?
    var isScanning = false
    var flaringPorts: Set<UInt16> = []

    var refreshInterval: RefreshInterval {
        get { RefreshInterval(rawValue: UserDefaults.standard.double(forKey: "refreshInterval")) ?? .default }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "refreshInterval")
            restartTimer()
            Log.store.info("Intervalle de rafraichissement: \(newValue.rawValue)s")
        }
    }

    var tunneledServerCount: Int {
        entries.filter { server in
            activeTunnels.contains { $0.serverPort == server.port && $0.status == .running }
        }.count
    }

    var runningContainers: [Container] {
        allContainers.filter { $0.isRunning }
    }

    var activeTunnelCount: Int {
        activeTunnels.filter({ $0.status == .running }).count
    }

    var hasActiveTunnels: Bool {
        !activeTunnels.isEmpty
    }

    var tunnelStatus: TunnelStatus {
        tunnelManager.aggregatedState
    }

    private let portScanner = PortScanner()
    private let containerScanner = ContainerScanner()
    private let tunnelManager = TunnelManager()
    private var timer: Timer?
    private var scanTask: Task<Void, Never>?
    private var recentlyKilled: [UInt16: Date] = [:]
    private var sleepObserver: Any?
    private var wakeObserver: Any?

    init() {
        setupLifecycleObservers()
        Log.lifecycle.info("PortStore initialise")
    }

    // MARK: - Polling

    func ensurePolling() {
        guard timer == nil else { return }
        Log.lifecycle.info("Demarrage du polling (intervalle: \(self.refreshInterval.rawValue)s)")
        refresh()
        startTimer()
    }

    private func startTimer() {
        timer?.invalidate()
        let interval = refreshInterval.rawValue
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    private func restartTimer() {
        guard timer != nil else { return }
        startTimer()
    }

    // MARK: - Refresh

    func refresh() {
        guard !isScanning else {
            if Log.isVerbose { Log.store.debug("Rafraichissement ignore - scan en cours") }
            return
        }

        scanTask?.cancel()
        scanTask = Task { [portScanner, containerScanner] in
            isScanning = true
            defer { isScanning = false }

            let newServers = await portScanner.scan()
            guard !Task.isCancelled else { return }

            let newContainers = await containerScanner.scan()
            guard !Task.isCancelled else { return }

            pruneRecentlyKilled()
            let filtered = newServers.filter { !recentlyKilled.keys.contains($0.port) }

            applyUpdate(filtered)
            allContainers = newContainers

            Log.store.info("Scan termine: \(filtered.count) serveurs, \(newContainers.count) conteneurs")
        }
    }

    private func applyUpdate(_ newEntries: [DevServer]) {
        let oldIDs = Set(entries.map(\.id))
        let newIDs = Set(newEntries.map(\.id))

        if oldIDs == newIDs && entries.count == newEntries.count {
            var needsUpdate = false
            for (old, new) in zip(entries, newEntries) {
                if old != new { needsUpdate = true; break }
            }
            if !needsUpdate { return }
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            entries = newEntries
        }
    }

    // MARK: - Tunnels

    func startTunnel(for port: UInt16) {
        flaringPorts.insert(port)
        Task {
            do {
                _ = try await tunnelManager.startTunnel(for: port)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    self.activeTunnels = self.tunnelManager.activeTunnels
                }
                Log.tunnel.info("Tunnel demarre pour le port \(port)")
            } catch {
                lastError = error.localizedDescription
                Log.tunnel.error("Echec du tunnel: \(error.localizedDescription)")
            }
            flaringPorts.remove(port)
        }
    }

    func stopTunnel(id: UUID) {
        tunnelManager.stopTunnel(id: id)
        withAnimation(.easeOut(duration: 0.25)) {
            self.activeTunnels = self.tunnelManager.activeTunnels
        }
    }

    func stopTunnel(for port: UInt16) {
        if let tunnel = activeTunnels.first(where: { $0.serverPort == port }) {
            stopTunnel(id: tunnel.id)
        }
    }

    func stopAllTunnels() {
        tunnelManager.stopAllTunnels()
        withAnimation(.easeOut(duration: 0.25)) {
            self.activeTunnels = []
        }
    }

    func tunnelURL(for port: UInt16) -> String? {
        tunnelManager.tunnelURL(for: port)
    }

    // MARK: - Actions

    func killProcess(pid: Int32, port: UInt16) {
        kill(pid, SIGTERM)
        recentlyKilled[port] = Date()
        Log.store.info("Processus \(pid) tue sur le port \(port)")
    }

    func killAllProcesses() {
        let currentEntries = entries
        guard !currentEntries.isEmpty else { return }

        for entry in currentEntries {
            kill(entry.pid, SIGTERM)
            recentlyKilled[entry.port] = Date()
        }

        Log.store.info("Tues \(currentEntries.count) processus")
        withAnimation(.easeInOut(duration: 0.25)) {
            entries = []
        }
    }

    func removeEntry(port: UInt16) {
        withAnimation(.easeOut(duration: 0.3)) {
            entries.removeAll { $0.port == port }
        }
    }

    func openServer(_ server: DevServer) {
        if let url = URL(string: server.localhostURL) {
            NSWorkspace.shared.open(url)
        }
    }

    func openTunnelURL(_ tunnel: Tunnel) {
        guard let urlString = tunnel.cloudflareURL, let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    static func copyToClipboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    // MARK: - Recently Killed Cleanup

    private func pruneRecentlyKilled() {
        let cutoff = Date().addingTimeInterval(-8)
        recentlyKilled = recentlyKilled.filter { $0.value > cutoff }
    }

    // MARK: - Sleep / Wake

    private func setupLifecycleObservers() {
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleSleep()
            }
        }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleWake()
            }
        }
    }

    private func handleSleep() {
        Log.lifecycle.info("Systeme en veille - suspension du polling")
        timer?.invalidate()
        timer = nil
        scanTask?.cancel()
    }

    private func handleWake() {
        Log.lifecycle.info("Systeme reveille - reprise du polling")
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            self?.ensurePolling()
        }
    }

    // MARK: - Diagnostics

    var diagnosticsSnapshot: String {
        """
        === DevBar Diagnostics ===
        Ports: \(entries.count)
        Scanning: \(isScanning)
        Error: \(lastError ?? "none")
        Interval: \(refreshInterval.rawValue)s
        Tunnels: \(activeTunnels.count) (\(activeTunnelCount) actifs)
        Containers: \(allContainers.filter(\.isRunning).count)
        Recently killed: \(recentlyKilled.keys.sorted().map(String.init).joined(separator: ", "))
        ==========================
        """
    }
}
