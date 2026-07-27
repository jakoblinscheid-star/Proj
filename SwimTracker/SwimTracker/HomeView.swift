import SwiftUI

/// Landing tab: a friendly header plus your most recent meets.
struct HomeView: View {
    @Environment(Store.self) private var store

    var body: some View {
        NavigationStack {
            Group {
                if store.meets.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .navigationTitle("SwimTracker")
        }
    }

    private var content: some View {
        List {
            Section {
                ForEach(store.recentMeets()) { meet in
                    MeetRowView(meet: meet)
                }
            } header: {
                Text("Recent meets")
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No meets yet", systemImage: "figure.pool.swim")
        } description: {
            Text("Add a meet in the Meets tab and your most recent ones will show up here.")
        }
    }
}

#Preview {
    HomeView()
        .environment(Store())
        .tint(Theme.accent)
}
