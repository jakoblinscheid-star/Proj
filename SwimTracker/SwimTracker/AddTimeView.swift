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
    @State private var minutes = 0
    @State private var seconds = 0
    @State private var hundredths = 0
    @State private var splitValues: [Double]
    @State private var date = Date()
    @State private var meetID: String? = nil
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
        let components = (editing?.seconds ?? 0).swimTimeComponents
        _minutes = State(initialValue: components.minutes)
        _seconds = State(initialValue: components.seconds)
        _hundredths = State(initialValue: components.hundredths)
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
        store.baseSeconds(for: SwimEvent(distance: distance, stroke: stroke, course: course))
            .flatMap { SwimScore.points(seconds: totalSeconds, base: $0) }
    }

    private var canSave: Bool {
        totalSeconds > 0 && availableDistances.contains(distance)
    }

    private var splitsMismatchFinal: Bool {
        let expected = SwimSplits.fiftyCount(distance: distance, isRelay: false)
        let values = Array(splitValues.prefix(expected))
        guard totalSeconds > 0,
              SwimSplits.isComplete(values, distance: distance, isRelay: false) else { return false }
        let total = values.reduce(0, +)
        return abs(total - totalSeconds) >= 0.005
    }

    var body: some View {
        NavigationStack {
            Form {
                eventSection
                timeSection
                SplitEntrySection(
                    distance: distance,
                    unit: course.unit,
                    isRelay: false,
                    splits: $splitValues,
                    finalSeconds: totalSeconds,
                    onUseSplitTotal: applyFinalTime
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
                if splitsMismatchFinal {
                    Text("Splits don’t add up")
                } else if let previewScore {
                    Text("\(previewScore) World Aquatics pts")
                } else if totalSeconds > 0 {
                    Text("No score for this event")
                } else {
                    Text("Enter a time")
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(splitsMismatchFinal ? Theme.danger : (previewScore != nil ? Theme.accent : .secondary))
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

    private func applyFinalTime(_ value: Double) {
        let components = value.swimTimeComponents
        minutes = components.minutes
        seconds = components.seconds
        hundredths = components.hundredths
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
                             note: note,
                             splits: splitValues)
        } else {
            store.addTime(distance: distance,
                          stroke: stroke,
                          course: course,
                          seconds: totalSeconds,
                          date: swimDate,
                          meetID: meetID,
                          note: note,
                          splits: splitValues)
        }
        dismiss()
    }

    private func deleteEditingTime() {
        guard let editingID else { return }
        store.deleteTime(id: editingID)
        dismiss()
    }
}
