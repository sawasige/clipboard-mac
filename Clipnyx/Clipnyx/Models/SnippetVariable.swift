import AppKit
import Foundation

enum SnippetVariable: String, CaseIterable, Sendable {
    case date
    case time
    case datetime
    case year
    case month
    case day
    case timestamp
    case clipboard
    case newline

    var placeholder: String { "{{\(rawValue)}}" }

    var label: String {
        switch self {
        case .date: String(localized: "Date")
        case .time: String(localized: "Time")
        case .datetime: String(localized: "Date & Time")
        case .year: String(localized: "Year")
        case .month: String(localized: "Month")
        case .day: String(localized: "Day")
        case .timestamp: String(localized: "Timestamp")
        case .clipboard: String(localized: "Clipboard")
        case .newline: String(localized: "Newline")
        }
    }

    var example: String {
        let now = Date()
        switch self {
        case .date: return Self.dateFormatter.string(from: now)
        case .time: return Self.timeFormatter.string(from: now)
        case .datetime: return Self.datetimeFormatter.string(from: now)
        case .year: return Self.yearFormatter.string(from: now)
        case .month: return Self.monthFormatter.string(from: now)
        case .day: return Self.dayFormatter.string(from: now)
        case .timestamp: return String(Int(now.timeIntervalSince1970))
        case .clipboard: return String(localized: "(current clipboard)")
        case .newline: return "\\n"
        }
    }

    // MARK: - Expand

    static func expand(_ content: String) -> String {
        let now = Date()
        var result = content

        for variable in Self.allCases {
            guard result.contains(variable.placeholder) else { continue }
            let value: String
            switch variable {
            case .date: value = dateFormatter.string(from: now)
            case .time: value = timeFormatter.string(from: now)
            case .datetime: value = datetimeFormatter.string(from: now)
            case .year: value = yearFormatter.string(from: now)
            case .month: value = monthFormatter.string(from: now)
            case .day: value = dayFormatter.string(from: now)
            case .timestamp: value = String(Int(now.timeIntervalSince1970))
            case .clipboard: value = NSPasteboard.general.string(forType: .string) ?? ""
            case .newline: value = "\n"
            }
            result = result.replacingOccurrences(of: variable.placeholder, with: value)
        }

        return result
    }

    // MARK: - Formatters

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let datetimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    private static let yearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        return f
    }()

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd"
        return f
    }()
}
