import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var hexValue: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&hexValue)

        let r, g, b, a: Double
        switch hex.count {
        case 6:
            r = Double((hexValue >> 16) & 0xFF) / 255.0
            g = Double((hexValue >> 8) & 0xFF) / 255.0
            b = Double(hexValue & 0xFF) / 255.0
            a = 1.0
        case 8:
            r = Double((hexValue >> 24) & 0xFF) / 255.0
            g = Double((hexValue >> 16) & 0xFF) / 255.0
            b = Double((hexValue >> 8) & 0xFF) / 255.0
            a = Double(hexValue & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0; a = 1.0
        }
        self.init(red: r, green: g, blue: b, opacity: a)
    }
}
