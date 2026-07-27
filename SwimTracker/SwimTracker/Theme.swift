import SwiftUI

/// Colours and small formatting helpers for SwimTracker's aquatic palette.
enum Theme {
    static let accent = Color(red: 0.055, green: 0.647, blue: 0.914)  // #0EA5E9 pool blue
    static let deep = Color(red: 0.043, green: 0.353, blue: 0.541)    // #0B5A8A lane line
    static let success = Color(red: 0.204, green: 0.827, blue: 0.600) // #34d399
    static let danger = Color(red: 0.973, green: 0.443, blue: 0.443)  // #f87171

    /// Stable per-name colour, matching the sibling app's name-hash → hue logic.
    static func color(for name: String) -> Color {
        var hash = 0
        for scalar in name.unicodeScalars {
            hash = Int(scalar.value) &+ ((hash << 5) &- hash)
        }
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.55, brightness: 0.7)
    }

    /// Performance-tier colour for a swim score, shared by the score badge and the
    /// Score tab: purple (elite) → pool blue → green, muted below.
    static func scoreColor(_ points: Int) -> Color {
        switch points {
        case 900...: return .purple
        case 700..<900: return accent
        case 500..<700: return success
        default: return .secondary
        }
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
    /// A swim time formatted the way a scoreboard shows it:
    /// "27.34" under a minute, "1:02.36" for a minute or more.
    var asSwimTime: String {
        let hundredths = Int((self * 100).rounded())
        let minutes = hundredths / 6000
        let seconds = (hundredths % 6000) / 100
        let fraction = hundredths % 100
        if minutes > 0 {
            return String(format: "%d:%02d.%02d", minutes, seconds, fraction)
        }
        return String(format: "%d.%02d", seconds, fraction)
    }

    /// Split into (minutes, seconds, hundredths) for the wheel time editors.
    var swimTimeComponents: (minutes: Int, seconds: Int, hundredths: Int) {
        let total = Int((self * 100).rounded())
        return (total / 6000, (total % 6000) / 100, total % 100)
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

    /// Relative day description, e.g. "Today", "Yesterday", or a short date.
    var asRelativeDay: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) { return "Today" }
        if calendar.isDateInYesterday(self) { return "Yesterday" }
        if calendar.isDateInTomorrow(self) { return "Tomorrow" }
        return asShortDate
    }
}
