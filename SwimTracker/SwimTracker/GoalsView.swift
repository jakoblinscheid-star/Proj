import SwiftUI

/// All-time and meet goal times per event. Opened from the Times tab.
struct GoalsView: View {
    @Environment(Store.self) private var store

    @State private var courseFilter: Course? = nil
    @State private var editingEvent: SwimEvent? = nil
    @State private var showingAdd = false
    @State private var pendingEditEvent: SwimEvent? = nil

    var body: some View {
        Group {
            if filteredGoals.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add goal", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editingEvent) { event in
            GoalEditorSheet(event: event)
        }
        .sheet(isPresented: $showingAdd, onDismiss: {
            if let pending = pendingEditEvent {
                editingEvent = pending
                pendingEditEvent = nil
            }
        }) {
            AddGoalEventSheet { event in
                pendingEditEvent = event
            }
        }
    }

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

            List {
                Section {
                    ForEach(filteredGoals) { entry in
                        Button {
                            editingEvent = entry.event
                        } label: {
                            GoalRowView(goals: entry)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                store.clearGoals(for: entry.event)
                            } label: {
                                Label("Clear", systemImage: "trash")
                            }
                        }
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("All-time goals use your overall best. Meet goals use your best in the current season (\(SwimSeason.label()), Aug–Jul).")
                        if !GoalsWidgetStore.isSharedContainerAvailable {
                            Text("Home Screen Goals widget can’t sync: App Group isn’t available. In Xcode, enable the same App Group on SwimTracker and SwimTrackerWidget (see README). Free Personal Teams often can’t use App Groups.")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var filteredGoals: [EventGoals] {
        store.eventsWithGoals.filter { courseFilter == nil || $0.course == courseFilter }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No goals yet", systemImage: "target")
        } description: {
            Text("Set an all-time or meet goal for any event. Meet goals track your best this season (\(SwimSeason.label())).")
        } actions: {
            Button {
                showingAdd = true
            } label: {
                Label("Add a goal", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Row

private struct GoalRowView: View {
    @Environment(Store.self) private var store
    let goals: EventGoals

    var body: some View {
        HStack(spacing: 12) {
            StrokeBadge(stroke: goals.stroke)

            VStack(alignment: .leading, spacing: 6) {
                Text(goals.event.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(goals.course.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let allTime = goals.allTimeSeconds {
                    GoalProgressLine(
                        label: "All-time",
                        goalSeconds: allTime,
                        bestSeconds: store.bestTime(for: goals.event)?.seconds
                    )
                }
                if let meet = goals.meetSeconds {
                    GoalProgressLine(
                        label: "Meet",
                        goalSeconds: meet,
                        bestSeconds: store.bestTimeInCurrentSeason(for: goals.event)?.seconds
                    )
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

/// Passive gap line: Goal · best · Δ (or Hit).
struct GoalProgressLine: View {
    @Environment(Store.self) private var store
    let label: String
    let goalSeconds: Double
    let bestSeconds: Double?

    var body: some View {
        HStack(spacing: 0) {
            Text("\(label) \(goalSeconds.asSwimTime)")
            if let bestSeconds {
                Text(" · \(bestSeconds.asSwimTime)")
                if store.isGoalMet(goalSeconds: goalSeconds, bestSeconds: bestSeconds) {
                    Text(" · Hit")
                        .foregroundStyle(Theme.success)
                } else if let gap = store.goalGap(goalSeconds: goalSeconds, bestSeconds: bestSeconds) {
                    Text(" · +\(gap.asSwimTime)")
                        .foregroundStyle(Theme.danger)
                }
            } else {
                Text(" · —")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .monospacedDigit()
    }
}

// MARK: - Add event picker

private struct AddGoalEventSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    let onSelect: (SwimEvent) -> Void

    @State private var course: Course = .scy
    @State private var didApplyDefault = false

    private var events: [SwimEvent] {
        BaseTimes.events(for: course)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Course", selection: $course) {
                        ForEach(Course.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                Section {
                    ForEach(events) { event in
                        Button {
                            onSelect(event)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                StrokeBadge(stroke: event.stroke)
                                Text(event.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if store.goals(for: event) != nil {
                                    Text("Edit")
                                        .font(.caption)
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                        }
                    }
                } footer: {
                    Text("Choose an event to set all-time and meet goals.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Add Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                guard !didApplyDefault else { return }
                course = store.settings.defaultCourse
                didApplyDefault = true
            }
        }
    }
}

// MARK: - Editor

private struct GoalEditorSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    let event: SwimEvent

    @State private var allTimeSeconds: Double = 0
    @State private var meetSeconds: Double = 0
    @State private var editingField: GoalField = .allTime

    private enum GoalField {
        case allTime, meet
    }

    private var canSave: Bool { allTimeSeconds > 0 || meetSeconds > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Event", value: event.titleWithCourse)
                }

                Section {
                    goalFieldButton(
                        title: "All-time goal",
                        seconds: allTimeSeconds,
                        field: .allTime,
                        detail: allTimeDetail
                    )
                    goalFieldButton(
                        title: "Meet goal",
                        seconds: meetSeconds,
                        field: .meet,
                        detail: meetDetail
                    )
                } footer: {
                    Text("All-time uses your overall best. Meet uses your best in \(SwimSeason.label()) (Aug–Jul). Leave a field at 0:00.00 to clear it.")
                }

                Section {
                    SwimTimePad(seconds: binding(for: editingField))
                } header: {
                    Text(editingField == .allTime ? "All-time goal" : "Meet goal")
                }

                if store.goals(for: event) != nil {
                    Section {
                        Button("Clear goals", role: .destructive) {
                            store.clearGoals(for: event)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Edit Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.setGoals(
                            for: event,
                            allTimeSeconds: allTimeSeconds > 0 ? allTimeSeconds : nil,
                            meetSeconds: meetSeconds > 0 ? meetSeconds : nil
                        )
                        dismiss()
                    }
                    .disabled(!canSave && store.goals(for: event) == nil)
                }
            }
            .onAppear {
                let existing = store.goals(for: event)
                allTimeSeconds = existing?.allTimeSeconds ?? 0
                meetSeconds = existing?.meetSeconds ?? 0
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var allTimeDetail: String {
        progressDetail(
            goal: allTimeSeconds,
            best: store.bestTime(for: event)?.seconds
        )
    }

    private var meetDetail: String {
        progressDetail(
            goal: meetSeconds,
            best: store.bestTimeInCurrentSeason(for: event)?.seconds
        )
    }

    private func progressDetail(goal: Double, best: Double?) -> String {
        guard goal > 0 else { return "Not set" }
        guard let best else { return "No swim yet" }
        if store.isGoalMet(goalSeconds: goal, bestSeconds: best) {
            return "Hit · best \(best.asSwimTime)"
        }
        if let gap = store.goalGap(goalSeconds: goal, bestSeconds: best) {
            return "Best \(best.asSwimTime) · +\(gap.asSwimTime)"
        }
        return "Best \(best.asSwimTime)"
    }

    private func goalFieldButton(title: String, seconds: Double, field: GoalField, detail: String) -> some View {
        Button {
            editingField = field
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer()
                Text(seconds > 0 ? seconds.asSwimTime : "—")
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(editingField == field ? Theme.accent : .primary)
            }
        }
        .buttonStyle(.plain)
    }

    private func binding(for field: GoalField) -> Binding<Double> {
        switch field {
        case .allTime: return $allTimeSeconds
        case .meet: return $meetSeconds
        }
    }
}

#Preview {
    NavigationStack {
        GoalsView()
    }
    .environment(Store())
    .tint(Theme.accent)
}
