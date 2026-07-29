import SwiftUI

/// Landing tab: stroke radar from overall scores, upcoming countdown, plus recent meets.
struct HomeView: View {
    @Environment(Store.self) private var store
    @State private var showingSettings = false

    private var strokeScores: [StrokeScore] { store.strokeOveralls }
    private var hasStrokeScores: Bool { strokeScores.contains { !$0.isEmpty } }
    private var upcomingMeets: [Meet] { store.upcomingMeets() }
    private var recentMeets: [Meet] { store.recentMeets() }
    private var hasContent: Bool { hasStrokeScores || !upcomingMeets.isEmpty || !recentMeets.isEmpty }

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
            if !upcomingMeets.isEmpty {
                Section {
                    ForEach(upcomingMeets) { meet in
                        NavigationLink(value: meet) {
                            UpcomingMeetRow(meet: meet, daysUntil: store.daysUntilMeet(meet))
                        }
                    }
                } header: {
                    Text("Upcoming")
                }
            }

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

            if !recentMeets.isEmpty {
                Section {
                    ForEach(recentMeets) { meet in
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

// MARK: - Upcoming meet row

/// Meet name/details with a days-until countdown on the trailing edge.
struct UpcomingMeetRow: View {
    let meet: Meet
    let daysUntil: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Theme.color(for: meet.name),
                            in: RoundedRectangle(cornerRadius: 4, style: .circular))

            VStack(alignment: .leading, spacing: 2) {
                Text(meet.name)
                    .font(.headline)
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(meet.dateRangeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Group {
                if daysUntil <= 0 {
                    Text("Today")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.accent)
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(daysUntil)")
                            .font(.title2.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.accent)
                        Text(daysUntil == 1 ? "day" : "days")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(countdownAccessibilityLabel)
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        var parts = [meet.team, meet.location].filter { !$0.isEmpty }
        parts.append(meet.course.rawValue)
        return parts.joined(separator: " · ")
    }

    private var countdownAccessibilityLabel: String {
        switch daysUntil {
        case ...0: return "Today"
        case 1: return "1 day"
        default: return "\(daysUntil) days"
        }
    }
}

#Preview {
    HomeView()
        .environment(Store())
        .tint(Theme.accent)
}
