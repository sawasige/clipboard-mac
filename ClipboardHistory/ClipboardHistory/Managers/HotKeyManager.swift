@preconcurrency import Carbon
import AppKit

final class HotKeyManager: @unchecked Sendable {
    static let shared = HotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    var onHotKey: (() -> Void)?

    private init() {}

    // MARK: - Registration

    func register() {
        let hotKeyID = EventHotKeyID(signature: OSType(0x434C4950), id: 1) // "CLIP"
        // ⌘+Shift+V: keyCode 9 = V, modifiers: cmdKey + shiftKey
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
        let keyCode: UInt32 = 9 // V key

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // Install handler
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyCallback,
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandler
        )

        guard status == noErr else {
            print("Failed to install event handler: \(status)")
            return
        }

        var ref: EventHotKeyRef?
        let regStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        guard regStatus == noErr else {
            print("Failed to register hotkey: \(regStatus)")
            return
        }
        hotKeyRef = ref
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    // MARK: - Handler

    func handleHotKey() {
        DispatchQueue.main.async { [weak self] in
            self?.onHotKey?()
        }
    }

    // MARK: - Accessibility Check

    static func checkAccessibility() -> Bool {
        AXIsProcessTrusted()
    }
}

// C callback function
private func hotKeyCallback(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else { return OSStatus(eventNotHandledErr) }
    let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
    manager.handleHotKey()
    return noErr
}
