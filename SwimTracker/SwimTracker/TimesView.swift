import SwiftUI
import Charts

/// Times tab: your best time in every event you've swum, sortable by swim score
/// or by event. Tap an event to see all of its times and a progression graph.
struct TimesView: View {
    @Environment(Store.self) private var store

    @State private var showingAdd = false
    @State private var courseFilter: Course? = nil
    @State private var sortMode: SortMode = .score

    enum SortMode: String, CaseIterable, Identifiable {
        case score = "Swim score"
        case event = "Event"
        var id: String { rawValue }
        var systemImage: String { self == .score ? "rosette" : "list.number" }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.times.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .navigationTitle("Times")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { genderMenu }
                ToolbarItem(placement: .topBarTrailing) { sortMenu }
                ToolbarItem(placement: .topBarTrailing) { addButton }
            }
            .sheet(isPresented: $showingAdd) {
                AddTimeView()
            }
            .navigationDestination(for: SwimEvent.self) { event in
                EventDetailView(event: event)
            }
        }
    }

    // MARK: Content

    private var content: some View {
        VStack(spacing: 0) {
            Picker("Course", selection: $courseFilter) {
                Text("All").tag(Course?.none)
                ForEach(Course.allCases) { course in
                    Text(course.rawValue).tag(Course?.some(course))
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            eventsList
        }
    }

    private var eventsList: some View {
        List {
            switch sortMode {
            case .score:
                Section {
                    ForEach(eventsSortedByScore) { event in
                        eventLink(event)
                    }
                } footer: {
                    Text("World Aquatics points for \(store.gender.label.lowercased()), best time per event.")
                }
            case .event:
                ForEach(coursesToShow) { course in
                    Section(course.label) {
                        ForEach(events(for: course)) { event in
                            eventLink(event)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func eventLink(_ event: SwimEvent) -> some View {
        NavigationLink(value: event) {
            BestTimeRowView(event: event)
        }
    }

    // MARK: Derived data

    private var filteredEvents: [SwimEvent] {
        store.eventsWithTimes.filter { courseFilter == nil || $0.course == courseFilter }
    }

    private var eventsSortedByScore: [SwimEvent] {
        filteredEvents.sorted { lhs, rhs in
            let l = store.bestScore(for: lhs) ?? -1
            let r = store.bestScore(for: rhs) ?? -1
            if l != r { return l > r }
            return lhs < rhs
        }
    }

    private var coursesToShow: [Course] {
        Course.allCases.filter { course in
            (courseFilter == nil || courseFilter == course) && filteredEvents.contains { $0.course == course }
        }
    }

    private func events(for course: Course) -> [SwimEvent] {
        filteredEvents.filter { $0.course == course }.sorted(by: <)
    }

    // MARK: Toolbar pieces

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

    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: $sortMode) {
                ForEach(SortMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.systemImage).tag(mode)
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
    }

    private var addButton: some View {
        Button {
            showingAdd = true
        } label: {
            Label("Add time", systemImage: "plus")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No times yet", systemImage: "stopwatch.fill")
        } description: {
            Text("Add a swim to start tracking your best times and swim scores.")
        } actions: {
            Button {
                showingAdd = true
            } label: {
                Label("Add your first time", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Best time row

/// One row in the Times list: an event, its best time, and the swim score.
struct BestTimeRowView: View {
    @Environment(Store.self) private var store
    let event: SwimEvent

    private var best: SwimTime? { store.bestTime(for: event) }
    private var count: Int { store.recordedTimes(for: event).count }

    var body: some View {
        HStack(spacing: 12) {
            StrokeBadge(stroke: event.stroke)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.name)
                    .font(.headline)
                Text("\(event.course.rawValue) · \(count) \(count == 1 ? "swim" : "swims")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                if let seconds = best?.seconds {
                    Text(seconds.asSwimTime)
                        .font(.headline)
                        .monospacedDigit()
                }
                if let score = store.bestScore(for: event) {
                    ScoreBadge(points: score)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// A coloured square badge with the stroke's short name.
struct StrokeBadge: View {
    let stroke: Stroke

    var body: some View {
        Text(stroke.rawValue)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .background(Theme.color(for: stroke.fullName),
                        in: RoundedRectangle(cornerRadius: 4, style: .circular))
    }
}

/// A small pill showing World Aquatics points, tinted by performance tier.
struct ScoreBadge: View {
    let points: Int

    private var tint: Color { Theme.scoreColor(points) }

    var body: some View {
        Text("\(points) pts")
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 4, style: .circular))
    }
}

// MARK: - Add time

/// Sheet for recording or editing a swim. Optionally pre-filled to a specific event.
struct AddTimeView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Non-nil when editing an existing swim.
    private let editingID: String?

    @State private var course: Course
    @State private var stroke: Stroke
    @State private var distance: Int
    @State private var minutes = 0
    @State private var seconds = 0
    @State private var hundredths = 0
    @State private var date = Date()
    @State private var meetID: String? = nil
    @State private var note = ""

    init(presetEvent: SwimEvent? = nil, editing: SwimTime? = nil) {
        editingID = editing?.id
        let event = editing?.event ?? presetEvent
        _course = State(initialValue: event?.course ?? .scy)
        _stroke = State(initialValue: event?.stroke ?? .freestyle)
        _distance = State(initialValue: event?.distance ?? 100)
        let components = (editing?.seconds ?? 0).swimTimeComponents
        _minutes = State(initialValue: components.minutes)
        _seconds = State(initialValue: components.seconds)
        _hundredths = State(initialValue: components.hundredths)
        _date = State(initialValue: editing?.date ?? Date())
        _meetID = State(initialValue: editing?.meetID)
        _note = State(initialValue: editing?.note ?? "")
    }

    private var availableStrokes: [Stroke] {
        let set = Set(BaseTimes.events(for: course).map { $0.stroke })
        return Stroke.allCases.filter { set.contains($0) }
    }

    private var availableDistances: [Int] {
        BaseTimes.events(for: course)
            .filter { $0.stroke == stroke }
            .map { $0.distance }
    }

    private var totalSeconds: Double {
        Double(minutes) * 60 + Double(seconds) + Double(hundredths) / 100.0
    }

    private var previewScore: Int? {
        SwimScore.points(seconds: totalSeconds, distance: distance, stroke: stroke, course: course, gender: store.gender)
    }

    private var canSave: Bool {
        totalSeconds > 0 && availableDistances.contains(distance)
    }

    var body: some View {
        NavigationStack {
            Form {
                eventSection
                timeSection
                detailsSection
            }
            .navigationTitle(editingID == nil ? "Add Time" : "Edit Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onChange(of: course) { _, _ in reconcileEventSelection() }
            .onChange(of: stroke) { _, _ in reconcileEventSelection() }
        }
    }

    private var eventSection: some View {
        Section("Event") {
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
        }
    }

    private var timeSection: some View {
        Section {
            SwimTimeWheels(minutes: $minutes, seconds: $seconds, hundredths: $hundredths)
        } header: {
            Text("Time")
        } footer: {
            HStack {
                Text(totalSeconds > 0 ? totalSeconds.asSwimTime : "—")
                    .monospacedDigit()
                Spacer()
                if let previewScore {
                    Text("\(previewScore) World Aquatics pts")
                } else if totalSeconds > 0 {
                    Text("No score for this event")
                } else {
                    Text("Enter a time")
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(previewScore != nil ? Theme.accent : .secondary)
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            DatePicker("Date", selection: $date, displayedComponents: .date)

            Picker("Meet", selection: $meetID) {
                Text("None").tag(String?.none)
                ForEach(store.meetsByDate) { meet in
                    Text(meet.name).tag(String?.some(meet.id))
                }
            }

            TextField("Note (optional)", text: $note)
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

    private func save() {
        guard canSave else { return }
        var swimDate = date
        if let meetID, let meet = store.meet(id: meetID) {
            swimDate = meet.date
        }
        if let editingID {
            store.updateTime(id: editingID,
                             distance: distance,
                             stroke: stroke,
                             course: course,
                             seconds: totalSeconds,
                             date: swimDate,
                             meetID: meetID,
                             isRelay: false,
                             note: note)
        } else {
            store.addTime(distance: distance,
                          stroke: stroke,
                          course: course,
                          seconds: totalSeconds,
                          date: swimDate,
                          meetID: meetID,
                          note: note)
        }
        dismiss()
    }
}

// MARK: - Event detail

/// All recorded times for an event plus a progression graph.
struct EventDetailView: View {
    @Environment(Store.self) private var store
    let event: SwimEvent

    @State private var showingAdd = false
    @State private var editingTime: SwimTime? = nil

    private var recorded: [SwimTime] { store.recordedTimes(for: event) }
    private var best: SwimTime? { store.bestTime(for: event) }

    var body: some View {
        List {
            summarySection
            if recorded.count >= 2 {
                progressionSection
            }
            historySection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(event.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add time", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddTimeView(presetEvent: event)
        }
        .sheet(item: $editingTime) { time in
            AddTimeView(editing: time)
        }
    }

    private var summarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text(event.fullName)
                    .font(.headline)
                Text(event.course.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    statBlock(title: "Best time", value: best?.seconds?.asSwimTime ?? "—")
                    Spacer()
                    if let best, let score = store.score(for: best) {
                        statBlock(title: "Swim score", value: "\(score)", trailing: true)
                    }
                }

                if let drop = improvement {
                    Label("Dropped \(drop.asSwimTime) since your first swim", systemImage: "arrow.down.right")
                        .font(.caption)
                        .foregroundStyle(Theme.success)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func statBlock(title: String, value: String, trailing: Bool = false) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2)
                .tracking(0.5)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .default))
                .monospacedDigit()
                .foregroundStyle(Theme.accent)
        }
    }

    /// Time dropped from the first recorded swim to the best swim (if improved).
    private var improvement: Double? {
        guard let first = recorded.first?.seconds, let best = best?.seconds, first > best else { return nil }
        return first - best
    }

    private var progressionSection: some View {
        Section("Progression") {
            Chart(recorded) { time in
                LineMark(
                    x: .value("Date", time.date),
                    y: .value("Time", time.seconds ?? 0)
                )
                .foregroundStyle(Theme.accent)
                .interpolationMethod(.monotone)

                PointMark(
                    x: .value("Date", time.date),
                    y: .value("Time", time.seconds ?? 0)
                )
                .foregroundStyle(time.id == best?.id ? Theme.success : Theme.accent)
                .symbolSize(time.id == best?.id ? 90 : 50)
            }
            .chartYScale(domain: .automatic(includesZero: false, reversed: true))
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let seconds = value.as(Double.self) {
                            Text(seconds.asSwimTime)
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4))
            }
            .frame(height: 220)
            .padding(.vertical, 8)
        }
    }

    private var historySection: some View {
        Section {
            ForEach(recorded.reversed()) { time in
                Button {
                    editingTime = time
                } label: {
                    TimeRowView(time: time, isBest: time.id == best?.id)
                }
                .buttonStyle(.plain)
            }
            .onDelete(perform: deleteTimes)
        } header: {
            Text("All times")
        } footer: {
            Text("Tap a time to edit it.")
        }
    }

    private func deleteTimes(at offsets: IndexSet) {
        let reversed = Array(recorded.reversed())
        for index in offsets {
            store.deleteTime(id: reversed[index].id)
        }
    }
}

/// One row in an event's history: time, score, date, meet, and a PR flag.
struct TimeRowView: View {
    @Environment(Store.self) private var store
    let time: SwimTime
    let isBest: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if let seconds = time.seconds {
                        Text(seconds.asSwimTime)
                            .font(.headline)
                            .monospacedDigit()
                    } else {
                        Text("No time yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if isBest {
                        Text("PR")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                        .background(Theme.success, in: RoundedRectangle(cornerRadius: 3, style: .circular))
                    }
                }
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !time.note.isEmpty {
                    Text(time.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if let score = store.score(for: time) {
                ScoreBadge(points: score)
            }
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        if let meetName = store.meetName(for: time) {
            return "\(time.date.asShortDate) · \(meetName)"
        }
        return time.date.asShortDate
    }
}

#Preview {
    TimesView()
        .environment(Store())
        .tint(Theme.accent)
}
