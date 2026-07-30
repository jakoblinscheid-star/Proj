import SwiftUI

/// Sheet for recording or editing a swim. Optionally pre-filled to a specific event.
struct AddTimeView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Non-nil when editing an existing swim.
    private let editingID: String?

    @State private var course: Course
    @State private var stroke: Stroke
    @State private var distance: Int
    @State private var timeSeconds: Double
    @State private var splitValues: [Double]
    @State private var date = Date()
    @State private var meetID: String? = nil
    @State private var round: MeetRound = .prelims
    @State private var note = ""
    @State private var confirmingDelete = false

    init(presetEvent: SwimEvent? = nil, editing: SwimTime? = nil, defaultCourse: Course = .scy) {
        editingID = editing?.id
        let event = editing?.event ?? presetEvent
        let initialDistance = event?.distance ?? 100
        let initialRelay = event?.isRelay ?? false
        _course = State(initialValue: event?.course ?? defaultCourse)
        _stroke = State(initialValue: event?.stroke ?? .freestyle)
        _distance = State(initialValue: initialDistance)
        _timeSeconds = State(initialValue: editing?.seconds ?? 0)
        let expected = SwimSplits.fiftyCount(distance: initialDistance, isRelay: initialRelay)
        var initialSplits = editing?.splits ?? []
        if expected >= 2 {
            if initialSplits.count < expected {
                initialSplits.append(contentsOf: Array(repeating: 0, count: expected - initialSplits.count))
            } else if initialSplits.count > expected {
                initialSplits = Array(initialSplits.prefix(expected))
            }
        } else {
            initialSplits = []
        }
        _splitValues = State(initialValue: initialSplits)
        _date = State(initialValue: editing?.date ?? Date())
        _meetID = State(initialValue: editing?.meetID)
        _round = State(initialValue: editing?.round ?? .prelims)
        _note = State(initialValue: editing?.note ?? "")
    }

    private var selectedMeetAllowsRound: Bool {
        guard let meetID, let meet = store.meet(id: meetID) else { return false }
        return meet.hasPrelimsFinals
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

    private var previewScore: Int? {
        store.baseSeconds(for: SwimEvent(distance: distance, stroke: stroke, course: course))
            .flatMap { SwimScore.points(seconds: timeSeconds, base: $0) }
    }

    private var canSave: Bool {
        timeSeconds > 0 && availableDistances.contains(distance)
    }

    private var derivesFinalFromSplits: Bool {
        SwimSplits.supportsSplits(distance: distance, isRelay: false)
    }

    var body: some View {
        NavigationStack {
            Form {
                eventSection
                if !derivesFinalFromSplits {
                    timeSection
                }
                SplitEntrySection(
                    distance: distance,
                    unit: course.unit,
                    isRelay: false,
                    splits: $splitValues,
                    onFinalFromSplits: { timeSeconds = $0 }
                )
                detailsSection
                if editingID != nil {
                    Section {
                        Button("Delete Time", role: .destructive) {
                            confirmingDelete = true
                        }
                    }
                }
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
            .alert("Delete this time?", isPresented: $confirmingDelete) {
                Button("Delete", role: .destructive) { deleteEditingTime() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the swim from Times and any linked meet. This can’t be undone.")
            }
            .onChange(of: course) { _, _ in reconcileEventSelection() }
            .onChange(of: stroke) { _, _ in reconcileEventSelection() }
            .onChange(of: meetID) { _, newMeetID in
                if let newMeetID, let meet = store.meet(id: newMeetID) {
                    course = meet.course
                    date = meet.date
                }
            }
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
            .disabled(meetID != nil)

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
            SwimTimePad(seconds: $timeSeconds)
        } header: {
            Text("Time")
        } footer: {
            HStack {
                Text(timeSeconds > 0 ? timeSeconds.asSwimTime : "—")
                    .monospacedDigit()
                Spacer()
                if let previewScore {
                    Text("\(previewScore) World Aquatics pts")
                } else if timeSeconds > 0 {
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

            if selectedMeetAllowsRound {
                Picker("Round", selection: $round) {
                    ForEach(MeetRound.allCases) { meetRound in
                        Text(meetRound.rawValue).tag(meetRound)
                    }
                }
                .pickerStyle(.segmented)
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
        var swimCourse = course
        if let meetID, let meet = store.meet(id: meetID) {
            swimDate = meet.date
            swimCourse = meet.course
        }
        let swimRound: MeetRound? = selectedMeetAllowsRound ? round : nil
        if let editingID {
            store.updateTime(id: editingID,
                             distance: distance,
                             stroke: stroke,
                             course: swimCourse,
                             seconds: timeSeconds,
                             date: swimDate,
                             meetID: meetID,
                             isRelay: false,
                             note: note,
                             splits: splitValues,
                             round: swimRound)
        } else {
            store.addTime(distance: distance,
                          stroke: stroke,
                          course: swimCourse,
                          seconds: timeSeconds,
                          date: swimDate,
                          meetID: meetID,
                          note: note,
                          splits: splitValues,
                          round: swimRound)
        }
        dismiss()
    }

    private func deleteEditingTime() {
        guard let editingID else { return }
        store.deleteTime(id: editingID)
        dismiss()
    }
}
