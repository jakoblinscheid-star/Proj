import SwiftUI

/// Landing tab: a friendly header plus your most recent meets.
struct HomeView: View {
    @Environment(Store.self) private var store
    @State private var showingSettings = false

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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .navigationDestination(for: Meet.self) { meet in
                MeetDetailView(meetID: meet.id)
            }
        }
    }

    private var content: some View {
        List {
            Section {
                ForEach(store.recentMeets()) { meet in
                    NavigationLink(value: meet) {
                        MeetRowView(meet: meet)
                    }
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
