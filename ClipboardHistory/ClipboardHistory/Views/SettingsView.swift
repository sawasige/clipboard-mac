import SwiftUI
import AppKit

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

            Section("情報") {
                LabeledContent("バージョン") {
                    Text("1.0.0")
                }
                LabeledContent("ホットキー") {
                    Text("⌘+Shift+V")
                }
            }
        }
    }
}

// MARK: - Filter Tab

// MARK: - Accessibility Status

private struct AccessibilityStatusView: View {
    @State private var isGranted = AXIsProcessTrusted()
    @State private var timer: Timer?

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
        .onAppear {
            // 権限変更を自動検知（2秒間隔）
            timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
                let current = AXIsProcessTrusted()
                if current != isGranted {
                    DispatchQueue.main.async {
                        isGranted = current
                    }
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
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
