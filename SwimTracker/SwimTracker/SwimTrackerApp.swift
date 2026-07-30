import SwiftUI

@main
struct SwimTrackerApp: App {
    @State private var store = Store()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .tint(Theme.accent)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.publishGoalsWidgetSnapshot()
            }
        }
    }
}
