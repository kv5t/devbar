import Foundation
import ServiceManagement

/// Configuration globale de l'application via UserDefaults
final class DevBarConfig {
    nonisolated(unsafe) static let shared = DevBarConfig()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let refreshInterval = "refreshInterval"
        static let autoStartTunnels = "autoStartTunnels"
        static let cloudflaredPath = "cloudflaredPath"
        static let showTailscaleBadge = "showTailscaleBadge"
        static let lastSelectedPorts = "lastSelectedPorts"
    }

    var refreshInterval: TimeInterval {
        get { defaults.double(forKey: Keys.refreshInterval) }
        set { defaults.set(newValue, forKey: Keys.refreshInterval) }
    }

    var autoStartTunnels: Bool {
        get { defaults.bool(forKey: Keys.autoStartTunnels) }
        set { defaults.set(newValue, forKey: Keys.autoStartTunnels) }
    }

    var cloudflaredPath: String? {
        get { defaults.string(forKey: Keys.cloudflaredPath) }
        set { defaults.set(newValue, forKey: Keys.cloudflaredPath) }
    }

    var showTailscaleBadge: Bool {
        get {
            if defaults.object(forKey: Keys.showTailscaleBadge) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.showTailscaleBadge)
        }
        set { defaults.set(newValue, forKey: Keys.showTailscaleBadge) }
    }

    var lastSelectedPorts: [UInt16] {
        get {
            (defaults.array(forKey: Keys.lastSelectedPorts) as? [Int])?
                .compactMap { UInt16(exactly: $0) } ?? []
        }
        set { defaults.set(newValue.map { Int($0) }, forKey: Keys.lastSelectedPorts) }
    }

    private init() {
        defaults.register(defaults: [
            Keys.refreshInterval: 5.0,
            Keys.autoStartTunnels: false,
            Keys.showTailscaleBadge: true
        ])
    }

    // MARK: - Start at Login (SMAppService)

    var startAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Erreur Start at Login: \(error.localizedDescription)")
            }
        }
    }
}
