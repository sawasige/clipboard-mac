import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    @Environment(ClipboardManager.self) private var clipboardManager

    var body: some View {
        @Bindable var manager = clipboardManager
        TabView {
            GeneralTab(clipboardManager: clipboardManager)
                .tabItem {
                    Label("一般", systemImage: "gear")
                }

            FilterTab(clipboardManager: clipboardManager)
                .tabItem {
                    Label("フィルタ", systemImage: "line.3.horizontal.decrease.circle")
                }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 350)
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    @Bindable var clipboardManager: ClipboardManager

    private let historyCountOptions = [20, 50, 100, 200, 500]
    private let maxSizeOptions = [10, 25, 50, 100]

    var body: some View {
        Form {
            Section("履歴") {
                Picker("最大履歴数", selection: $clipboardManager.maxHistoryCount) {
                    ForEach(historyCountOptions, id: \.self) { count in
                        Text("\(count)件").tag(count)
                    }
                }

                Picker("1アイテムの最大サイズ", selection: $clipboardManager.maxItemSizeMB) {
                    ForEach(maxSizeOptions, id: \.self) { size in
                        Text("\(size) MB").tag(size)
                    }
                }

                LabeledContent("使用容量") {
                    Text(clipboardManager.formattedTotalSize)
                }

                LabeledContent("アイテム数") {
                    Text("\(clipboardManager.items.count)件")
                }
            }

            Section {
                Button("すべての履歴を削除", role: .destructive) {
                    clipboardManager.removeAllItems()
                }
            }

            Section("アクセシビリティ") {
                AccessibilityStatusView()
            }

            Section("起動") {
                LaunchAtLoginToggle()
            }

            Section("ホットキー") {
                HotKeyRecorderRow()
            }

            Section("情報") {
                LabeledContent("バージョン") {
                    Text("1.0.0")
                }
            }
        }
    }
}

// MARK: - Launch at Login

private struct LaunchAtLoginToggle: View {
    @State private var isEnabled = SMAppService.mainApp.status == .enabled

    var body: some View {
        Toggle("ログイン時に起動", isOn: $isEnabled)
            .onChange(of: isEnabled) { _, newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    isEnabled = SMAppService.mainApp.status == .enabled
                }
            }
    }
}

// MARK: - Accessibility Status

private struct AccessibilityStatusView: View {
    @State private var isGranted = AXIsProcessTrusted()
    var body: some View {
        LabeledContent("権限の状態") {
            HStack(spacing: 6) {
                Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(isGranted ? .green : .red)
                Text(isGranted ? "許可済み" : "未許可")
            }
        }

        if !isGranted {
            Text("ペースト機能とカーソル位置検出にはアクセシビリティ権限が必要です。許可後、アプリの再起動が必要な場合があります。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("システム設定を開く") {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                )
            }
        }

        Button("状態を更新") {
            isGranted = AXIsProcessTrusted()
        }
        .font(.caption)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                isGranted = AXIsProcessTrusted()
            }
        }
    }
}

// MARK: - Hot Key Recorder

private struct HotKeyRecorderRow: View {
    @State private var keyCode: UInt32 = HotKeyManager.shared.currentKeyCode
    @State private var modifiers: UInt = HotKeyManager.shared.currentModifiers
    @State private var isRecording = false
    @State private var eventMonitor: Any?

    private var displayString: String {
        HotKeyManager.displayString(keyCode: keyCode, modifiers: modifiers)
    }

    var body: some View {
        LabeledContent("ホットキー") {
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                Text(isRecording ? "キーを入力..." : displayString)
                    .frame(minWidth: 80)
            }
            .keyboardShortcut(.none)
        }
    }

    private func startRecording() {
        HotKeyManager.shared.unregister()
        isRecording = true

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let cocoaModifiers = event.modifierFlags
                .intersection([.command, .shift, .option, .control]).rawValue
            // Require at least one modifier key (⌘, ⌥, ⌃, ⇧)
            guard cocoaModifiers != 0 else { return nil }

            let newKeyCode = UInt32(event.keyCode)
            keyCode = newKeyCode
            modifiers = cocoaModifiers

            HotKeyManager.shared.currentKeyCode = newKeyCode
            HotKeyManager.shared.currentModifiers = cocoaModifiers

            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        guard isRecording else { return }
        isRecording = false
        HotKeyManager.shared.register()
    }
}

// MARK: - Filter Tab

private struct FilterTab: View {
    @Bindable var clipboardManager: ClipboardManager

    var body: some View {
        Form {
            Section("カテゴリフィルタ") {
                Text("無効にしたカテゴリのコピーは記録されません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(ClipboardContentCategory.allCases, id: \.self) { category in
                    Toggle(isOn: Binding(
                        get: { !clipboardManager.excludedCategories.contains(category) },
                        set: { isEnabled in
                            if isEnabled {
                                clipboardManager.excludedCategories.remove(category)
                            } else {
                                clipboardManager.excludedCategories.insert(category)
                            }
                        }
                    )) {
                        Label {
                            Text(category.label)
                        } icon: {
                            Image(systemName: category.icon)
                                .foregroundStyle(category.color)
                        }
                    }
                }
            }
        }
    }
}
