import SwiftUI

// MARK: - Content View

struct DevBarContentView: View {
    @Environment(PortStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DevBarHeaderView()

            Divider()

            // Afficher l'erreur meme quand des serveurs existent
            if let error = store.lastError {
                DevBarErrorView(error: error)
            } else if store.entries.isEmpty && !store.isScanning {
                DevBarEmptyView()
            } else if store.entries.isEmpty && store.isScanning {
                DevBarScanningView()
            } else {
                DevBarServerListView()
            }
        }
        .frame(width: 420)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Header

struct DevBarHeaderView: View {
    @Environment(PortStore.self) private var store
    @State private var showMenu = false
    @State private var menuHovered = false

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    var body: some View {
        HStack(spacing: 10) {
            // Brand mark
            HStack(spacing: 6) {
                Text("devbar")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                // Status dot
                let statusColor: Color = {
                    if store.lastError != nil && store.entries.isEmpty { return .orange }
                    if !store.activeTunnels.isEmpty { return .green }
                    return store.entries.isEmpty ? .gray : .white
                }()

                PulsingDot(color: statusColor)
                    .frame(width: 8, height: 8)
            }

            Spacer()

            // Compteurs
            HStack(spacing: 8) {
                if !store.entries.isEmpty {
                    HeaderCounter(icon: "bolt.fill", count: store.entries.count)
                }
                if store.activeTunnelCount > 0 {
                    HeaderCounter(icon: "link", count: store.activeTunnelCount, color: .green)
                }
            }

            HStack(spacing: 4) {
                if store.hasActiveTunnels {
                    HeaderButton("Stop tunnels", destructive: true) {
                        store.stopAllTunnels()
                    }
                }

                if !store.entries.isEmpty {
                    HeaderButton("Kill all", destructive: true) {
                        store.killAllProcesses()
                    }
                }

                HeaderIconButton(systemName: "power", tooltip: "Quitter DevBar") {
                    NSApplication.shared.terminate(nil)
                }

                Button { showMenu.toggle() } label: {
                    HeaderIconLabel(systemName: "ellipsis")
                        .padding(.horizontal, 5)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(menuHovered ? Color.primary.opacity(0.08) : .clear))
                        .foregroundStyle(menuHovered ? .primary : .secondary)
                        .scaleEffect(menuHovered ? 1.04 : 1)
                }
                .buttonStyle(.plain)
                .help("Settings")
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.12)) {
                        menuHovered = hovering
                    }
                }
                .popover(isPresented: $showMenu, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("DevBar \(appVersion)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        Picker("Intervalle", selection: Binding(
                            get: { store.refreshInterval },
                            set: { store.refreshInterval = $0 }
                        )) {
                            Text("2s").tag(RefreshInterval.fast)
                            Text("5s").tag(RefreshInterval.normal)
                            Text("10s").tag(RefreshInterval.relaxed)
                            Text("30s").tag(RefreshInterval.slow)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        Divider()

                        Toggle("Demarrer au login", isOn: Binding(
                            get: { DevBarConfig.shared.startAtLogin },
                            set: { DevBarConfig.shared.startAtLogin = $0 }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)

                        Divider()

                        Button("Copier le diagnostic") {
                            PortStore.copyToClipboard(store.diagnosticsSnapshot)
                        }
                        .font(.caption)
                    }
                    .padding(12)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Header Counter

struct HeaderCounter: View {
    let icon: String
    let count: Int
    var color: Color = .secondary

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .medium))
            Text("\(count)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(color.opacity(0.1)))
    }
}

// MARK: - Header Buttons

struct HeaderButton: View {
    let label: String
    let destructive: Bool
    let action: () -> Void
    @State private var isHovered = false

    init(_ label: String, destructive: Bool = false, action: @escaping () -> Void) {
        self.label = label
        self.destructive = destructive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, destructive ? 10 : 7)
                .padding(.vertical, 4)
                .background(Capsule().fill(backgroundColor))
                .foregroundStyle(foregroundColor)
                .scaleEffect(isHovered ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var backgroundColor: Color {
        if destructive {
            return isHovered ? .red.opacity(0.12) : .clear
        }
        return isHovered ? .primary.opacity(0.08) : .clear
    }

    private var foregroundColor: Color {
        destructive ? (isHovered ? .red : .secondary) : .secondary
    }
}

struct HeaderIconButton: View {
    let systemName: String
    let tooltip: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HeaderIconLabel(systemName: systemName)
                .padding(.horizontal, 5)
                .padding(.vertical, 4)
                .background(Capsule().fill(isHovered ? Color.primary.opacity(0.08) : .clear))
                .foregroundStyle(isHovered ? .primary : .secondary)
                .scaleEffect(isHovered ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { isHovered = $0 }
    }
}

struct HeaderIconLabel: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: NSFont.preferredFont(forTextStyle: .caption1).pointSize, weight: .medium))
            .frame(width: 12, height: 14)
    }
}

// MARK: - Server List

struct DevBarServerListView: View {
    @Environment(PortStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tunnels actifs
            if !store.activeTunnels.isEmpty {
                TunnelSectionView(
                    tunnels: store.activeTunnels,
                    onStopTunnel: { id in store.stopTunnel(id: id) },
                    onCopyURL: { url in PortStore.copyToClipboard(url) },
                    onOpenURL: { tunnel in store.openTunnelURL(tunnel) }
                )
            }

            // Serveurs
            if !store.entries.isEmpty {
                // Section header
                HStack(spacing: 6) {
                    Circle()
                        .fill(.blue)
                        .frame(width: 6, height: 6)
                    Text("SERVEURS")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    Spacer()
                    Text("\(store.entries.count)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                Divider().padding(.horizontal, 16)

                ForEach(Array(store.entries.enumerated()), id: \.element.id) { index, entry in
                    DevBarServerRow(server: entry, showTopDivider: index > 0)
                }
            }

            // Conteneurs Docker
            if !store.runningContainers.isEmpty {
                ContainerSectionView(
                    containers: store.runningContainers,
                    onStartTunnel: { port in store.startTunnel(for: port) }
                )
            }
        }
        .padding(.bottom, 6)
    }
}

// MARK: - Server Row

struct DevBarServerRow: View {
    let server: DevServer
    let showTopDivider: Bool
    @Environment(PortStore.self) private var store
    @State private var isHovered = false
    @State private var slidOut = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showTopDivider {
                Divider().padding(.horizontal, 16)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    // Dot de statut avec animation de flare
                    if isFlaring {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Circle()
                            .fill(hasActiveTunnel ? .green : .blue)
                            .frame(width: 6, height: 6)
                            .offset(y: -1)
                    }

                    Text(server.projectName)
                        .font(.system(.body, design: .monospaced).weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer()

                    HStack(spacing: 4) {
                        if isFlaring {
                            // Etat: tunnel en cours de creation
                            HStack(spacing: 4) {
                                ProgressView()
                                    .controlSize(.mini)
                                Text("Flaring...")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.orange.opacity(0.1)))
                        } else {
                            HoverButton("Flare") {
                                store.startTunnel(for: server.port)
                            }
                            .opacity(!hasActiveTunnel && isHovered ? 1 : 0)
                            .scaleEffect(!hasActiveTunnel && isHovered ? 1 : 0.85, anchor: .trailing)
                        }

                        HoverButton("Open") {
                            store.openServer(server)
                        }
                        .opacity(isHovered ? 1 : 0)
                        .scaleEffect(isHovered ? 1 : 0.85, anchor: .trailing)

                        HoverButton("Kill", destructive: true) {
                            killWithAnimation()
                        }
                        .opacity(isHovered ? 1 : 0)
                        .scaleEffect(isHovered ? 1 : 0.85, anchor: .trailing)
                    }
                }

                HStack(spacing: 6) {
                    if let branch = server.gitBranch, !branch.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.triangle.branch")
                            Text(branch)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Text(":\(server.port)")
                        .fontDesign(.monospaced)
                        .foregroundStyle(.tertiary)

                    if hasActiveTunnel {
                        Text("tunneled")
                            .font(.caption2)
                            .foregroundStyle(.green)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(3)
                    }

                    Spacer()

                    Text(formatUptime(from: server.startTime))
                        .foregroundStyle(.tertiary)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .blur(radius: slidOut ? 8 : 0)
        .opacity(slidOut ? 0 : 1)
        .offset(x: slidOut ? 420 : 0)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button("Copier l'URL") {
                PortStore.copyToClipboard(server.localhostURL)
            }
            Button("Copier le port") {
                PortStore.copyToClipboard(String(server.port))
            }
            Divider()
            Button("Ouvrir dans le navigateur") {
                store.openServer(server)
            }
            if !hasActiveTunnel {
                Button("Creer un tunnel") {
                    store.startTunnel(for: server.port)
                }
            }
            Divider()
            Button("Tuer le serveur", role: .destructive) {
                killWithAnimation()
            }
        }
    }

    private var hasActiveTunnel: Bool {
        store.activeTunnels.contains { $0.serverPort == server.port && $0.status == .running }
    }

    private var isFlaring: Bool {
        store.flaringPorts.contains(server.port)
    }

    private func killWithAnimation() {
        store.killProcess(pid: server.pid, port: server.port)
        withAnimation(.easeOut(duration: 0.3)) {
            slidOut = true
        }
        Task {
            try? await Task.sleep(for: .seconds(0.3))
            store.removeEntry(port: server.port)
        }
    }
}

// MARK: - Hover Button

struct HoverButton: View {
    let label: String
    let destructive: Bool
    let action: () -> Void
    @State private var isHovered = false

    init(_ label: String, destructive: Bool = false, action: @escaping () -> Void) {
        self.label = label
        self.destructive = destructive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(backgroundColor))
                .foregroundStyle(foregroundColor)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.04 : 1)
        .onHover { isHovered = $0 }
    }

    private var backgroundColor: Color {
        if destructive { return isHovered ? .red.opacity(0.15) : .clear }
        return isHovered ? .primary.opacity(0.1) : .primary.opacity(0.05)
    }

    private var foregroundColor: Color {
        destructive ? (isHovered ? .red : .secondary) : .primary
    }
}

// MARK: - States

struct DevBarEmptyView: View {
    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "bolt")
                .font(.system(size: 24))
                .foregroundStyle(.quaternary)
                .rotationEffect(.degrees(rotation))
            Text("Aucun serveur detecte")
                .font(.callout.bold())
                .foregroundStyle(.secondary)
            Text("Lancez un serveur de dev pour le voir ici")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                withAnimation(.easeInOut(duration: 0.8)) {
                    rotation += 360
                    rotation = rotation.truncatingRemainder(dividingBy: 360)
                }
            }
        }
    }
}

struct DevBarScanningView: View {
    var body: some View {
        VStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Scan des ports...")
                .font(.callout.bold())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

struct DevBarErrorView: View {
    @Environment(PortStore.self) private var store
    let error: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.orange)
            Text("Echec du scan")
                .font(.callout.bold())
                .foregroundStyle(.secondary)
            Text(error)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Button("Reessayer") { store.refresh() }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

// MARK: - Helpers

func formatUptime(from start: Date) -> String {
    let s = Int(Date().timeIntervalSince(start))
    if s < 60 { return "<1m" }
    let m = s / 60
    if m < 60 { return "\(m)m" }
    let h = m / 60
    if h < 24 { return "\(h)h \(m % 60)m" }
    return "\(h / 24)d \(h % 24)h"
}
