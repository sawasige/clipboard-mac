import SwiftUI

@main
struct ClipboardHistoryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("ClipboardHistory", systemImage: "clipboard") {
            MenuBarView()
                .environment(appDelegate.clipboardManager)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(appDelegate.clipboardManager)
        }
    }
}

// MARK: - AppDelegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let clipboardManager = ClipboardManager()
    private var popupController = PopupPanelController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register hotkey
        HotKeyManager.shared.onHotKey = { [weak self] in
            guard let self else { return }
            self.popupController.toggle(clipboardManager: self.clipboardManager)
        }
        HotKeyManager.shared.register()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregister()
        clipboardManager.stopPolling()
    }
}
