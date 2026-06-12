import Foundation

/// Represente un serveur de developpement detecte sur un port TCP en ecoute
struct DevServer: Identifiable, Hashable {
    let id: String
    let port: UInt16
    let pid: Int32
    let processName: String
    let projectName: String
    let gitBranch: String?
    let serverType: ServerType
    let startTime: Date

    /// Duree depuis le demarrage
    var uptime: String {
        let elapsed = Date().timeIntervalSince(startTime)
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        let seconds = Int(elapsed) % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    /// URL localhost du serveur
    var localhostURL: String {
        "http://localhost:\(port)"
    }

    /// Identifiant unique base sur le port + PID
    static func == (lhs: DevServer, rhs: DevServer) -> Bool {
        lhs.port == rhs.port && lhs.pid == rhs.pid
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(port)
        hasher.combine(pid)
    }
}
