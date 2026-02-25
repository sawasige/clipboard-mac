import SwiftUI

struct MenuBarView: View {
    @Environment(ClipboardManager.self) private var clipboardManager

    @State private var searchText = ""
    @State private var selectedCategory: ClipboardContentCategory?
    @State private var hoveredItemID: UUID?
    @State private var detailItem: ClipboardItem?
    @FocusState private var isSearchFocused: Bool

    private var filteredItems: [ClipboardItem] {
        var result = clipboardManager.items
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.previewText.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("検索...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                // Pause toggle
                Button {
                    clipboardManager.isPaused.toggle()
                } label: {
                    Image(systemName: clipboardManager.isPaused ? "play.fill" : "pause.fill")
                        .contentTransition(.symbolEffect(.replace))
                        .foregroundStyle(clipboardManager.isPaused ? .orange : .secondary)
                }
                .buttonStyle(.plain)
                .help(clipboardManager.isPaused ? "監視を再開" : "監視を一時停止")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Category filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    MenuFilterChip(
                        label: "すべて",
                        icon: "tray.full",
                        isSelected: selectedCategory == nil,
                        color: .accentColor
                    ) {
                        selectedCategory = nil
                    }

                    ForEach(activeCategories, id: \.self) { category in
                        MenuFilterChip(
                            label: category.label,
                            icon: category.icon,
                            isSelected: selectedCategory == category,
                            color: category.color
                        ) {
                            selectedCategory = selectedCategory == category ? nil : category
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            Divider()

            // History list
            if filteredItems.isEmpty {
                ContentUnavailableView {
                    Label("履歴なし", systemImage: "clipboard")
                } description: {
                    Text(searchText.isEmpty ? "コピーした内容がここに表示されます" : "検索結果が見つかりません")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredItems) { item in
                            MenuItemRow(
                                item: item,
                                isHovered: hoveredItemID == item.id,
                                onSelect: {
                                    clipboardManager.restoreToClipboard(item)
                                },
                                onShowDetail: {
                                    detailItem = item
                                },
                                onDelete: {
                                    clipboardManager.removeItem(item)
                                }
                            )
                            .onHover { isHovering in
                                hoveredItemID = isHovering ? item.id : nil
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 450)
            }

            Divider()

            // Footer
            HStack {
                Text("\(clipboardManager.items.count)件")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("・")
                    .foregroundStyle(.secondary)
                Text(clipboardManager.formattedTotalSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("全削除") {
                    clipboardManager.removeAllItems()
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(.red)

                Text("・")
                    .foregroundStyle(.secondary)

                SettingsLink {
                    Text("設定...")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded {
                    NSApp.activate(ignoringOtherApps: true)
                })

                Text("・")
                    .foregroundStyle(.secondary)

                Button("終了") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.caption)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 360)
        .popover(item: $detailItem) { item in
            ItemDetailView(item: item)
        }
    }

    private var activeCategories: [ClipboardContentCategory] {
        let present = Set(clipboardManager.items.map(\.category))
        return ClipboardContentCategory.allCases.filter { present.contains($0) }
    }

}

// MARK: - Subviews

private struct MenuFilterChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? color.opacity(0.2) : Color.clear)
            .foregroundStyle(isSelected ? color : .secondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? color.opacity(0.5) : Color.secondary.opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MenuItemRow: View {
    let item: ClipboardItem
    let isHovered: Bool
    let onSelect: () -> Void
    let onShowDetail: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Category icon
            Image(systemName: item.category.icon)
                .font(.caption)
                .foregroundStyle(item.category.color)
                .frame(width: 16)

            // Thumbnail or preview text
            if let thumbnailData = item.thumbnailData,
               let nsImage = NSImage(data: thumbnailData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.previewText)
                    .font(.system(size: 12))
                    .lineLimit(2)
                    .truncationMode(.tail)
                Text(item.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isHovered {
                Button {
                    onShowDetail()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            } else {
                Text(item.formattedDataSize)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}
