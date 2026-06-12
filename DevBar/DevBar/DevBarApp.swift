import SwiftUI

/// Point d'entree principal de l'application DevBar
@main
struct DevBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var store = PortStore.shared

    var body: some Scene {
        MenuBarExtra {
            DevBarContentView()
                .environment(store)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: store.entries.isEmpty
                      ? "bolt"
                      : "bolt.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(statusColor)
                if !store.entries.isEmpty {
                    Text(store.entries.count, format: .number)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
            }
            .onAppear { store.ensurePolling() }
        }
        .menuBarExtraStyle(.window)
    }

    private var statusColor: Color {
        if store.lastError != nil && store.entries.isEmpty {
            return .orange
        }
        if !store.activeTunnels.isEmpty {
            return .green
        }
        return store.entries.isEmpty ? .gray : .white
    }
}

/// Delegate pour configurer l'application
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        CloudflaredProcessCleaner.cleanOrphanedProcesses()

        Task.detached {
            do {
                _ = try await CloudflaredBundler.shared.ensureCloudflared()
            } catch {
                Log.lifecycle.error("Echec du telechargement cloudflared: \(error.localizedDescription)")
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        PortStore.shared.stopAllTunnels()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        false
    }
}
