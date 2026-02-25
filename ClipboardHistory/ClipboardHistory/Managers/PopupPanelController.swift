import AppKit
import SwiftUI
import Observation

// MARK: - KeyablePanel

private class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
@Observable
final class PopupPanelController {
    private var panel: NSPanel?
    private var previousApp: NSRunningApplication?
    private var clickMonitor: Any?
    private var appDeactivationObserver: Any?
    var isVisible: Bool = false

    func toggle(clipboardManager: ClipboardManager) {
        if isVisible {
            close()
        } else {
            show(clipboardManager: clipboardManager)
        }
    }

    func show(clipboardManager: ClipboardManager) {
        guard !isVisible else { return }

        // パネル表示前の最前面アプリを記憶（自分自身は除外）
        let myBundleID = Bundle.main.bundleIdentifier
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost?.bundleIdentifier != myBundleID {
            previousApp = frontmost
        }

        let panelWidth: CGFloat = 380
        let panelHeight: CGFloat = 480

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Position at text cursor, fallback to mouse
        let anchorPoint = Self.textCursorPosition() ?? NSEvent.mouseLocation
        var panelOrigin = NSPoint(
            x: anchorPoint.x,
            y: anchorPoint.y - panelHeight
        )

        // Screen edge correction
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(anchorPoint) }) ?? NSScreen.main {
            let visibleFrame = screen.visibleFrame

            if panelOrigin.x < visibleFrame.minX {
                panelOrigin.x = visibleFrame.minX
            }
            if panelOrigin.x + panelWidth > visibleFrame.maxX {
                panelOrigin.x = visibleFrame.maxX - panelWidth
            }
            if panelOrigin.y < visibleFrame.minY {
                panelOrigin.y = visibleFrame.minY
            }
            if panelOrigin.y + panelHeight > visibleFrame.maxY {
                panelOrigin.y = visibleFrame.maxY - panelHeight
            }
        }

        panel.setFrameOrigin(panelOrigin)

        let contentView = PopupContentView(
            clipboardManager: clipboardManager,
            onDismiss: { [weak self] in
                self?.close()
            },
            onPaste: { [weak self] in
                self?.closeAndPaste()
            }
        )

        panel.contentView = NSHostingView(rootView: contentView)

        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
        self.isVisible = true

        // パネル外クリックで閉じる
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }

        // ⌘Tab 等で他のアプリがアクティブになったら閉じる
        appDeactivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
            self?.close()
        }
    }

    func close() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        if let observer = appDeactivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            appDeactivationObserver = nil
        }
        panel?.orderOut(nil)
        panel = nil
        isVisible = false
    }

    func closeAndPaste() {
        let targetApp = previousApp
        close()

        guard let targetApp else { return }

        targetApp.activate()
        performPaste(targetPID: targetApp.processIdentifier, attempt: 0)
    }

    private func performPaste(targetPID: pid_t, attempt: Int) {
        let maxAttempts = 8
        let delay = 0.1

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

            if frontPID != targetPID, attempt < maxAttempts {
                self.performPaste(targetPID: targetPID, attempt: attempt + 1)
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                Self.tryPaste(targetPID: targetPID)
            }
        }
    }

    private static func tryPaste(targetPID: pid_t) {
        // AX API でフォーカス要素にテキストを直接挿入
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        let focusErr = AXUIElementCopyAttributeValue(
            systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef
        )

        let appElement = AXUIElementCreateApplication(targetPID)
        var appFocusedRef: CFTypeRef?
        let appFocusErr = AXUIElementCopyAttributeValue(
            appElement, kAXFocusedUIElementAttribute as CFString, &appFocusedRef
        )

        let element: AXUIElement? = if focusErr == .success, let ref = focusedRef {
            (ref as! AXUIElement)
        } else if appFocusErr == .success, let ref = appFocusedRef {
            (ref as! AXUIElement)
        } else {
            nil
        }

        if let element, let text = NSPasteboard.general.string(forType: .string) {
            let setErr = AXUIElementSetAttributeValue(
                element, kAXSelectedTextAttribute as CFString, text as CFTypeRef
            )
            if setErr == .success { return }
        }

        // フォールバック: CGEvent ⌘V
        postPasteEvent()
    }

    // MARK: - Paste Event Fallback

    private static func postPasteEvent() {
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false) else { return }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            keyUp.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Text Cursor Position via Accessibility API

    private static func textCursorPosition() -> NSPoint? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)

        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success else {
            return nil
        }

        let element = focusedElement as! AXUIElement

        // Get selected text range
        var selectedRangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRangeValue) == .success else {
            return nil
        }

        // Get bounds of the selected text range
        var boundsValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            selectedRangeValue!,
            &boundsValue
        ) == .success else {
            return nil
        }

        var rect = CGRect.zero
        guard AXValueGetValue(boundsValue as! AXValue, .cgRect, &rect) else {
            return nil
        }

        // AX coordinates: top-left origin → convert to AppKit bottom-left origin
        guard let screenHeight = NSScreen.main?.frame.height else { return nil }
        let x = rect.origin.x
        let y = screenHeight - rect.origin.y - rect.height

        return NSPoint(x: x, y: y)
    }
}
