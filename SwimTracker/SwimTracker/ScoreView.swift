import SwiftUI
import Charts

/// Score tab: your overall swim score (a weighted average of your best events),
/// or a calculator that turns an event + time into World Aquatics points.
struct ScoreView: View {
    @Environment(Store.self) private var store

    enum Mode: String, CaseIterable, Identifiable {
        case yourScore = "Your Score"
        case calc = "Calc"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .yourScore
    /// Scope for overall / top events / year chart: nil = all times, otherwise a team.
    @State private var selectedTeam: String? = nil
    @State private var showingBaseTimes = false
    @State private var showingSettings = false

    private var selectedOverall: OverallScore { store.overall(team: selectedTeam) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                switch mode {
                case .yourScore:
                    yourScoreContent
                case .calc:
                    CalcScoreView()
                }
            }
            .navigationTitle("Score")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingBaseTimes = true
                    } label: {
                        Label("Base Times", systemImage: "trophy.fill")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showingBaseTimes) {
                BaseTimesView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .navigationDestination(for: SwimEvent.self) { event in
                EventDetailView(event: event)
            }
            .onChange(of: teams) { _, teams in
                if let selectedTeam, !teams.contains(selectedTeam) {
                    self.selectedTeam = nil
                }
            }
        }
    }

    // MARK: Your Score

    @ViewBuilder
    private var yourScoreContent: some View {
        if store.allTimesOverall.isEmpty {
            emptyState
        } else {
            List {
                overallSection
                progressionSection
                topEventsSection
                teamsSection
            }
            .listStyle(.insetGrouped)
        }
    }

    private var overallSection: some View {
        let overall = selectedOverall
        return Section {
            if !teams.isEmpty {
                Picker("Team", selection: $selectedTeam) {
                    Text("All times").tag(String?.none)
                    ForEach(teams, id: \.self) { team in
                        Text(team).tag(String?.some(team))
                    }
                }
                .pickerStyle(.menu)
            }

            if overall.isEmpty {
                Text("No scored swims for this team yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
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
        } footer: {
            Text(overallFooter)
        }
    }

    private func overallCaption(_ overall: OverallScore) -> String {
        let count = overall.components.count
        if count >= 4 { return "Weighted average of your four best events" }
        return "Weighted average of your best \(count) event\(count == 1 ? "" : "s")"
    }

    private var overallFooter: String {
        let gender = store.settings.gender.rawValue.lowercased()
        if let team = selectedTeam {
            return "Showing overall for \(team), scored as \(gender). Change gender in Settings."
        }
        return "Showing overall across all times, scored as \(gender). Change gender in Settings."
    }

    // MARK: Progression

    private var progressionSection: some View {
        let data = store.yearlyOveralls(team: selectedTeam)
        return Section {
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
        if let team = selectedTeam {
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

    @ViewBuilder
    private var topEventsSection: some View {
        let overall = selectedOverall
        if !overall.isEmpty {
            Section {
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

    // MARK: Empty state

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No score yet", systemImage: "chart.bar.fill")
        } description: {
            Text("Add timed swims in the Times or Meets tab to build your overall swim score.")
        }
    }
}

// MARK: - Calc score

/// Hypothetical World Aquatics points for an event + time (does not save a swim).
struct CalcScoreView: View {
    @Environment(Store.self) private var store

    @State private var gender: Gender = .male
    @State private var course: Course = .scy
    @State private var stroke: Stroke = .freestyle
    @State private var distance: Int = 100
    @State private var minutes = 0
    @State private var seconds = 0
    @State private var hundredths = 0
    @State private var didApplyDefaults = false

    private var availableStrokes: [Stroke] {
        let set = Set(BaseTimes.events(for: course).map(\.stroke))
        return Stroke.allCases.filter { set.contains($0) }
    }

    private var availableDistances: [Int] {
        BaseTimes.events(for: course)
            .filter { $0.stroke == stroke }
            .map(\.distance)
    }

    private var event: SwimEvent {
        SwimEvent(distance: distance, stroke: stroke, course: course)
    }

    private var totalSeconds: Double {
        Double(minutes * 60 + seconds) + Double(hundredths) / 100.0
    }

    private var baseSeconds: Double? {
        store.baseSeconds(for: event, gender: gender)
    }

    private var calculatedPoints: Int? {
        guard totalSeconds > 0, let base = baseSeconds else { return nil }
        return SwimScore.points(seconds: totalSeconds, base: base)
    }

    var body: some View {
        Form {
            Section {
                Picker("Gender", selection: $gender) {
                    ForEach(Gender.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Course", selection: $course) {
                    ForEach(Course.allCases) { course in
                        Text(course.rawValue).tag(course)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Stroke", selection: $stroke) {
                    ForEach(availableStrokes) { stroke in
                        Text(stroke.fullName).tag(stroke)
                    }
                }

                Picker("Distance", selection: $distance) {
                    ForEach(availableDistances, id: \.self) { distance in
                        Text("\(distance) \(course.unit)").tag(distance)
                    }
                }
            } header: {
                Text("Event")
            }

            Section {
                SwimTimeWheels(minutes: $minutes, seconds: $seconds, hundredths: $hundredths)
            } header: {
                Text("Time")
            }

            Section {
                if let points = calculatedPoints {
                    VStack(spacing: 6) {
                        Text("\(points)")
                            .font(.system(size: 60, weight: .bold, design: .default))
                            .monospacedDigit()
                            .foregroundStyle(Theme.scoreColor(points))
                        Text("World Aquatics pts")
                            .font(.headline)
                        Text("\(gender.rawValue) · \(event.name) · \(totalSeconds.asSwimTime)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } else if totalSeconds > 0, baseSeconds == nil {
                    Text("No base time for this event — it can’t be scored.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Pick an event and enter a time.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Score")
            } footer: {
                if let base = baseSeconds {
                    Text("\(gender.rawValue) base time \(base.asSwimTime) = 1000 pts. Formula: 1000 × (base ÷ time)³.")
                } else {
                    Text("Uses \(gender.rawValue.lowercased()) World Aquatics / U.S. Open base times (editable under Base Times).")
                }
            }
        }
        .onChange(of: course) { _, _ in reconcileEventSelection() }
        .onChange(of: stroke) { _, _ in reconcileEventSelection() }
        .onAppear {
            if !didApplyDefaults {
                gender = store.settings.gender
                course = store.settings.defaultCourse
                didApplyDefaults = true
            }
            reconcileEventSelection()
        }
    }

    private func reconcileEventSelection() {
        if !availableStrokes.contains(stroke) {
            stroke = availableStrokes.first ?? .freestyle
        }
        if !availableDistances.contains(distance) {
            distance = availableDistances.first ?? distance
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
