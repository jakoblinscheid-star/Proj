import SwiftUI

/// Meets tab: the meets you've competed in. Tap a meet to see (and fill in) the
/// events you swam there — individual events and relays, with times.
struct MeetsView: View {
    @Environment(Store.self) private var store
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if store.meets.isEmpty {
                    emptyState
                } else {
                    meetsList
                }
            }
            .navigationTitle("Meets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add meet", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                MeetEditView(mode: .add)
            }
            .navigationDestination(for: Meet.self) { meet in
                MeetDetailView(meetID: meet.id)
            }
        }
    }

    private var meetsList: some View {
        List {
            ForEach(store.meetsByDate) { meet in
                NavigationLink(value: meet) {
                    MeetRowView(meet: meet)
                }
            }
            .onDelete(perform: deleteMeets)
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No meets yet", systemImage: "flag.checkered")
        } description: {
            Text("Add a meet to start tracking the events you swam.")
        } actions: {
            Button {
                showingAdd = true
            } label: {
                Label("Add your first meet", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func deleteMeets(at offsets: IndexSet) {
        let ids = offsets.map { store.meetsByDate[$0].id }
        for id in ids { store.deleteMeet(id: id) }
    }
}

// MARK: - Meet row

/// One row: a coloured badge, the meet name, team/location, event count, and date.
struct MeetRowView: View {
    @Environment(Store.self) private var store
    let meet: Meet

    private var eventCount: Int { store.results(forMeet: meet.id).count }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "flag.checkered")
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
                if eventCount > 0 {
                    Text("\(eventCount) \(eventCount == 1 ? "event" : "events")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            Text(meet.date.asRelativeDay)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        [meet.team, meet.location].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

// MARK: - Add / edit a meet

/// Sheet for creating a meet (with optional events) or editing a meet's details.
struct MeetEditView: View {
    enum Mode {
        case add
        case edit(Meet)

        var title: String {
            switch self {
            case .add: return "New Meet"
            case .edit: return "Edit Meet"
            }
        }
    }

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var name: String
    @State private var team: String
    @State private var location: String
    @State private var date: Date
    @State private var drafts: [ResultDraft] = []
    @State private var showingEventEntry = false
    @State private var editingDraftID: String? = nil

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .add:
            _name = State(initialValue: "")
            _team = State(initialValue: "")
            _location = State(initialValue: "")
            _date = State(initialValue: Date())
        case .edit(let meet):
            _name = State(initialValue: meet.name)
            _team = State(initialValue: meet.team)
            _location = State(initialValue: meet.location)
            _date = State(initialValue: meet.date)
        }
    }

    private var isAdding: Bool {
        if case .add = mode { return true }
        return false
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Meet") {
                    TextField("Name", text: $name)
                    TextField("Team you're swimming for", text: $team)
                    TextField("Location", text: $location)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                if isAdding {
                    eventsSection
                }
            }
            .navigationTitle(mode.title)
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
            .sheet(isPresented: $showingEventEntry) {
                ResultEntryView(draft: editingDraft) { event, seconds, note in
                    applyDraft(event: event, seconds: seconds, note: note)
                }
            }
        }
    }

    private var eventsSection: some View {
        Section {
            ForEach(drafts) { draft in
                Button {
                    editingDraftID = draft.id
                    showingEventEntry = true
                } label: {
                    DraftRow(draft: draft)
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                drafts.remove(atOffsets: offsets)
            }

            Button {
                editingDraftID = nil
                showingEventEntry = true
            } label: {
                Label("Add event", systemImage: "plus")
            }
        } header: {
            Text("Events swam")
        } footer: {
            Text("Add the events you swam — individual or relay. You can enter times now or leave them blank and fill them in later.")
        }
    }

    private var editingDraft: ResultDraft? {
        guard let editingDraftID else { return nil }
        return drafts.first { $0.id == editingDraftID }
    }

    private func applyDraft(event: SwimEvent, seconds: Double?, note: String) {
        if let editingDraftID, let index = drafts.firstIndex(where: { $0.id == editingDraftID }) {
            drafts[index].event = event
            drafts[index].seconds = seconds
            drafts[index].note = note
        } else {
            drafts.append(ResultDraft(event: event, seconds: seconds, note: note))
        }
    }

    private func save() {
        switch mode {
        case .add:
            if let meetID = store.addMeet(name: name, team: team, location: location, date: date) {
                for draft in drafts {
                    store.addResult(toMeet: meetID, event: draft.event, seconds: draft.seconds, note: draft.note)
                }
            }
        case .edit(let meet):
            store.updateMeet(id: meet.id, name: name, team: team, location: location, date: date)
        }
        dismiss()
    }
}

/// A pending event added while creating a meet, before it becomes a stored result.
struct ResultDraft: Identifiable {
    var id: String = UUID().uuidString
    var event: SwimEvent
    var seconds: Double?
    var note: String
}

private struct DraftRow: View {
    let draft: ResultDraft

    var body: some View {
        HStack {
            Text(draft.event.titleWithCourse)
                .foregroundStyle(.primary)
            Spacer()
            Text(draft.seconds?.asSwimTime ?? "No time")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

// MARK: - Meet detail

/// Everything about one meet: its details and the events you swam there.
struct MeetDetailView: View {
    @Environment(Store.self) private var store
    let meetID: String

    @State private var showingEdit = false
    @State private var showingEventEntry = false
    @State private var editingResultID: String? = nil

    private var meet: Meet? { store.meet(id: meetID) }
    private var results: [SwimTime] { store.results(forMeet: meetID) }

    var body: some View {
        List {
            if let meet {
                detailSection(meet)
            }
            eventsSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(meet?.name ?? "Meet")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            if let meet {
                MeetEditView(mode: .edit(meet))
            }
        }
        .sheet(isPresented: $showingEventEntry) {
            ResultEntryView(draft: editingDraft) { event, seconds, note in
                applyResult(event: event, seconds: seconds, note: note)
            }
        }
    }

    private func detailSection(_ meet: Meet) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                if !meet.team.isEmpty {
                    Label(meet.team, systemImage: "person.3.fill")
                        .font(.subheadline.weight(.medium))
                }
                if !meet.location.isEmpty {
                    Label(meet.location, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Label(meet.date.asShortDate, systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var eventsSection: some View {
        Section {
            if results.isEmpty {
                Text("No events yet. Add the events you swam at this meet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(results) { result in
                    Button {
                        editingResultID = result.id
                        showingEventEntry = true
                    } label: {
                        ResultRow(result: result)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteResults)
            }

            Button {
                editingResultID = nil
                showingEventEntry = true
            } label: {
                Label("Add event", systemImage: "plus")
            }
        } header: {
            Text("Events swam")
        }
    }

    private var editingDraft: ResultDraft? {
        guard let editingResultID, let result = results.first(where: { $0.id == editingResultID }) else { return nil }
        return ResultDraft(event: result.event, seconds: result.seconds, note: result.note)
    }

    private func applyResult(event: SwimEvent, seconds: Double?, note: String) {
        if let editingResultID,
           let existing = results.first(where: { $0.id == editingResultID }) {
            store.updateTime(id: editingResultID,
                             distance: event.distance,
                             stroke: event.stroke,
                             course: event.course,
                             seconds: seconds,
                             date: existing.date,
                             meetID: meetID,
                             isRelay: event.isRelay,
                             note: note)
        } else {
            store.addResult(toMeet: meetID, event: event, seconds: seconds, note: note)
        }
    }

    private func deleteResults(at offsets: IndexSet) {
        let ids = offsets.map { results[$0].id }
        for id in ids { store.deleteTime(id: id) }
    }
}

/// One row in a meet's event list: event, time (or a prompt), score, and note.
struct ResultRow: View {
    @Environment(Store.self) private var store
    let result: SwimTime

    var body: some View {
        HStack(spacing: 12) {
            StrokeBadge(stroke: result.stroke)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.event.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(result.event.course.rawValue + (result.isRelay ? " · Relay" : ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !result.note.isEmpty {
                    Text(result.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                if let seconds = result.seconds {
                    Text(seconds.asSwimTime)
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                } else {
                    Text("Add time")
                        .font(.subheadline)
                        .foregroundStyle(Theme.accent)
                }
                if let score = store.score(for: result) {
                    ScoreBadge(points: score)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Result entry editor

/// Sheet for composing one event result: individual or relay, with an optional time.
struct ResultEntryView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Pass an existing draft to edit it; leave nil to add a new one.
    let draft: ResultDraft?
    let onSave: (SwimEvent, Double?, String) -> Void

    @State private var isRelay: Bool
    @State private var course: Course
    @State private var stroke: Stroke
    @State private var distance: Int
    @State private var minutes: Int
    @State private var seconds: Int
    @State private var hundredths: Int
    @State private var note: String

    init(draft: ResultDraft?, onSave: @escaping (SwimEvent, Double?, String) -> Void) {
        self.draft = draft
        self.onSave = onSave
        let event = draft?.event
        _isRelay = State(initialValue: event?.isRelay ?? false)
        _course = State(initialValue: event?.course ?? .scy)
        _stroke = State(initialValue: event?.stroke ?? .freestyle)
        _distance = State(initialValue: event?.distance ?? 100)
        let components = (draft?.seconds ?? 0).swimTimeComponents
        _minutes = State(initialValue: components.minutes)
        _seconds = State(initialValue: components.seconds)
        _hundredths = State(initialValue: components.hundredths)
        _note = State(initialValue: draft?.note ?? "")
    }

    private var catalog: [SwimEvent] {
        isRelay ? BaseTimes.relayEvents(for: course) : BaseTimes.events(for: course)
    }

    private var availableStrokes: [Stroke] {
        let set = Set(catalog.map { $0.stroke })
        return Stroke.allCases.filter { set.contains($0) }
    }

    private var availableDistances: [Int] {
        catalog.filter { $0.stroke == stroke }.map { $0.distance }
    }

    private var totalSeconds: Double {
        Double(minutes) * 60 + Double(seconds) + Double(hundredths) / 100.0
    }

    private var selectedEvent: SwimEvent {
        SwimEvent(distance: distance, stroke: stroke, course: course, isRelay: isRelay)
    }

    private var previewScore: Int? {
        guard !isRelay, totalSeconds > 0 else { return nil }
        return SwimScore.points(seconds: totalSeconds, distance: distance, stroke: stroke, course: course, gender: store.gender)
    }

    private var canSave: Bool {
        availableDistances.contains(distance)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event") {
                    Picker("Type", selection: $isRelay) {
                        Text("Individual").tag(false)
                        Text("Relay").tag(true)
                    }
                    .pickerStyle(.segmented)

                    Picker("Course", selection: $course) {
                        ForEach(Course.allCases) { course in
                            Text(course.rawValue).tag(course)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker(strokePickerTitle, selection: $stroke) {
                        ForEach(availableStrokes) { stroke in
                            Text(strokeLabel(stroke)).tag(stroke)
                        }
                    }

                    Picker("Distance", selection: $distance) {
                        ForEach(availableDistances, id: \.self) { distance in
                            Text(distanceLabel(distance)).tag(distance)
                        }
                    }
                }

                Section {
                    SwimTimeWheels(minutes: $minutes, seconds: $seconds, hundredths: $hundredths)
                } header: {
                    Text("Time (optional)")
                } footer: {
                    HStack {
                        Text(totalSeconds > 0 ? totalSeconds.asSwimTime : "No time yet")
                            .monospacedDigit()
                        Spacer()
                        if let previewScore {
                            Text("\(previewScore) pts")
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(totalSeconds > 0 ? Theme.accent : .secondary)
                }

                Section("Note") {
                    TextField("Note (optional)", text: $note)
                }
            }
            .navigationTitle(navigationTitleText)
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
            .onChange(of: isRelay) { _, _ in reconcile() }
            .onChange(of: course) { _, _ in reconcile() }
            .onChange(of: stroke) { _, _ in reconcile() }
        }
    }

    private var navigationTitleText: String { draft == nil ? "Add Event" : "Edit Event" }

    private var strokePickerTitle: String { isRelay ? "Relay" : "Stroke" }

    private func strokeLabel(_ stroke: Stroke) -> String {
        if isRelay { return stroke == .medley ? "Medley" : "Free" }
        return stroke.fullName
    }

    private func distanceLabel(_ distance: Int) -> String {
        if isRelay {
            if course == .scy { return "\(distance * 4) \(course.unit) (4×\(distance))" }
            return "4×\(distance) \(course.unit)"
        }
        return "\(distance) \(course.unit)"
    }

    private func reconcile() {
        if !availableStrokes.contains(stroke) {
            stroke = availableStrokes.first ?? .freestyle
        }
        if !availableDistances.contains(distance) {
            distance = availableDistances.first ?? distance
        }
    }

    private func save() {
        guard canSave else { return }
        onSave(selectedEvent, totalSeconds > 0 ? totalSeconds : nil, note)
        dismiss()
    }
}

// MARK: - Shared time wheels

/// Three side-by-side wheels for entering a swim time (minutes / seconds / hundredths).
struct SwimTimeWheels: View {
    @Binding var minutes: Int
    @Binding var seconds: Int
    @Binding var hundredths: Int

    var body: some View {
        HStack(spacing: 0) {
            wheel(title: "min", selection: $minutes, range: 0..<60)
            separator(":")
            wheel(title: "sec", selection: $seconds, range: 0..<60, padded: true)
            separator(".")
            wheel(title: "1/100", selection: $hundredths, range: 0..<100, padded: true)
        }
        .frame(height: 130)
    }

    private func wheel(title: String, selection: Binding<Int>, range: Range<Int>, padded: Bool = false) -> some View {
        VStack(spacing: 2) {
            Picker(title, selection: selection) {
                ForEach(range, id: \.self) { value in
                    Text(padded ? String(format: "%02d", value) : "\(value)").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func separator(_ symbol: String) -> some View {
        Text(symbol)
            .font(.title2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.bottom, 16)
    }
}

#Preview {
    MeetsView()
        .environment(Store())
        .tint(Theme.accent)
}
