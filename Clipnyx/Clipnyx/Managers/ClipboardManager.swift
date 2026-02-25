import AppKit
import Observation

@Observable
final class ClipboardManager: @unchecked Sendable {
    var items: [ClipboardItem] = []
    var isPaused: Bool = false
    var maxHistoryCount: Int = 50
    var maxItemSizeMB: Int = 50
    var excludedCategories: Set<ClipboardContentCategory> = []

    private(set) var isRestoringItem: Bool = false
    private var lastChangeCount: Int = 0
    private var pollingTimer: Timer?

    private static let historyDirectoryURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Clipnyx", isDirectory: true)
    }()

    private static let historyFileURL: URL = {
        historyDirectoryURL.appendingPathComponent("history.json")
    }()

    init() {
        loadHistory()
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

        guard let newItem = ClipboardItem(from: pasteboard) else { return }

        // Check excluded categories
        guard !excludedCategories.contains(newItem.category) else { return }

        addItem(newItem)
    }

    // MARK: - Item Management

    private func addItem(_ newItem: ClipboardItem) {
        // Remove duplicate
        items.removeAll { $0.hasSameContent(as: newItem) }

        // Insert at front
        items.insert(newItem, at: 0)

        // Enforce count limit
        if items.count > maxHistoryCount {
            items = Array(items.prefix(maxHistoryCount))
        }

        saveHistory()
    }

    func removeItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        saveHistory()
    }

    func removeAllItems() {
        items.removeAll()
        saveHistory()
    }

    func restoreToClipboard(_ item: ClipboardItem) {
        isRestoringItem = true
        item.restoreToPasteboard()
        lastChangeCount = NSPasteboard.general.changeCount

        // Move item to front
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            let moved = items.remove(at: index)
            items.insert(moved, at: 0)
            saveHistory()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isRestoringItem = false
        }
    }

    // MARK: - Persistence

    private func saveHistory() {
        let dirURL = Self.historyDirectoryURL
        do {
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(items)
            try data.write(to: Self.historyFileURL, options: .atomic)
        } catch {
            print("Failed to save history: \(error)")
        }
    }

    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: Self.historyFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: Self.historyFileURL)
            items = try JSONDecoder().decode([ClipboardItem].self, from: data)
        } catch {
            print("Failed to load history: \(error)")
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
