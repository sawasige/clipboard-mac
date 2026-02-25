import AppKit

struct PasteboardRepresentation: Codable, Equatable, Sendable {
    let typeRawValue: String
    let data: Data

    var pasteboardType: NSPasteboard.PasteboardType {
        NSPasteboard.PasteboardType(typeRawValue)
    }

    init(type: NSPasteboard.PasteboardType, data: Data) {
        self.typeRawValue = type.rawValue
        self.data = data
    }
}
