import SwiftUI

/// Section affichant les tunnels Cloudflare actifs
/// Modele: tony-roslund/tunnelbar TunnelBarView.swift
struct TunnelSectionView: View {
    let tunnels: [Tunnel]
    let onStopTunnel: (UUID) -> Void
    let onCopyURL: (String) -> Void
    let onOpenURL: (Tunnel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // En-tete avec compteur
            HStack(spacing: 6) {
                PulsingDot(color: tunnels.contains(where: { $0.status == .running }) ? .green : .orange)
                Text("TUNNELS")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Spacer()
                Text("\(tunnels.count)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider().padding(.horizontal, 16)

            // Liste des tunnels
            ForEach(tunnels) { tunnel in
                TunnelCardView(
                    tunnel: tunnel,
                    onStop: { onStopTunnel(tunnel.id) },
                    onCopy: {
                        if let url = tunnel.cloudflareURL {
                            onCopyURL(url)
                        }
                    },
                    onOpen: { onOpenURL(tunnel) }
                )
            }
        }
    }
}

// MARK: - Tunnel Card

struct TunnelCardView: View {
    let tunnel: Tunnel
    let onStop: () -> Void
    let onCopy: () -> Void
    let onOpen: () -> Void
    @State private var isHovered = false
    @State private var showCopied = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                // Ligne principale: statut + port + boutons
                HStack(alignment: .center, spacing: 8) {
                    // Statut
                    statusIndicator

                    // Port et uptime
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Port \(tunnel.serverPort)")
                                .font(.system(.body, design: .monospaced).weight(.semibold))
                            if tunnel.status == .running {
                                Text(tunnel.uptime)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    Spacer()

                    // Boutons d'action (meme style que les serveurs)
                    HStack(spacing: 4) {
                        if tunnel.status == .running {
                            HoverButton("Open") { onOpen() }
                                .opacity(isHovered ? 1 : 0)
                                .scaleEffect(isHovered ? 1 : 0.85, anchor: .trailing)

                            HoverButton("Copy URL") {
                                onCopy()
                                withAnimation { showCopied = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation { showCopied = false }
                                }
                            }
                            .opacity(isHovered ? 1 : 0)
                            .scaleEffect(isHovered ? 1 : 0.85, anchor: .trailing)

                            HoverButton("Unflare", destructive: true) { onStop() }
                                .opacity(isHovered ? 1 : 0)
                                .scaleEffect(isHovered ? 1 : 0.85, anchor: .trailing)
                        } else if tunnel.status == .starting {
                            ProgressView()
                                .controlSize(.mini)
                        } else if tunnel.status == .failed {
                            HoverButton("Unflare", destructive: true) { onStop() }
                        }
                    }
                }

                // URLs
                if tunnel.status == .running {
                    // URL locale
                    HStack(spacing: 4) {
                        Text("l:")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.orange)
                        Text(tunnel.shortLocalURL)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    // URL publique
                    if let publicURL = tunnel.shortPublicURL {
                        HStack(spacing: 4) {
                            Text("p:")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.green)
                            Text(publicURL)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.green)
                                .lineLimit(1)
                        }
                    }
                } else if tunnel.status == .starting {
                    TypewriterText(text: "Demarrage du tunnel...")
                } else if tunnel.status == .failed {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                        Text(tunnel.lastError ?? "Echec du tunnel")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.white.opacity(0.03) : Color.clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }

            Divider().padding(.horizontal, 16)
        }
        .overlay(alignment: .trailing) {
            if showCopied {
                Text("Copie!")
                    .font(.caption2)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.green.opacity(0.15)))
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .padding(.trailing, 12)
            }
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch tunnel.status {
        case .running:
            PulsingDot(color: .green)
        case .starting:
            PulsingDot(color: .orange)
        case .failed:
            Circle()
                .fill(.red)
                .frame(width: 6, height: 6)
        case .stopped:
            Circle()
                .fill(.gray)
                .frame(width: 6, height: 6)
        }
    }
}

// MARK: - Pulsing Dot

struct PulsingDot: View {
    let color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.033)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let scale = 0.92 + 0.08 * sin(t * 2)
            let opacity = 0.8 + 0.2 * sin(t * 2)

            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .scaleEffect(scale)
                .opacity(opacity)
                .shadow(color: color.opacity(0.6), radius: 3)
        }
        .frame(width: 6, height: 6)
    }
}

// MARK: - Typewriter Text

struct TypewriterText: View {
    let text: String
    @State private var displayedText = ""
    @State private var characterIndex = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 2) {
            Text(displayedText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.orange)
            // Curseur clignotant
            Rectangle()
                .fill(.orange)
                .frame(width: 7, height: 13)
                .opacity(characterIndex <= text.count ? 1 : 0)
                .animation(.easeInOut(duration: 0.5).repeatForever(), value: characterIndex <= text.count)
        }
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
                if characterIndex < text.count {
                    characterIndex += 1
                    displayedText = String(text.prefix(characterIndex))
                } else {
                    timer?.invalidate()
                    timer = nil
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}
