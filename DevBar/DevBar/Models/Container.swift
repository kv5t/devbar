import Foundation

/// Represente un conteneur Docker en cours d'execution
struct Container: Identifiable {
    let id: String
    let name: String
    let image: String
    let ports: [String]
    let status: ContainerStatus
    let isRunning: Bool

    /// Badge Tailscale si detecte
    var hasTailscale: Bool {
        ports.contains { $0.contains("tailscale") || $0.contains("100.") }
    }
}
