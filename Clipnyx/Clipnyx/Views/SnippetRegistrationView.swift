import SwiftUI

struct SnippetRegistrationView: View {
    var clipboardManager: ClipboardManager
    let item: ClipboardItem
    let onDismiss: () -> Void

    @State private var name: String = ""
    @State private var selectedCategoryId: UUID?
    @State private var newCategoryName: String = ""
    @State private var showNewCategory = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Register as Snippet")
                .font(.headline)

            TextField("Snippet Name", text: $name)
                .textFieldStyle(.roundedBorder)

            if showNewCategory {
                HStack {
                    TextField("New Category", text: $newCategoryName)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        guard !newCategoryName.isEmpty else { return }
                        let category = clipboardManager.addSnippetCategory(name: newCategoryName)
                        selectedCategoryId = category.id
                        newCategoryName = ""
                        showNewCategory = false
                    }
                    .disabled(newCategoryName.isEmpty)
                    Button("Cancel") {
                        showNewCategory = false
                        newCategoryName = ""
                    }
                }
            } else {
                HStack {
                    Picker("Category", selection: $selectedCategoryId) {
                        Text("None").tag(UUID?.none)
                        ForEach(clipboardManager.snippetCategories.sorted(by: { $0.order < $1.order })) { cat in
                            Text(cat.name).tag(UUID?.some(cat.id))
                        }
                    }
                    Button {
                        showNewCategory = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Register") {
                    let categoryId: UUID
                    if let selected = selectedCategoryId {
                        categoryId = selected
                    } else {
                        let category = clipboardManager.addSnippetCategory(name: String(localized: "General"))
                        categoryId = category.id
                    }
                    clipboardManager.registerAsSnippet(item, name: name, categoryId: categoryId)
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
        .onAppear {
            name = String(item.previewText.prefix(while: { $0 != "\n" }).prefix(50))
            selectedCategoryId = clipboardManager.snippetCategories.first?.id
        }
    }
}
