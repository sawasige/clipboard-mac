import Carbon.HIToolbox
import AppKit

final class HotKeyManager: @unchecked Sendable {
    static let shared = HotKeyManager()

    private static let defaultKeyCode: UInt32 = 9 // V key
    private static let defaultModifiers: UInt = NSEvent.ModifierFlags([.command, .shift]).rawValue

    private var globalMonitor: Any?
    var onHotKey: (() -> Void)?

    var currentKeyCode: UInt32 {
        get {
            let stored = UserDefaults.standard.object(forKey: "hotKeyKeyCode") as? UInt32
            return stored ?? Self.defaultKeyCode
        }
        set { UserDefaults.standard.set(newValue, forKey: "hotKeyKeyCode") }
    }

    var currentModifiers: UInt {
        get {
            let stored = UserDefaults.standard.object(forKey: "hotKeyModifiers") as? UInt
            return stored ?? Self.defaultModifiers
        }
        set { UserDefaults.standard.set(newValue, forKey: "hotKeyModifiers") }
    }

    private init() {}

    // MARK: - Registration

    func register() {
        unregister()

        let keyCode = UInt16(currentKeyCode)
        let modifiers = NSEvent.ModifierFlags(rawValue: currentModifiers)
            .intersection([.command, .shift, .option, .control])

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let eventMods = event.modifierFlags.intersection([.command, .shift, .option, .control])
            if event.keyCode == keyCode && eventMods == modifiers {
                self?.handleHotKey()
            }
        }
    }

    func unregister() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
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

    static func modifiersToString(_ modifiers: UInt) -> String {
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        var result = ""
        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option) { result += "⌥" }
        if flags.contains(.shift) { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }
        return result
    }

    static func displayString(keyCode: UInt32, modifiers: UInt) -> String {
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
