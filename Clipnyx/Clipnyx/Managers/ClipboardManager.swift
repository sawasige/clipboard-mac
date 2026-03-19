import AppKit
import Observation

@Observable
final class ClipboardManager: @unchecked Sendable {
    var items: [ClipboardItem] = []
    var isPaused: Bool = false

    var maxHistoryCount: Int {
        didSet { UserDefaults.standard.set(maxHistoryCount, forKey: "maxHistoryCount") }
    }

    var maxTotalSizeMB: Int {
        didSet { UserDefaults.standard.set(maxTotalSizeMB, forKey: "maxTotalSizeMB") }
    }

    var excludedCategories: Set<ClipboardContentCategory> {
        didSet { UserDefaults.standard.set(excludedCategories.map(\.rawValue), forKey: "excludedCategories") }
    }

    private(set) var isRestoringItem: Bool = false
    private var lastChangeCount: Int = 0
    private var pollingTimer: Timer?
    private let store = ClipboardStore()

    init() {
        maxHistoryCount = UserDefaults.standard.object(forKey: "maxHistoryCount") as? Int ?? 50
        maxTotalSizeMB = UserDefaults.standard.object(forKey: "maxTotalSizeMB") as? Int ?? 1024
        if let raw = UserDefaults.standard.stringArray(forKey: "excludedCategories") {
            excludedCategories = Set(raw.compactMap { ClipboardContentCategory(rawValue: $0) })
        } else {
            excludedCategories = []
        }
        items = store.loadIndex()
        store.cleanupOrphans(validIDs: Set(items.map(\.id)))
        lastChangeCount = NSPasteboard.general.changeCount
        startPolling()
    }

    deinit {
        pollingTimer?.invalidate()
    }

    // MARK: - Polling

    func startPolling() {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func checkForChanges() {
        guard !isPaused, !isRestoringItem else { return }

        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        guard let (newItem, representations) = ClipboardItem.capture(from: pasteboard) else { return }

        // Check excluded categories
        guard !excludedCategories.contains(newItem.category) else { return }

        addItem(newItem, representations: representations)
    }

    // MARK: - Item Management

    private func addItem(_ newItem: ClipboardItem, representations: [PasteboardRepresentation]) {
        // ピン留めアイテムの重複は除外しない
        let duplicateIDs = items.filter { !$0.isPinned && $0.hasSameContent(as: newItem) }.map(\.id)

        // Remove duplicates (unpinned only)
        items.removeAll { !$0.isPinned && $0.hasSameContent(as: newItem) }

        // Insert at front
        items.insert(newItem, at: 0)

        // Enforce count limit (unpinned only)
        var removedIDs = duplicateIDs
        let unpinnedCount = items.filter({ !$0.isPinned }).count
        if unpinnedCount > maxHistoryCount {
            // 末尾から unpinned を削除
            var removeCount = unpinnedCount - maxHistoryCount
            var i = items.count - 1
            while i >= 0, removeCount > 0 {
                if !items[i].isPinned {
                    removedIDs.append(items[i].id)
                    items.remove(at: i)
                    removeCount -= 1
                }
                i -= 1
            }
        }

        // Enforce total size limit (unpinned only)
        let maxBytes = maxTotalSizeMB * 1024 * 1024
        while items.filter({ !$0.isPinned }).count > 1, totalDataSize > maxBytes {
            if let lastUnpinnedIndex = items.lastIndex(where: { !$0.isPinned }) {
                removedIDs.append(items[lastUnpinnedIndex].id)
                items.remove(at: lastUnpinnedIndex)
            } else {
                break
            }
        }

        // Save blobs first, then index
        store.saveBlobs(for: newItem.id, representations: representations, thumbnail: newItem.thumbnailData)
        store.saveIndex(items)
        if !removedIDs.isEmpty {
            store.deleteBlobs(for: removedIDs)
        }
    }

    func removeItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        store.saveIndex(items)
        store.deleteBlobs(for: [item.id])
    }

    func removeAllItems() {
        // ピン留めアイテムは残す
        let pinned = items.filter(\.isPinned)
        let removedIDs = items.filter { !$0.isPinned }.map(\.id)
        items = pinned
        store.saveIndex(items)
        if !removedIDs.isEmpty {
            store.deleteBlobs(for: removedIDs)
        }
    }

    // MARK: - Pin

    func togglePin(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        store.saveIndex(items)
    }

    // MARK: - Restore

    func restoreToClipboard(_ item: ClipboardItem, asPlainText: Bool = false) {
        isRestoringItem = true

        // Load representations from disk and restore to pasteboard
        if let reps = store.loadRepresentations(for: item.id) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            if asPlainText {
                if let stringRep = reps.first(where: { $0.pasteboardType == .string }) {
                    pasteboard.declareTypes([.string], owner: nil)
                    pasteboard.setData(stringRep.data, forType: .string)
                }
            } else {
                let types = reps.map(\.pasteboardType)
                pasteboard.declareTypes(types, owner: nil)
                for rep in reps {
                    pasteboard.setData(rep.data, forType: rep.pasteboardType)
                }
            }
        }
        lastChangeCount = NSPasteboard.general.changeCount

        // 使用したアイテムを先頭に移動
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let index = self.items.firstIndex(where: { $0.id == item.id }) {
                let moved = self.items.remove(at: index)
                self.items.insert(moved, at: 0)
            }
            self.store.saveIndex(self.items)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isRestoringItem = false
        }
    }

    // MARK: - Statistics

    var totalDataSize: Int {
        items.reduce(0) { $0 + $1.totalDataSize }
    }

    var formattedTotalSize: String {
        let bytes = totalDataSize
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
        }
    }

    var categoryCountMap: [ClipboardContentCategory: Int] {
        var map: [ClipboardContentCategory: Int] = [:]
        for item in items {
            map[item.category, default: 0] += 1
        }
        return map
    }
}
