import SwiftUI

/// Landing tab: stroke radar from overall scores, plus your most recent meets.
struct HomeView: View {
    @Environment(Store.self) private var store
    @State private var showingSettings = false

    private var strokeScores: [StrokeScore] { store.strokeOveralls }
    private var hasStrokeScores: Bool { strokeScores.contains { !$0.isEmpty } }
    private var hasContent: Bool { hasStrokeScores || !store.meets.isEmpty }

    var body: some View {
        NavigationStack {
            Group {
                if hasContent {
                    content
                } else {
                    emptyState
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
            if hasStrokeScores {
                Section {
                    StrokeRadarChart(scores: strokeScores)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                } header: {
                    Text("By stroke")
                } footer: {
                    Text("Overall score for each stroke — same weighted average as Your Score, scoped to that stroke.")
                }
            }

            if !store.meets.isEmpty {
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
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No swims yet", systemImage: "figure.pool.swim")
        } description: {
            Text("Add times or meets and your stroke scores will show up here.")
        }
    }
}

#Preview {
    HomeView()
        .environment(Store())
        .tint(Theme.accent)
}
