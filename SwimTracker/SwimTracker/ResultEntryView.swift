import SwiftUI

/// Sheet for composing one event result: individual or relay, with an optional time.
struct ResultEntryView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Pass an existing draft to edit it; leave nil to add a new one.
    let draft: ResultDraft?
    let onSave: (SwimEvent, Double?, String, [Double]) -> Void

    @State private var isRelay: Bool
    @State private var course: Course
    @State private var stroke: Stroke
    @State private var distance: Int
    @State private var minutes: Int
    @State private var seconds: Int
    @State private var hundredths: Int
    @State private var splitValues: [Double]
    @State private var note: String

    init(
        draft: ResultDraft?,
        defaultCourse: Course = .scy,
        onSave: @escaping (SwimEvent, Double?, String, [Double]) -> Void
    ) {
        self.draft = draft
        self.onSave = onSave
        let event = draft?.event
        let initialDistance = event?.distance ?? 100
        let initialRelay = event?.isRelay ?? false
        _isRelay = State(initialValue: initialRelay)
        _course = State(initialValue: event?.course ?? defaultCourse)
        _stroke = State(initialValue: event?.stroke ?? .freestyle)
        _distance = State(initialValue: initialDistance)
        let components = (draft?.seconds ?? 0).swimTimeComponents
        _minutes = State(initialValue: components.minutes)
        _seconds = State(initialValue: components.seconds)
        _hundredths = State(initialValue: components.hundredths)
        let expected = SwimSplits.fiftyCount(distance: initialDistance, isRelay: initialRelay)
        var initialSplits = draft?.splits ?? []
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
        return store.baseSeconds(for: SwimEvent(distance: distance, stroke: stroke, course: course))
            .flatMap { SwimScore.points(seconds: totalSeconds, base: $0) }
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

                SplitEntrySection(
                    distance: distance,
                    unit: course.unit,
                    isRelay: isRelay,
                    splits: $splitValues,
                    finalSeconds: totalSeconds,
                    onUseSplitTotal: applyFinalTime
                )

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

    private func applyFinalTime(_ value: Double) {
        let components = value.swimTimeComponents
        minutes = components.minutes
        seconds = components.seconds
        hundredths = components.hundredths
    }

    private func save() {
        guard canSave else { return }
        onSave(selectedEvent, totalSeconds > 0 ? totalSeconds : nil, note, splitValues)
        dismiss()
    }
}
