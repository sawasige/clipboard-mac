import SwiftUI

struct FavoriteManagerView: View {
    var clipboardManager: ClipboardManager
    @State var selectedFolderFilter: FolderFilter = .all
    @State var selectedItemId: UUID?
    @State private var newFolderName = ""
    @State private var renamingFolderId: UUID?
    @State private var renamingText = ""
    @FocusState private var isRenamingFocused: Bool
    @FocusState private var focusedArea: FocusArea?

    enum FocusArea: Hashable {
        case sidebar
        case detail
    }

    enum FolderFilter: Hashable {
        case all
        case uncategorized
        case folder(UUID)
    }

    private var filteredItems: [ClipboardItem] {
        let saved = clipboardManager.items.filter(\.isSaved)
        switch selectedFolderFilter {
        case .all:
            return saved
        case .uncategorized:
            return saved.filter { $0.favoriteFolderId == nil }
        case .folder(let id):
            return saved.filter { $0.favoriteFolderId == id }
        }
    }

    private var selectedItem: ClipboardItem? {
        guard let id = selectedItemId else { return nil }
        return clipboardManager.items.first(where: { $0.id == id })
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            favoriteList
        } detail: {
            detailArea
        }
        .frame(minWidth: 800, minHeight: 500)
        .onChange(of: selectedFolderFilter) { _, _ in
            selectedItemId = nil
        }
        .background {
            // Delete: Backspaceキーで選択中フォルダを削除（サイドバーフォーカス時のみ）
            Button("") {
                guard focusedArea == .sidebar else { return }
                if case .folder(let id) = selectedFolderFilter {
                    clipboardManager.deleteFavoriteFolder(id: id)
                    selectedFolderFilter = .all
                }
            }
            .keyboardShortcut(.delete, modifiers: [])
            .hidden()

            // Return: 選択中フォルダの名前編集（サイドバーフォーカス時のみ）
            Button("") {
                guard focusedArea == .sidebar else { return }
                if case .folder(let id) = selectedFolderFilter,
                   let folder = clipboardManager.favoriteFolders.first(where: { $0.id == id }) {
                    renamingText = folder.name
                    renamingFolderId = id
                }
            }
            .keyboardShortcut(.return, modifiers: [])
            .hidden()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedFolderFilter) {
            Label("All Saved", systemImage: "bookmark.fill")
                .tag(FolderFilter.all)
            Label("Uncategorized", systemImage: "tray")
                .tag(FolderFilter.uncategorized)

            Section("Folders") {
                ForEach(clipboardManager.favoriteFolders.sorted(by: { $0.order < $1.order })) { folder in
                    if renamingFolderId == folder.id {
                        TextField("", text: $renamingText, onCommit: {
                            if !renamingText.isEmpty {
                                clipboardManager.renameFavoriteFolder(id: folder.id, name: renamingText)
                            }
                            renamingFolderId = nil
                            isRenamingFocused = false
                        })
                        .textFieldStyle(.roundedBorder)
                        .focused($isRenamingFocused)
                        .onAppear { isRenamingFocused = true }
                        .onExitCommand {
                            renamingFolderId = nil
                            isRenamingFocused = false
                        }
                    } else {
                        Label(folder.name, systemImage: "folder")
                            .tag(FolderFilter.folder(folder.id))
                            .contextMenu {
                                Button("Rename") {
                                    renamingText = folder.name
                                    renamingFolderId = folder.id
                                }
                                Button("Delete Folder", role: .destructive) {
                                    clipboardManager.deleteFavoriteFolder(id: folder.id)
                                }
                            }
                    }
                }
                .onMove { from, to in
                    var sorted = clipboardManager.favoriteFolders.sorted(by: { $0.order < $1.order })
                    sorted.move(fromOffsets: from, toOffset: to)
                    for i in sorted.indices {
                        sorted[i].order = i
                    }
                    clipboardManager.reorderFavoriteFolders(sorted)
                }
                .onDelete { offsets in
                    let sorted = clipboardManager.favoriteFolders.sorted(by: { $0.order < $1.order })
                    for index in offsets {
                        clipboardManager.deleteFavoriteFolder(id: sorted[index].id)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .focusable()
        .focused($focusedArea, equals: .sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack {
                TextField("New Folder", text: $newFolderName)
                    .textFieldStyle(.roundedBorder)
                Button {
                    guard !newFolderName.isEmpty else { return }
                    _ = clipboardManager.addFavoriteFolder(name: newFolderName)
                    newFolderName = ""
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(newFolderName.isEmpty)
            }
            .padding(8)
        }
        .navigationSplitViewColumnWidth(min: 160, ideal: 180)
    }

    // MARK: - Favorite List

    private var favoriteList: some View {
        Group {
            if filteredItems.isEmpty {
                ContentUnavailableView {
                    Label("No Favorites", systemImage: "bookmark.slash")
                } description: {
                    Text("Save items to keep them here")
                }
            } else {
                List(filteredItems, selection: $selectedItemId) { item in
                    HStack(spacing: 8) {
                        // Category icon
                        Image(systemName: item.category.icon)
                            .font(.callout)
                            .foregroundStyle(item.category.color)
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 3) {
                            if let name = item.favoriteName, !name.isEmpty {
                                Text(name)
                                    .font(.body.bold())
                                    .lineLimit(1)
                            }
                            ItemPreviewContent(item: item, maxThumbnailHeight: 30)
                            if let folderId = item.favoriteFolderId,
                               let folder = clipboardManager.favoriteFolders.first(where: { $0.id == folderId }) {
                                Text(folder.name)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .frame(minHeight: 36)
                    .tag(item.id)
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        .toolbar {
            ToolbarItem {
                Button {
                    let defaultFolderId: UUID? = {
                        if case .folder(let id) = selectedFolderFilter { return id }
                        return nil
                    }()
                    clipboardManager.createFavorite(text: "", name: "", folderId: defaultFolderId)
                    if let newItem = clipboardManager.items.first {
                        selectedItemId = newItem.id
                    }
                } label: {
                    Label("New Favorite", systemImage: "plus")
                }
            }
        }
    }

    // MARK: - Detail (auto-save editor)

    @ViewBuilder
    private var detailArea: some View {
        if let item = selectedItem {
            FavoriteInlineEditor(clipboardManager: clipboardManager, itemId: item.id)
                .id(item.id)
        } else {
            ContentUnavailableView {
                Label("No Selection", systemImage: "square.dashed")
            } description: {
                Text("Select a favorite to edit")
            }
        }
    }
}

// MARK: - Inline Editor (auto-save)

private struct FavoriteInlineEditor: View {
    var clipboardManager: ClipboardManager
    let itemId: UUID

    @State private var name: String = ""
    @State private var selectedFolderId: UUID?
    @State private var text: String = ""

    private var item: ClipboardItem? {
        clipboardManager.items.first(where: { $0.id == itemId })
    }

    private var isTextEditable: Bool {
        guard let item else { return false }
        return item.category == .plainText
    }

    private let labelWidth: CGFloat = 100

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Favorite Name
                HStack(alignment: .top) {
                    Text("Favorite Name")
                        .frame(width: labelWidth, alignment: .trailing)
                    TextField("", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: name) { _, newValue in
                            if let item {
                                clipboardManager.updateFavoriteName(item, name: newValue)
                            }
                        }
                }

                // Folder
                HStack(alignment: .top) {
                    Text("Folder")
                        .frame(width: labelWidth, alignment: .trailing)
                    Picker("", selection: $selectedFolderId) {
                        Text("None").tag(UUID?.none)
                        ForEach(clipboardManager.favoriteFolders.sorted(by: { $0.order < $1.order })) { folder in
                            Text(folder.name).tag(UUID?.some(folder.id))
                        }
                    }
                    .labelsHidden()
                    .onChange(of: selectedFolderId) { _, newValue in
                        if let item {
                            clipboardManager.updateFavoriteFolder(item, folderId: newValue)
                        }
                    }
                }

                Divider()

                // Content / Preview
                if isTextEditable {
                    HStack(alignment: .top) {
                        Text("Content")
                            .frame(width: labelWidth, alignment: .trailing)
                        TextEditor(text: $text)
                            .font(.system(size: 13, design: .monospaced))
                            .frame(minHeight: 200)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color(nsColor: .separatorColor))
                            )
                            .onChange(of: text) { _, newValue in
                                if let item {
                                    clipboardManager.updateFavoriteContent(item, text: newValue)
                                }
                            }
                    }
                } else if let item {
                    HStack(alignment: .top) {
                        Text("Preview")
                            .frame(width: labelWidth, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 8) {
                            if let thumbnailData = item.thumbnailData,
                               let nsImage = NSImage(data: thumbnailData) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            Text(item.previewText)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(10)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(8)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(nsColor: .separatorColor))
                        )
                    }
                }

                Divider()

                // Unsave
                if item?.isSaved == true {
                    Button("Unsave", role: .destructive) {
                        if let item {
                            clipboardManager.toggleSave(item)
                        }
                    }
                }
            }
            .padding()
        }
        .onAppear { loadItem() }
    }

    private func loadItem() {
        guard let item else { return }
        name = item.favoriteName ?? ""
        selectedFolderId = item.favoriteFolderId
        if let reps = clipboardManager.store.loadRepresentations(for: item.id),
           let stringRep = reps.first(where: { $0.pasteboardType == .string }),
           let str = String(data: stringRep.data, encoding: .utf8) {
            text = str
        } else {
            text = item.previewText
        }
    }
}
