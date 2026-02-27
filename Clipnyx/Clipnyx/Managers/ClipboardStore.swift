import AppKit
import CryptoKit

final class ClipboardStore: Sendable {
    private let writeQueue = DispatchQueue(label: "com.clipnyx.store.write", qos: .utility)

    private static let baseURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Clipnyx", isDirectory: true)
    }()

    private static let v2URL: URL = {
        baseURL.appendingPathComponent("v2", isDirectory: true)
    }()

    private static let indexURL: URL = {
        v2URL.appendingPathComponent("index.json")
    }()

    private static let blobsURL: URL = {
        v2URL.appendingPathComponent("blobs", isDirectory: true)
    }()

    private static let legacyHistoryURL: URL = {
        baseURL.appendingPathComponent("history.json")
    }()

    // MARK: - Index Codable Types

    private struct IndexEntry: Codable {
        let id: UUID
        let timestamp: Date
        let category: ClipboardContentCategory
        let previewText: String
        let hasThumbnail: Bool
        let totalDataSize: Int
        let contentHash: Data
        let representationInfos: [RepInfoEntry]
    }

    private struct RepInfoEntry: Codable {
        let type: String
        let size: Int
    }

    private struct BlobMeta: Codable {
        let types: [String]
        let sizes: [Int]
    }

    // MARK: - Save Index

    func saveIndex(_ items: [ClipboardItem]) {
        let entries = items.map { item in
            IndexEntry(
                id: item.id,
                timestamp: item.timestamp,
                category: item.category,
                previewText: item.previewText,
                hasThumbnail: item.thumbnailData != nil,
                totalDataSize: item.totalDataSize,
                contentHash: item.contentHash,
                representationInfos: item.representationInfos.map { RepInfoEntry(type: $0.type, size: $0.size) }
            )
        }
        writeQueue.async {
            do {
                try FileManager.default.createDirectory(at: Self.v2URL, withIntermediateDirectories: true)
                let data = try JSONEncoder().encode(entries)
                try data.write(to: Self.indexURL, options: .atomic)
            } catch {
                print("Failed to save index: \(error)")
            }
        }
    }

    // MARK: - Save Blobs

    func saveBlobs(for itemID: UUID, representations: [PasteboardRepresentation], thumbnail: Data?) {
        writeQueue.async {
            do {
                let blobDir = Self.blobsURL.appendingPathComponent(itemID.uuidString, isDirectory: true)
                try FileManager.default.createDirectory(at: blobDir, withIntermediateDirectories: true)

                // Write representation data
                for (index, rep) in representations.enumerated() {
                    let repFile = blobDir.appendingPathComponent("rep-\(index).dat")
                    try rep.data.write(to: repFile)
                }

                // Write thumbnail
                if let thumbnail {
                    let thumbFile = blobDir.appendingPathComponent("thumb.dat")
                    try thumbnail.write(to: thumbFile)
                }

                // Write meta.json
                let meta = BlobMeta(
                    types: representations.map(\.typeRawValue),
                    sizes: representations.map(\.data.count)
                )
                let metaData = try JSONEncoder().encode(meta)
                try metaData.write(to: blobDir.appendingPathComponent("meta.json"))
            } catch {
                print("Failed to save blobs for \(itemID): \(error)")
            }
        }
    }

    // MARK: - Load Index

    func loadIndex() -> [ClipboardItem] {
        guard FileManager.default.fileExists(atPath: Self.indexURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: Self.indexURL)
            let entries = try JSONDecoder().decode([IndexEntry].self, from: data)
            return entries.compactMap { entry in
                // Load thumbnail from blob dir
                var thumbnailData: Data?
                if entry.hasThumbnail {
                    let thumbFile = Self.blobsURL
                        .appendingPathComponent(entry.id.uuidString, isDirectory: true)
                        .appendingPathComponent("thumb.dat")
                    thumbnailData = try? Data(contentsOf: thumbFile)
                }

                return ClipboardItem(
                    id: entry.id,
                    timestamp: entry.timestamp,
                    category: entry.category,
                    previewText: entry.previewText,
                    thumbnailData: thumbnailData,
                    totalDataSize: entry.totalDataSize,
                    contentHash: entry.contentHash,
                    representationInfos: entry.representationInfos.map { RepresentationInfo(type: $0.type, size: $0.size) }
                )
            }
        } catch {
            print("Failed to load index: \(error)")
            return []
        }
    }

    // MARK: - Load Representations

    func loadRepresentations(for itemID: UUID) -> [PasteboardRepresentation]? {
        let blobDir = Self.blobsURL.appendingPathComponent(itemID.uuidString, isDirectory: true)
        let metaFile = blobDir.appendingPathComponent("meta.json")

        guard let metaData = try? Data(contentsOf: metaFile),
              let meta = try? JSONDecoder().decode(BlobMeta.self, from: metaData) else { return nil }

        var reps: [PasteboardRepresentation] = []
        for (index, type) in meta.types.enumerated() {
            let repFile = blobDir.appendingPathComponent("rep-\(index).dat")
            guard let data = try? Data(contentsOf: repFile) else { continue }
            reps.append(PasteboardRepresentation(
                type: NSPasteboard.PasteboardType(type),
                data: data
            ))
        }

        return reps.isEmpty ? nil : reps
    }

    // MARK: - Delete

    func deleteBlobs(for itemIDs: [UUID]) {
        writeQueue.async {
            let fm = FileManager.default
            for id in itemIDs {
                let blobDir = Self.blobsURL.appendingPathComponent(id.uuidString, isDirectory: true)
                try? fm.removeItem(at: blobDir)
            }
        }
    }

    func deleteAll() {
        writeQueue.async {
            try? FileManager.default.removeItem(at: Self.v2URL)
        }
    }

    // MARK: - Migration

    func migrateFromLegacyIfNeeded() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: Self.legacyHistoryURL.path) else { return }

        // Don't migrate if v2 index already exists
        guard !fm.fileExists(atPath: Self.indexURL.path) else {
            try? fm.removeItem(at: Self.legacyHistoryURL)
            return
        }

        // Legacy item format (mirrors old ClipboardItem)
        struct LegacyItem: Codable {
            let id: UUID
            let timestamp: Date
            let category: ClipboardContentCategory
            let representations: [PasteboardRepresentation]
            let previewText: String
            let thumbnailData: Data?
        }

        do {
            let data = try Data(contentsOf: Self.legacyHistoryURL)
            let legacyItems = try JSONDecoder().decode([LegacyItem].self, from: data)

            // Create v2 directory structure
            try fm.createDirectory(at: Self.blobsURL, withIntermediateDirectories: true)

            // Convert and write each item
            var indexEntries: [IndexEntry] = []

            for legacyItem in legacyItems {
                let blobDir = Self.blobsURL.appendingPathComponent(legacyItem.id.uuidString, isDirectory: true)
                try fm.createDirectory(at: blobDir, withIntermediateDirectories: true)

                // Write representation data
                for (index, rep) in legacyItem.representations.enumerated() {
                    try rep.data.write(to: blobDir.appendingPathComponent("rep-\(index).dat"))
                }

                // Write thumbnail
                if let thumb = legacyItem.thumbnailData {
                    try thumb.write(to: blobDir.appendingPathComponent("thumb.dat"))
                }

                // Write meta.json
                let meta = BlobMeta(
                    types: legacyItem.representations.map(\.typeRawValue),
                    sizes: legacyItem.representations.map(\.data.count)
                )
                try JSONEncoder().encode(meta).write(to: blobDir.appendingPathComponent("meta.json"))

                // Compute content hash
                var hasher = SHA256()
                for rep in legacyItem.representations {
                    hasher.update(data: rep.data)
                }
                let contentHash = Data(hasher.finalize())

                let entry = IndexEntry(
                    id: legacyItem.id,
                    timestamp: legacyItem.timestamp,
                    category: legacyItem.category,
                    previewText: legacyItem.previewText,
                    hasThumbnail: legacyItem.thumbnailData != nil,
                    totalDataSize: legacyItem.representations.reduce(0) { $0 + $1.data.count },
                    contentHash: contentHash,
                    representationInfos: legacyItem.representations.map {
                        RepInfoEntry(type: $0.typeRawValue, size: $0.data.count)
                    }
                )
                indexEntries.append(entry)
            }

            // Write index.json
            let indexData = try JSONEncoder().encode(indexEntries)
            try indexData.write(to: Self.indexURL, options: .atomic)

            // Remove legacy file
            try fm.removeItem(at: Self.legacyHistoryURL)

            print("Migration complete: \(legacyItems.count) items migrated to v2")
        } catch {
            print("Migration failed: \(error)")
        }
    }

    // MARK: - Cleanup Orphans

    func cleanupOrphans(validIDs: Set<UUID>) {
        writeQueue.async {
            let fm = FileManager.default
            guard let contents = try? fm.contentsOfDirectory(
                at: Self.blobsURL,
                includingPropertiesForKeys: nil
            ) else { return }

            for url in contents {
                guard let uuid = UUID(uuidString: url.lastPathComponent) else {
                    try? fm.removeItem(at: url)
                    continue
                }
                if !validIDs.contains(uuid) {
                    try? fm.removeItem(at: url)
                }
            }
        }
    }
}
