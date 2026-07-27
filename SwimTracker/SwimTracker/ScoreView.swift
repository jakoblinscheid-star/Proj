import SwiftUI
import Charts

/// Score tab: your overall swim score (a weighted average of your best events),
/// an overall for each team you've competed under, and a year-by-year graph.
struct ScoreView: View {
    @Environment(Store.self) private var store

    /// Progression graph scope: nil = all times, otherwise a specific team.
    @State private var progressionTeam: String? = nil

    var body: some View {
        NavigationStack {
            Group {
                if store.allTimesOverall.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .navigationTitle("Score")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { genderMenu }
            }
            .navigationDestination(for: SwimEvent.self) { event in
                EventDetailView(event: event)
            }
        }
    }

    // MARK: Content

    private var content: some View {
        List {
            overallSection
            progressionSection
            topEventsSection
            teamsSection
        }
        .listStyle(.insetGrouped)
    }

    private var overallSection: some View {
        let overall = store.allTimesOverall
        return Section {
            VStack(spacing: 6) {
                Text("\(overall.value)")
                    .font(.system(size: 60, weight: .bold, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(Theme.scoreColor(overall.value))
                Text("Overall swim score")
                    .font(.headline)
                Text(overallCaption(overall))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    private func overallCaption(_ overall: OverallScore) -> String {
        let count = overall.components.count
        if count >= 4 { return "Weighted average of your four best events" }
        return "Weighted average of your best \(count) event\(count == 1 ? "" : "s")"
    }

    // MARK: Progression

    private var progressionSection: some View {
        let data = store.yearlyOveralls(team: progressionTeam)
        return Section {
            if !teams.isEmpty {
                Picker("Scope", selection: $progressionTeam) {
                    Text("All times").tag(String?.none)
                    ForEach(teams, id: \.self) { team in
                        Text(team).tag(String?.some(team))
                    }
                }
                .pickerStyle(.menu)
            }

            if data.isEmpty {
                Text("No scored swims for this selection yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                progressionChart(data)
            }
        } header: {
            Text("Score by year")
        } footer: {
            Text(progressionFooter)
        }
    }

    private var progressionFooter: String {
        if let team = progressionTeam {
            return "Each point is your overall from swims with \(team) that year."
        }
        return "Each point is your overall from all swims that year."
    }

    private func progressionChart(_ data: [YearlyScore]) -> some View {
        Chart(data) { point in
            LineMark(
                x: .value("Year", point.year),
                y: .value("Score", point.value)
            )
            .foregroundStyle(Theme.accent)
            .interpolationMethod(.monotone)

            PointMark(
                x: .value("Year", point.year),
                y: .value("Score", point.value)
            )
            .foregroundStyle(Theme.accent)
            .annotation(position: .top) {
                Text("\(point.value)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis {
            AxisMarks(values: data.map(\.year)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let year = value.as(Int.self) {
                        Text(String(year))
                    }
                }
            }
        }
        .frame(height: 220)
        .padding(.vertical, 8)
    }

    // MARK: Top events

    private var topEventsSection: some View {
        let overall = store.allTimesOverall
        return Section {
            ForEach(overall.components) { component in
                NavigationLink(value: component.event) {
                    ScoreComponentRow(component: component)
                }
            }
        } header: {
            Text("Top events")
        } footer: {
            Text("Your best four events, weighted 40% / 40% / 15% / 5% (renormalised when you have fewer).")
        }
    }

    // MARK: Teams

    @ViewBuilder
    private var teamsSection: some View {
        let teamOveralls = store.teamOveralls
        if !teamOveralls.isEmpty {
            Section {
                ForEach(teamOveralls) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.team)
                                .font(.headline)
                            Text("\(entry.overall.components.count) event\(entry.overall.components.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        Text("\(entry.overall.value)")
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.scoreColor(entry.overall.value))
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("By team")
            } footer: {
                Text("Overall for each team you've competed under.")
            }
        }
    }

    private var teams: [String] { store.teamOveralls.map(\.team) }

    // MARK: Toolbar & empty state

    private var genderMenu: some View {
        Menu {
            ForEach(Gender.allCases) { gender in
                Button {
                    store.gender = gender
                } label: {
                    if store.gender == gender {
                        Label(gender.label, systemImage: "checkmark")
                    } else {
                        Text(gender.label)
                    }
                }
            }
        } label: {
            Label(store.gender.label, systemImage: "person.fill")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No score yet", systemImage: "chart.bar.fill")
        } description: {
            Text("Add timed swims in the Times or Meets tab to build your overall swim score.")
        }
    }
}

// MARK: - Score component row

/// One row in the Score tab's "Top events": event, its share of the overall, and points.
struct ScoreComponentRow: View {
    let component: ScoreComponent

    private var sharePercent: Int { Int((component.weight * 100).rounded()) }

    var body: some View {
        HStack(spacing: 12) {
            StrokeBadge(stroke: component.event.stroke)

            VStack(alignment: .leading, spacing: 2) {
                Text(component.event.name)
                    .font(.headline)
                Text("\(component.event.course.rawValue) · \(sharePercent)% of overall")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            ScoreBadge(points: component.points)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ScoreView()
        .environment(Store())
        .tint(Theme.accent)
}
