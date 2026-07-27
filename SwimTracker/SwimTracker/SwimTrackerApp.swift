import SwiftUI

@main
struct SwimTrackerApp: App {
    @State private var store = Store()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .tint(Theme.accent)
        }
    }
}
