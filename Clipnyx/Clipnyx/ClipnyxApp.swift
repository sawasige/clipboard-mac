import SwiftUI
@preconcurrency import ApplicationServices

@main
struct ClipnyxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Clipnyx", image: "MenuBarIcon") {
            MenuBarView()
                .environment(appDelegate.clipboardManager)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - AppDelegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let clipboardManager = ClipboardManager()
    private var popupController = PopupPanelController()
    private var settingsWindow: NSWindow?

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

        // 設定ウィンドウ表示リクエスト
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showSettings),
            name: .openSettingsRequest,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregister()
        clipboardManager.stopPolling()
    }

    @objc func showSettings() {
        if let settingsWindow {
            settingsWindow.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
            .environment(clipboardManager)

        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "Settings")
        window.contentView = NSHostingView(rootView: settingsView)
        window.setContentSize(window.contentView!.fittingSize)
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.settingsWindow = window

        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === settingsWindow else { return }
        settingsWindow = nil
    }
}

extension Notification.Name {
    static let openSettingsRequest = Notification.Name("openSettingsRequest")
}
