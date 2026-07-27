import SwiftUI

@main
struct TabTrackApp: App {
    @State private var store = Store()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .tint(Theme.accent)
        }
    }
}
