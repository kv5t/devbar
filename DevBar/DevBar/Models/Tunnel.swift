import Foundation

/// Represente un tunnel Cloudflare actif
/// Modele inspire de tony-roslund/tunnelbar
struct Tunnel: Identifiable {
    let id: UUID
    let processContextID: UUID
    let serverPort: UInt16
    let localURL: String
    let cloudflareURL: String?
    let processID: Int32
    let startTime: Date
    var status: TunnelStatus
    var lastError: String?

    init(serverPort: UInt16, processID: Int32, processContextID: UUID) {
        self.id = UUID()
        self.processContextID = processContextID
        self.serverPort = serverPort
        self.localURL = "http://localhost:\(serverPort)"
        self.cloudflareURL = nil
        self.processID = processID
        self.startTime = Date()
        self.status = .starting
    }

    /// Conserve les IDs originaux lors de la mise a jour (starting -> running)
    init(id: UUID, processContextID: UUID, serverPort: UInt16, cloudflareURL: String, processID: Int32, startTime: Date) {
        self.id = id
        self.processContextID = processContextID
        self.serverPort = serverPort
        self.localURL = "http://localhost:\(serverPort)"
        self.cloudflareURL = cloudflareURL
        self.processID = processID
        self.startTime = startTime
        self.status = .running
    }

    /// Duree depuis le demarrage
    var uptime: String {
        let elapsed = Date().timeIntervalSince(startTime)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return "\(minutes)m \(seconds)s"
    }

    /// URL locale tronquee pour affichage
    var shortLocalURL: String {
        "localhost:\(serverPort)"
    }

    /// URL publique tronquee pour affichage
    var shortPublicURL: String? {
        guard let url = cloudflareURL else { return nil }
        return url.replacingOccurrences(of: "https://", with: "")
    }
}
