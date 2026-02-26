import SwiftUI

enum ClipboardContentCategory: String, Codable, CaseIterable, Sendable {
    case plainText
    case richText
    case html
    case url
    case image
    case pdf
    case fileURL
    case color
    case sourceCode
    case csv
    case other

    var icon: String {
        switch self {
        case .plainText: return "doc.text"
        case .richText: return "doc.richtext"
        case .html: return "chevron.left.forwardslash.chevron.right"
        case .url: return "link"
        case .image: return "photo"
        case .pdf: return "doc.fill"
        case .fileURL: return "folder"
        case .color: return "paintpalette"
        case .sourceCode: return "curlybraces"
        case .csv: return "tablecells"
        case .other: return "doc.questionmark"
        }
    }

    var color: Color {
        switch self {
        case .plainText: return .primary
        case .richText: return .blue
        case .html: return .orange
        case .url: return .cyan
        case .image: return .green
        case .pdf: return .red
        case .fileURL: return .purple
        case .color: return .pink
        case .sourceCode: return .yellow
        case .csv: return .mint
        case .other: return .gray
        }
    }

    var label: String {
        switch self {
        case .plainText: return String(localized: "Plain Text")
        case .richText: return String(localized: "Rich Text")
        case .html: return String(localized: "HTML")
        case .url: return String(localized: "URL")
        case .image: return String(localized: "Image")
        case .pdf: return String(localized: "PDF")
        case .fileURL: return String(localized: "File")
        case .color: return String(localized: "Color")
        case .sourceCode: return String(localized: "Source Code")
        case .csv: return String(localized: "CSV")
        case .other: return String(localized: "Other")
        }
    }
}
