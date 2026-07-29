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

    enum ProgressionRange: String, CaseIterable, Identifiable {
        case year = "Year"
        case season = "Season"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .yourScore
    /// Scope for overall / top events / progression chart: nil = all times, otherwise a team.
    @State private var selectedTeam: String? = nil
    @State private var progressionRange: ProgressionRange = .year
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

    private var progressionData: [ProgressionScore] {
        switch progressionRange {
        case .year:
            return store.yearlyOveralls(team: selectedTeam)
        case .season:
            return store.seasonMonthlyOveralls(team: selectedTeam)
        }
    }

    private var progressionSection: some View {
        let data = progressionData
        return Section {
            Picker("Range", selection: $progressionRange) {
                ForEach(ProgressionRange.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)

            if data.isEmpty {
                Text("No scored swims for this selection yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                progressionChart(data)
            }
        } header: {
            Text(progressionRange == .year ? "Score by year" : "Score by season")
        } footer: {
            Text(progressionFooter)
        }
    }

    private var progressionFooter: String {
        let teamScope: String = {
            if let team = selectedTeam { return " with \(team)" }
            return ""
        }()
        switch progressionRange {
        case .year:
            return "Each point is your overall from swims\(teamScope) that calendar year only — later improvements don’t change prior years."
        case .season:
            return "Each point is your season-to-date overall from swims\(teamScope) since August. The chart resets to 0 each August."
        }
    }

    private func progressionChart(_ data: [ProgressionScore]) -> some View {
        Chart(data) { point in
            LineMark(
                x: .value("Period", point.periodStart),
                y: .value("Score", point.value)
            )
            .foregroundStyle(Theme.accent)
            .interpolationMethod(.monotone)

            PointMark(
                x: .value("Period", point.periodStart),
                y: .value("Score", point.value)
            )
            .foregroundStyle(Theme.accent)
            .annotation(position: .top) {
                // Skip labels on long season charts when the value didn’t change,
                // but always show August resets (0) and year points.
                if shouldAnnotate(point, in: data) {
                    Text("\(point.value)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartYScale(domain: seasonYDomain(for: data))
        .chartXAxis {
            AxisMarks(values: axisValues(for: data)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self),
                       let point = data.first(where: { $0.periodStart == date }) {
                        Text(point.label)
                            .font(.caption2)
                    }
                }
            }
        }
        .frame(height: 220)
        .padding(.vertical, 8)
    }

    /// Season charts pin 0 so August resets are visible; year charts leave room above the data.
    private func seasonYDomain(for data: [ProgressionScore]) -> ClosedRange<Int> {
        let peak = data.map(\.value).max() ?? 0
        if progressionRange == .season {
            return 0...max(peak, 1)
        }
        let floor = data.map(\.value).min() ?? 0
        let pad = max(1, (peak - floor) / 8)
        return max(0, floor - pad)...(peak + pad)
    }

    private func axisValues(for data: [ProgressionScore]) -> [Date] {
        guard progressionRange == .season, data.count > 8 else {
            return data.map(\.periodStart)
        }
        // Label August (season start) and every third month so the axis stays readable.
        return data.enumerated().compactMap { index, point in
            let month = Calendar.current.component(.month, from: point.periodStart)
            if month == 8 || index == data.count - 1 || index % 3 == 0 {
                return point.periodStart
            }
            return nil
        }
    }

    private func shouldAnnotate(_ point: ProgressionScore, in data: [ProgressionScore]) -> Bool {
        if progressionRange == .year { return true }
        if point.value == 0 {
            let month = Calendar.current.component(.month, from: point.periodStart)
            return month == 8
        }
        guard let index = data.firstIndex(where: { $0.periodStart == point.periodStart }) else {
            return true
        }
        if index == 0 { return true }
        return data[index - 1].value != point.value
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
                Text("Your best four events, weighted 40% / 40% / 15% / 5% (renormalised when you have fewer). Opening splits from longer races count toward shorter events.")
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

/// Hypothetical World Aquatics conversion: time → points or points → approximate time.
struct CalcScoreView: View {
    @Environment(Store.self) private var store

    enum Direction: String, CaseIterable, Identifiable {
        case timeToScore = "Time → Score"
        case scoreToTime = "Score → Time"
        var id: String { rawValue }
    }

    @State private var direction: Direction = .timeToScore
    @State private var gender: Gender = .male
    @State private var course: Course = .scy
    @State private var stroke: Stroke = .freestyle
    @State private var distance: Int = 100
    @State private var timeSeconds = 0.0
    @State private var scoreInput = ""
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

    private var totalSeconds: Double { timeSeconds }

    private var parsedScore: Int? {
        let trimmed = scoreInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Int(trimmed), value > 0 else { return nil }
        return value
    }

    private var baseSeconds: Double? {
        store.baseSeconds(for: event, gender: gender)
    }

    private var calculatedPoints: Int? {
        guard totalSeconds > 0, let base = baseSeconds else { return nil }
        return SwimScore.points(seconds: totalSeconds, base: base)
    }

    private var calculatedSeconds: Double? {
        guard let points = parsedScore, let base = baseSeconds else { return nil }
        return SwimScore.seconds(points: points, base: base)
    }

    var body: some View {
        Form {
            Section {
                Picker("Direction", selection: $direction) {
                    ForEach(Direction.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)

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

            switch direction {
            case .timeToScore:
                timeToScoreSections
            case .scoreToTime:
                scoreToTimeSections
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

    @ViewBuilder
    private var timeToScoreSections: some View {
        Section {
            SwimTimePad(seconds: $timeSeconds)
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
            formulaFooter
        }
    }

    @ViewBuilder
    private var scoreToTimeSections: some View {
        Section {
            TextField("e.g. 505", text: $scoreInput)
                .keyboardType(.numberPad)
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .padding(.vertical, 4)
        } header: {
            Text("Score")
        }

        Section {
            if let seconds = calculatedSeconds, let points = parsedScore {
                VStack(spacing: 6) {
                    Text(seconds.asSwimTime)
                        .font(.system(size: 60, weight: .bold, design: .default))
                        .monospacedDigit()
                        .foregroundStyle(Theme.accent)
                    Text("Approximate time")
                        .font(.headline)
                    Text("\(gender.rawValue) · \(event.name) · \(points) pts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else if parsedScore != nil, baseSeconds == nil {
                Text("No base time for this event — it can’t be converted.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Pick an event and enter a score.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Time")
        } footer: {
            formulaFooter
        }
    }

    private var formulaFooter: Text {
        if let base = baseSeconds {
            Text("\(gender.rawValue) base time \(base.asSwimTime) = 1000 pts. Formula: 1000 × (base ÷ time)³.")
        } else {
            Text("Uses \(gender.rawValue.lowercased()) World Aquatics / U.S. Open base times (editable under Base Times).")
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
