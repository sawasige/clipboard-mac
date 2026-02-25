@preconcurrency import Carbon
import AppKit

final class HotKeyManager: @unchecked Sendable {
    static let shared = HotKeyManager()

    private static let defaultKeyCode: UInt32 = 9 // V key
    private static let defaultModifiers: UInt32 = UInt32(cmdKey | shiftKey)

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    var onHotKey: (() -> Void)?

    var currentKeyCode: UInt32 {
        get {
            let stored = UserDefaults.standard.object(forKey: "hotKeyKeyCode") as? UInt32
            return stored ?? Self.defaultKeyCode
        }
        set { UserDefaults.standard.set(newValue, forKey: "hotKeyKeyCode") }
    }

    var currentModifiers: UInt32 {
        get {
            let stored = UserDefaults.standard.object(forKey: "hotKeyModifiers") as? UInt32
            return stored ?? Self.defaultModifiers
        }
        set { UserDefaults.standard.set(newValue, forKey: "hotKeyModifiers") }
    }

    private init() {}

    // MARK: - Registration

    func register() {
        unregister()

        let hotKeyID = EventHotKeyID(signature: OSType(0x434C4950), id: 1) // "CLIP"

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
            currentKeyCode,
            currentModifiers,
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

    // MARK: - Display Helpers

    static func keyCodeToString(_ keyCode: UInt32) -> String {
        guard let inputSource = TISCopyCurrentASCIICapableKeyboardInputSource()?.takeRetainedValue(),
              let layoutDataPtr = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else {
            return "?"
        }
        let layoutData = unsafeBitCast(layoutDataPtr, to: CFData.self)
        let keyboardLayout = unsafeBitCast(CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self)

        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length: Int = 0

        let status = UCKeyTranslate(
            keyboardLayout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            chars.count,
            &length,
            &chars
        )

        guard status == noErr, length > 0 else { return "?" }
        return String(utf16CodeUnits: chars, count: length).uppercased()
    }

    static func modifiersToString(_ modifiers: UInt32) -> String {
        var result = ""
        if modifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { result += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { result += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { result += "⌘" }
        return result
    }

    static func displayString(keyCode: UInt32, modifiers: UInt32) -> String {
        modifiersToString(modifiers) + keyCodeToString(keyCode)
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
