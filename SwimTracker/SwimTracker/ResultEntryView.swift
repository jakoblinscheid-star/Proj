import SwiftUI

/// Sheet for composing one event result: individual or relay, with an optional time.
struct ResultEntryView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Pass an existing draft to edit it; leave nil to add a new one.
    let draft: ResultDraft?
    /// When set (meet results), course is locked to the meet and cannot be changed.
    let fixedCourse: Course?
    let defaultCourse: Course
    /// When true, show Prelims / Finals picker (meet uses prelims/finals).
    let allowsRoundSelection: Bool
    let onSave: (ResultDraft) -> Void

    @State private var isRelay: Bool
    @State private var course: Course
    @State private var stroke: Stroke
    @State private var distance: Int
    @State private var timeSeconds: Double
    @State private var splitValues: [Double]
    @State private var note: String
    @State private var round: MeetRound
    @State private var relayLeg: Int
    @State private var relayLegStroke: Stroke
    @State private var relayLegSeconds: Double
    @State private var isRelayLeadOff: Bool

    init(
        draft: ResultDraft?,
        fixedCourse: Course? = nil,
        defaultCourse: Course = .scy,
        allowsRoundSelection: Bool = false,
        onSave: @escaping (ResultDraft) -> Void
    ) {
        self.draft = draft
        self.fixedCourse = fixedCourse
        self.defaultCourse = defaultCourse
        self.allowsRoundSelection = allowsRoundSelection
        self.onSave = onSave
        let event = draft?.event
        let initialDistance = event?.distance ?? 100
        let initialRelay = event?.isRelay ?? false
        let initialCourse = fixedCourse ?? event?.course ?? defaultCourse
        _isRelay = State(initialValue: initialRelay)
        _course = State(initialValue: initialCourse)
        _stroke = State(initialValue: event?.stroke ?? .freestyle)
        _distance = State(initialValue: initialDistance)
        _timeSeconds = State(initialValue: draft?.seconds ?? 0)
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
        _round = State(initialValue: draft?.round ?? .prelims)
        let leg = draft?.relayLeg ?? 1
        _relayLeg = State(initialValue: leg)
        let defaultLegStroke = event?.stroke == .medley
            ? RelayLegInfo.defaultMedleyStroke(forLeg: leg)
            : .freestyle
        _relayLegStroke = State(initialValue: draft?.relayLegStroke ?? defaultLegStroke)
        _relayLegSeconds = State(initialValue: draft?.relayLegSeconds ?? 0)
        _isRelayLeadOff = State(initialValue: draft?.isRelayLeadOff ?? (leg == 1))
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

    private var selectedEvent: SwimEvent {
        SwimEvent(distance: distance, stroke: stroke, course: course, isRelay: isRelay)
    }

    private var previewScore: Int? {
        guard !isRelay, timeSeconds > 0 else { return nil }
        return store.baseSeconds(for: SwimEvent(distance: distance, stroke: stroke, course: course))
            .flatMap { SwimScore.points(seconds: timeSeconds, base: $0) }
    }

    private var canSave: Bool {
        availableDistances.contains(distance)
    }

    var body: some View {
        Form {
            Section("Event") {
                Picker("Type", selection: $isRelay) {
                    Text("Individual").tag(false)
                    Text("Relay").tag(true)
                }
                .pickerStyle(.segmented)

                if fixedCourse == nil {
                    Picker("Course", selection: $course) {
                        ForEach(Course.allCases) { course in
                            Text(course.rawValue).tag(course)
                        }
                    }
                    .pickerStyle(.segmented)
                } else {
                    LabeledContent("Course", value: course.rawValue)
                }

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

                if allowsRoundSelection {
                    Picker("Round", selection: $round) {
                        ForEach(MeetRound.allCases) { meetRound in
                            Text(meetRound.rawValue).tag(meetRound)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            if isRelay {
                relaySection
            }

            Section {
                SwimTimePad(seconds: $timeSeconds)
            } header: {
                Text(isRelay ? "Relay time (optional)" : "Time (optional)")
            } footer: {
                HStack {
                    Text(timeSeconds > 0 ? timeSeconds.asSwimTime : "No time yet")
                        .monospacedDigit()
                    Spacer()
                    if let previewScore {
                        Text("\(previewScore) pts")
                    }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(timeSeconds > 0 ? Theme.accent : .secondary)
            }

            if isRelay {
                Section {
                    SwimTimePad(seconds: $relayLegSeconds)
                } header: {
                    Text("Your leg time (optional)")
                } footer: {
                    Text(relayLegSeconds > 0 ? relayLegSeconds.asSwimTime : "No leg time yet")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(relayLegSeconds > 0 ? Theme.accent : .secondary)
                        .monospacedDigit()
                }
            }

            SplitEntrySection(
                distance: distance,
                unit: course.unit,
                isRelay: isRelay,
                splits: $splitValues,
                finalSeconds: timeSeconds,
                onUseSplitTotal: { timeSeconds = $0 }
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
        .onChange(of: stroke) { _, newStroke in
            reconcile()
            if isRelay, newStroke == .medley {
                relayLegStroke = RelayLegInfo.defaultMedleyStroke(forLeg: relayLeg)
            } else if isRelay {
                relayLegStroke = .freestyle
            }
        }
        .onChange(of: relayLeg) { _, newLeg in
            isRelayLeadOff = (newLeg == 1)
            if stroke == .medley {
                relayLegStroke = RelayLegInfo.defaultMedleyStroke(forLeg: newLeg)
            }
        }
        .onAppear {
            if let fixedCourse { course = fixedCourse }
        }
    }

    private var relaySection: some View {
        Section("Your relay leg") {
            Picker("Leg", selection: $relayLeg) {
                ForEach(RelayLegInfo.legs, id: \.self) { leg in
                    Text("Leg \(leg)").tag(leg)
                }
            }
            .pickerStyle(.segmented)

            if stroke == .medley {
                Picker("Stroke", selection: $relayLegStroke) {
                    ForEach(RelayLegInfo.medleyStrokes) { stroke in
                        Text(stroke.fullName).tag(stroke)
                    }
                }
            }

            Toggle("Lead-off", isOn: $isRelayLeadOff)
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
        var saved = draft ?? ResultDraft(event: selectedEvent, seconds: nil, note: "")
        saved.event = selectedEvent
        saved.seconds = timeSeconds > 0 ? timeSeconds : nil
        saved.note = note
        saved.splits = splitValues
        saved.round = allowsRoundSelection ? round : nil
        if isRelay {
            saved.relayLeg = relayLeg
            saved.relayLegStroke = stroke == .medley ? relayLegStroke : .freestyle
            saved.relayLegSeconds = relayLegSeconds > 0 ? relayLegSeconds : nil
            saved.isRelayLeadOff = isRelayLeadOff
        } else {
            saved.relayLeg = nil
            saved.relayLegStroke = nil
            saved.relayLegSeconds = nil
            saved.isRelayLeadOff = false
        }
        onSave(saved)
        dismiss()
    }
}
