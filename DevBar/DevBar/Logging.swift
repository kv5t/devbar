import Foundation
import os

/// Journalisation systeme pour DevBar
enum Log {
    static let scanner = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DevBar", category: "scanner")
    static let store = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DevBar", category: "store")
    static let ui = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DevBar", category: "ui")
    static let lifecycle = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DevBar", category: "lifecycle")
    static let shell = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DevBar", category: "shell")
    static let tunnel = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DevBar", category: "tunnel")

    /// Active le journalisation verbeuse. Cle UserDefaults: "debugLogging".
    static var isVerbose: Bool {
        UserDefaults.standard.bool(forKey: "debugLogging")
    }
}
