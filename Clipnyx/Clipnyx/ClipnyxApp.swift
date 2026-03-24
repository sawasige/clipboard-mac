import SwiftUI

@main
struct ClipnyxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Clipnyx", image: "MenuBarIcon") {
            MenuBarView()
                .environment(appDelegate.clipboardManager)
        }
    }
}

// MARK: - AppDelegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let clipboardManager = ClipboardManager()
    private var popupController = PopupPanelController()
    private var settingsWindow: NSWindow?
    private var snippetEditorWindow: NSWindow?
    #if ENABLE_SPARKLE
    let updateManager = UpdateManager()
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        CGRequestPostEventAccess()

        HotKeyManager.shared.onHotKey = { [weak self] in
            guard let self else { return }
            self.popupController.toggle(clipboardManager: self.clipboardManager)
        }
        HotKeyManager.shared.register()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowSettings),
            name: .openSettingsRequest,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenPopupPanel),
            name: .openPopupPanel,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenSnippetEditor(_:)),
            name: .openSnippetEditor,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCreateNewSnippet),
            name: .createNewSnippet,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregister()
        clipboardManager.stopPolling()
    }

    @objc private func handleOpenPopupPanel() {
        popupController.toggle(clipboardManager: clipboardManager)
    }

    @objc private func handleOpenSnippetEditor(_ notification: Notification) {
        let item = notification.object as? ClipboardItem
        showSnippetEditor(item: item)
    }

    @objc private func handleCreateNewSnippet() {
        showSnippetEditor(item: nil)
    }

    private func showSnippetEditor(item: ClipboardItem?) {
        // ペーストパネルを閉じる
        popupController.close(restoreFocus: false)

        if let snippetEditorWindow {
            snippetEditorWindow.close()
        }

        let editorView = SnippetEditorView(
            clipboardManager: clipboardManager,
            item: item,
            onDismiss: { [weak self] in
                self?.snippetEditorWindow?.close()
                self?.snippetEditorWindow = nil
            }
        )

        let window = NSWindow(
            contentViewController: NSHostingController(rootView: editorView)
        )
        window.styleMask = [.titled, .closable, .resizable]
        window.title = item != nil ? String(localized: "Edit Snippet") : String(localized: "New Snippet")
        window.setContentSize(NSSize(width: 500, height: 400))
        window.isReleasedWhenClosed = false
        self.snippetEditorWindow = window

        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func handleShowSettings() {
        // MenuBarExtra パネルを閉じる
        for window in NSApp.windows where window is NSPanel && window.isVisible {
            window.orderOut(nil)
        }

        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let tabVC = NSTabViewController()
        tabVC.tabStyle = .toolbar
        tabVC.title = String(localized: "Settings")

        #if ENABLE_SPARKLE
        let generalItem = NSTabViewItem(viewController: NSHostingController(
            rootView: GeneralTab(updateManager: updateManager).formStyle(.grouped)
        ))
        #else
        let generalItem = NSTabViewItem(viewController: NSHostingController(
            rootView: GeneralTab().formStyle(.grouped)
        ))
        #endif
        generalItem.label = String(localized: "General")
        generalItem.image = NSImage(systemSymbolName: "gear", accessibilityDescription: nil)
        tabVC.addTabViewItem(generalItem)

        let historyItem = NSTabViewItem(viewController: NSHostingController(
            rootView: HistoryTab(clipboardManager: clipboardManager).formStyle(.grouped)
        ))
        historyItem.label = String(localized: "History")
        historyItem.image = NSImage(systemSymbolName: "clock", accessibilityDescription: nil)
        tabVC.addTabViewItem(historyItem)

        let snippetsItem = NSTabViewItem(viewController: NSHostingController(
            rootView: SnippetsTab(clipboardManager: clipboardManager).formStyle(.grouped)
        ))
        snippetsItem.label = String(localized: "Snippets")
        snippetsItem.image = NSImage(systemSymbolName: "tag", accessibilityDescription: nil)
        tabVC.addTabViewItem(snippetsItem)

        let filterItem = NSTabViewItem(viewController: NSHostingController(
            rootView: FilterTab(clipboardManager: clipboardManager).formStyle(.grouped)
        ))
        filterItem.label = String(localized: "Filter")
        filterItem.image = NSImage(systemSymbolName: "line.3.horizontal.decrease.circle", accessibilityDescription: nil)
        tabVC.addTabViewItem(filterItem)

        let window = NSWindow(contentViewController: tabVC)
        window.styleMask = [.titled, .closable]
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.settingsWindow = window

        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === settingsWindow else { return }
        settingsWindow = nil
        NSApp.setActivationPolicy(.accessory)
    }
}

extension Notification.Name {
    static let openSettingsRequest = Notification.Name("openSettingsRequest")
    static let openPopupPanel = Notification.Name("openPopupPanel")
    static let closePopupPanel = Notification.Name("closePopupPanel")
    static let openSnippetEditor = Notification.Name("openSnippetEditor")
    static let createNewSnippet = Notification.Name("createNewSnippet")
}
