import Foundation

/// Compact payload the app writes for the goals Home Screen widget.
struct GoalsWidgetSnapshot: Codable, Hashable {
    var updatedAt: Date
    var seasonLabel: String
    var entries: [GoalsWidgetEntry]

    static let empty = GoalsWidgetSnapshot(updatedAt: .distantPast, seasonLabel: "", entries: [])
}

struct GoalsWidgetEntry: Codable, Hashable, Identifiable {
    var id: String
    var eventName: String
    var course: String
    var allTimeGoal: Double?
    var allTimeBest: Double?
    var meetGoal: Double?
    var seasonBest: Double?

    var primaryGoal: Double? { allTimeGoal ?? meetGoal }
    var primaryBest: Double? {
        if allTimeGoal != nil { return allTimeBest }
        if meetGoal != nil { return seasonBest }
        return nil
    }

    var primaryLabel: String {
        if allTimeGoal != nil { return "All-time" }
        if meetGoal != nil { return "Meet" }
        return "Goal"
    }

    /// Seconds above goal (positive = still to drop).
    func gap(goal: Double?, best: Double?) -> Double? {
        guard let goal, let best else { return nil }
        return best - goal
    }

    func isMet(goal: Double?, best: Double?) -> Bool {
        guard let goal, let best else { return false }
        return best <= goal
    }
}

enum GoalsWidgetStore {
    private static let defaultsKey = "goalsWidgetSnapshot"

    /// Prefer seconds-since-1970 so app ↔ widget JSON never breaks on ISO-8601
    /// fractional-second mismatches (a common cause of permanently empty widgets).
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()

    /// True when the App Group container is reachable (required for widget data sharing).
    static var isSharedContainerAvailable: Bool {
        AppGroup.containerURL != nil
    }

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.identifier)
    }

    static func load() -> GoalsWidgetSnapshot {
        if let data = sharedDefaults?.data(forKey: defaultsKey),
           let snapshot = decode(data) {
            return snapshot
        }
        guard let url = AppGroup.goalsSnapshotURL,
              let data = try? Data(contentsOf: url),
              let snapshot = decode(data)
        else {
            return .empty
        }
        return snapshot
    }

    @discardableResult
    static func save(_ snapshot: GoalsWidgetSnapshot) -> Bool {
        guard let data = try? encoder.encode(snapshot) else { return false }
        var wrote = false

        if let defaults = sharedDefaults {
            defaults.set(data, forKey: defaultsKey)
            wrote = true
        }

        if let url = AppGroup.goalsSnapshotURL {
            do {
                try data.write(to: url, options: [.atomic])
                wrote = true
            } catch {
                // Fall through; UserDefaults may still have succeeded.
            }
        }

        return wrote
    }

    private static func decode(_ data: Data) -> GoalsWidgetSnapshot? {
        if let snapshot = try? decoder.decode(GoalsWidgetSnapshot.self, from: data) {
            return snapshot
        }
        // Migrate snapshots written with the old ISO-8601 date strategy.
        let legacy = JSONDecoder()
        legacy.dateDecodingStrategy = .iso8601
        return try? legacy.decode(GoalsWidgetSnapshot.self, from: data)
    }
}

extension Double {
    /// Scoreboard-style swim time shared by the app and widget.
    var asWidgetSwimTime: String {
        let hundredths = Int((self * 100).rounded())
        let minutes = hundredths / 6000
        let seconds = (hundredths % 6000) / 100
        let fraction = hundredths % 100
        if minutes > 0 {
            return String(format: "%d:%02d.%02d", minutes, seconds, fraction)
        }
        return String(format: "%d.%02d", seconds, fraction)
    }
}
