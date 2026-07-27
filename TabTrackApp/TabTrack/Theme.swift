import SwiftUI

/// Colours and small formatting helpers, ported from the original web app's palette.
enum Theme {
    static let accent = Color(red: 0.169, green: 0.498, blue: 1.0)   // #2b7fff
    static let success = Color(red: 0.204, green: 0.827, blue: 0.600) // #34d399
    static let danger = Color(red: 0.973, green: 0.443, blue: 0.443)  // #f87171

    /// Stable per-name avatar colour, matching the web app's name-hash → hue logic.
    static func avatarColor(for name: String) -> Color {
        var hash = 0
        for scalar in name.unicodeScalars {
            hash = Int(scalar.value) &+ ((hash << 5) &- hash)
        }
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.55, brightness: 0.7)
    }

    /// Up-to-two-letter initials for an avatar bubble.
    static func initials(for name: String) -> String {
        let parts = name.split(whereSeparator: { $0.isWhitespace })
        guard let first = parts.first else { return "?" }
        if parts.count == 1 {
            return String(first.prefix(2)).uppercased()
        }
        let last = parts[parts.count - 1]
        return "\(first.prefix(1))\(last.prefix(1))".uppercased()
    }
}

extension Double {
    /// Localised currency string (USD), matching the web app's `Intl.NumberFormat`.
    var asCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: self)) ?? "$0.00"
    }
}

extension Date {
    /// Short medium-style date, e.g. "Jul 27, 2026".
    var asShortDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
}
