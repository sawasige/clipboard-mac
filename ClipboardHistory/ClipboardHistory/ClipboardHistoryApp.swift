import SwiftUI
@preconcurrency import ApplicationServices

@main
struct ClipboardHistoryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Clipnyx", image: "MenuBarIcon") {
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
        // アクセシビリティ権限の確認（未登録時のみシステムダイアログ表示）
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

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
