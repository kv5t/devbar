import Foundation

/// Types de serveurs de developpement detectes
enum ServerType: String, CaseIterable, Identifiable {
    case nextjs = "Next.js"
    case vite = "Vite"
    case rails = "Rails"
    case python = "Python"
    case express = "Express"
    case django = "Django"
    case flask = "Flask"
    case fastapi = "FastAPI"
    case laravel = "Laravel"
    case unknown = "Serveur"

    var id: String { rawValue }

    /// Icone SF Symbol associee
    var sfSymbol: String {
        switch self {
        case .nextjs: return "bolt.fill"
        case .vite: return "bolt.fill"
        case .rails: return "tram.fill"
        case .python: return "terminal.fill"
        case .express: return "globe"
        case .django: return "globe"
        case .flask: return "globe"
        case .fastapi: return "globe"
        case .laravel: return "globe"
        case .unknown: return "server.rack"
        }
    }
}

/// Etat d'un tunnel Cloudflare
enum TunnelStatus: String {
    case starting = "Demarrage"
    case running = "Actif"
    case failed = "Echec"
    case stopped = "Arrete"

    var isActive: Bool {
        self == .running
    }
}

/// Etat d'un conteneur Docker
enum ContainerStatus: String {
    case running = "En cours"
    case exited = "Arrete"
    case paused = "En pause"
    case restarting = "Redemarrage"
    case created = "Cree"

    var isActive: Bool {
        self == .running
    }
}
