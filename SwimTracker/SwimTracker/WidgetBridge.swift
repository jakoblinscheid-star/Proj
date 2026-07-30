import Foundation
import WidgetKit

/// Reloads Home Screen widgets after the app updates shared snapshot data.
enum WidgetBridge {
    static func reloadGoals() {
        WidgetCenter.shared.reloadTimelines(ofKind: GoalsWidgetKind.id)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
