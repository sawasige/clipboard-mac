import SwiftUI

struct SnippetManagerView: View {
    var clipboardManager: ClipboardManager
    @State var selectedCategoryFilter: CategoryFilter = .all
    @State var selectedItemId: UUID?
    @State private var newCategoryName = ""
    @State private var renamingCategoryId: UUID?
    @State private var renamingText = ""
    @FocusState private var isRenamingFocused: Bool
    @FocusState private var focusedArea: FocusArea?

    enum FocusArea: Hashable {
        case sidebar
        case detail
    }

    enum CategoryFilter: Hashable {
        case all
        case uncategorized
        case category(UUID)
    }

    private var filteredItems: [ClipboardItem] {
        let saved = clipboardManager.items.filter(\.isSaved)
        switch selectedCategoryFilter {
        case .all:
            return saved
        case .uncategorized:
            return saved.filter { $0.snippetCategoryId == nil }
        case .category(let id):
            return saved.filter { $0.snippetCategoryId == id }
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
            snippetList
        } detail: {
            detailArea
        }
        .frame(minWidth: 800, minHeight: 500)
        .onChange(of: selectedCategoryFilter) { _, _ in
            selectedItemId = nil
        }
        .background {
            // Delete: Backspaceキーで選択中カテゴリを削除（サイドバーフォーカス時のみ）
            Button("") {
                guard focusedArea == .sidebar else { return }
                if case .category(let id) = selectedCategoryFilter {
                    clipboardManager.deleteSnippetCategory(id: id)
                    selectedCategoryFilter = .all
                }
            }
            .keyboardShortcut(.delete, modifiers: [])
            .hidden()

            // Return: 選択中カテゴリの名前編集（サイドバーフォーカス時のみ）
            Button("") {
                guard focusedArea == .sidebar else { return }
                if case .category(let id) = selectedCategoryFilter,
                   let cat = clipboardManager.snippetCategories.first(where: { $0.id == id }) {
                    renamingText = cat.name
                    renamingCategoryId = id
                }
            }
            .keyboardShortcut(.return, modifiers: [])
            .hidden()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedCategoryFilter) {
            Label("All Saved", systemImage: "bookmark.fill")
                .tag(CategoryFilter.all)
            Label("Uncategorized", systemImage: "tray")
                .tag(CategoryFilter.uncategorized)

            Section("Categories") {
                ForEach(clipboardManager.snippetCategories.sorted(by: { $0.order < $1.order })) { cat in
                    if renamingCategoryId == cat.id {
                        TextField("", text: $renamingText, onCommit: {
                            if !renamingText.isEmpty {
                                clipboardManager.renameSnippetCategory(id: cat.id, name: renamingText)
                            }
                            renamingCategoryId = nil
                            isRenamingFocused = false
                        })
                        .textFieldStyle(.roundedBorder)
                        .focused($isRenamingFocused)
                        .onAppear { isRenamingFocused = true }
                        .onExitCommand {
                            renamingCategoryId = nil
                            isRenamingFocused = false
                        }
                    } else {
                        Label(cat.name, systemImage: "tag")
                            .tag(CategoryFilter.category(cat.id))
                            .contextMenu {
                                Button("Rename") {
                                    renamingText = cat.name
                                    renamingCategoryId = cat.id
                                }
                                Button("Delete Category", role: .destructive) {
                                    clipboardManager.deleteSnippetCategory(id: cat.id)
                                }
                            }
                    }
                }
                .onMove { from, to in
                    var sorted = clipboardManager.snippetCategories.sorted(by: { $0.order < $1.order })
                    sorted.move(fromOffsets: from, toOffset: to)
                    for i in sorted.indices {
                        sorted[i].order = i
                    }
                    clipboardManager.reorderSnippetCategories(sorted)
                }
                .onDelete { offsets in
                    let sorted = clipboardManager.snippetCategories.sorted(by: { $0.order < $1.order })
                    for index in offsets {
                        clipboardManager.deleteSnippetCategory(id: sorted[index].id)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .focusable()
        .focused($focusedArea, equals: .sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack {
                TextField("New Category", text: $newCategoryName)
                    .textFieldStyle(.roundedBorder)
                Button {
                    guard !newCategoryName.isEmpty else { return }
                    _ = clipboardManager.addSnippetCategory(name: newCategoryName)
                    newCategoryName = ""
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(newCategoryName.isEmpty)
            }
            .padding(8)
        }
        .navigationSplitViewColumnWidth(min: 160, ideal: 180)
    }

    // MARK: - Snippet List

    private var snippetList: some View {
        Group {
            if filteredItems.isEmpty {
                ContentUnavailableView {
                    Label("No Snippets", systemImage: "bookmark.slash")
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
                            if let name = item.snippetName, !name.isEmpty {
                                Text(name)
                                    .font(.body.bold())
                                    .lineLimit(1)
                            }
                            ItemPreviewContent(item: item, maxThumbnailHeight: 30)
                            if let catId = item.snippetCategoryId,
                               let cat = clipboardManager.snippetCategories.first(where: { $0.id == catId }) {
                                Text(cat.name)
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
                    let defaultCategoryId: UUID? = {
                        if case .category(let id) = selectedCategoryFilter { return id }
                        return nil
                    }()
                    clipboardManager.createSnippet(text: "", name: "", categoryId: defaultCategoryId)
                    if let newItem = clipboardManager.items.first {
                        selectedItemId = newItem.id
                    }
                } label: {
                    Label("New Snippet", systemImage: "plus")
                }
            }
        }
    }

    // MARK: - Detail (auto-save editor)

    @ViewBuilder
    private var detailArea: some View {
        if let item = selectedItem {
            SnippetInlineEditor(clipboardManager: clipboardManager, itemId: item.id)
                .id(item.id)
        } else {
            ContentUnavailableView {
                Label("No Selection", systemImage: "square.dashed")
            } description: {
                Text("Select a snippet to edit")
            }
        }
    }
}

// MARK: - Inline Editor (auto-save)

private struct SnippetInlineEditor: View {
    var clipboardManager: ClipboardManager
    let itemId: UUID

    @State private var name: String = ""
    @State private var selectedCategoryId: UUID?
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
                // Snippet Name
                HStack(alignment: .top) {
                    Text("Snippet Name")
                        .frame(width: labelWidth, alignment: .trailing)
                    TextField("", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: name) { _, newValue in
                            if let item {
                                clipboardManager.updateSnippetName(item, name: newValue)
                            }
                        }
                }

                // Category
                HStack(alignment: .top) {
                    Text("Category")
                        .frame(width: labelWidth, alignment: .trailing)
                    Picker("", selection: $selectedCategoryId) {
                        Text("None").tag(UUID?.none)
                        ForEach(clipboardManager.snippetCategories.sorted(by: { $0.order < $1.order })) { cat in
                            Text(cat.name).tag(UUID?.some(cat.id))
                        }
                    }
                    .labelsHidden()
                    .onChange(of: selectedCategoryId) { _, newValue in
                        if let item {
                            clipboardManager.updateSnippetCategory(item, categoryId: newValue)
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
                                    clipboardManager.updateSnippetContent(item, text: newValue)
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
        name = item.snippetName ?? ""
        selectedCategoryId = item.snippetCategoryId
        if let reps = clipboardManager.store.loadRepresentations(for: item.id),
           let stringRep = reps.first(where: { $0.pasteboardType == .string }),
           let str = String(data: stringRep.data, encoding: .utf8) {
            text = str
        } else {
            text = item.previewText
        }
    }
}
