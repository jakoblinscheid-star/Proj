import Foundation

/// Shared App Group used by SwimTracker and its Home Screen widgets.
enum AppGroup {
    static let identifier = "group.com.yourname.swimtracker"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static var goalsSnapshotURL: URL? {
        containerURL?.appendingPathComponent("goals-widget.json")
    }
}

/// WidgetKit kind string for the goals widget.
enum GoalsWidgetKind {
    static let id = "SwimTrackerGoalsWidget"
}
