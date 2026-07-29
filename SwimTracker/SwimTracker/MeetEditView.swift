import SwiftUI

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
    @State private var endDate: Date
    @State private var course: Course
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
            _endDate = State(initialValue: Date())
            _course = State(initialValue: .scy)
        case .edit(let meet):
            _name = State(initialValue: meet.name)
            _team = State(initialValue: meet.team)
            _location = State(initialValue: meet.location)
            _date = State(initialValue: meet.date)
            _endDate = State(initialValue: meet.endDate)
            _course = State(initialValue: meet.course)
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
                    DatePicker("Start", selection: $date, displayedComponents: .date)
                    DatePicker("End", selection: $endDate, in: date..., displayedComponents: .date)
                    Picker("Pool length", selection: $course) {
                        ForEach(Course.allCases) { course in
                            Text(course.rawValue).tag(course)
                        }
                    }
                    .pickerStyle(.segmented)
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
            .navigationDestination(isPresented: $showingEventEntry) {
                ResultEntryView(
                    draft: editingDraft,
                    fixedCourse: course,
                    defaultCourse: course
                ) { draft in
                    applyDraft(draft)
                }
            }
            .onAppear {
                if case .add = mode {
                    course = store.settings.defaultCourse
                }
            }
            .onChange(of: date) { _, newStart in
                if endDate < newStart { endDate = newStart }
            }
            .onChange(of: course) { _, newCourse in
                for index in drafts.indices {
                    drafts[index].event.course = newCourse
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
            Text("Add the events you swam — individual or relay. Pool length is set on the meet. You can enter times now or leave them blank.")
        }
    }

    private var editingDraft: ResultDraft? {
        guard let editingDraftID else { return nil }
        return drafts.first { $0.id == editingDraftID }
    }

    private func applyDraft(_ draft: ResultDraft) {
        var saved = draft
        saved.event.course = course
        if let editingDraftID, let index = drafts.firstIndex(where: { $0.id == editingDraftID }) {
            drafts[index] = saved
        } else {
            drafts.append(saved)
        }
    }

    private func save() {
        switch mode {
        case .add:
            if let meetID = store.addMeet(
                name: name,
                team: team,
                location: location,
                date: date,
                endDate: endDate,
                course: course
            ) {
                for draft in drafts {
                    store.addResult(toMeet: meetID, draft: draft)
                }
            }
        case .edit(let meet):
            store.updateMeet(
                id: meet.id,
                name: name,
                team: team,
                location: location,
                date: date,
                endDate: endDate,
                course: course
            )
        }
        dismiss()
    }
}

private struct DraftRow: View {
    let draft: ResultDraft

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(draft.event.titleWithCourse)
                    .foregroundStyle(.primary)
                if draft.event.isRelay, let leg = draft.relayLeg {
                    Text(relaySubtitle(leg: leg))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(draft.seconds?.asSwimTime ?? "No time")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func relaySubtitle(leg: Int) -> String {
        var parts = ["Leg \(leg)"]
        if let stroke = draft.relayLegStroke, draft.event.stroke == .medley {
            parts.append(stroke.rawValue)
        }
        if draft.isRelayLeadOff { parts.append("Lead-off") }
        if let legTime = draft.relayLegSeconds {
            parts.append("Leg \(legTime.asSwimTime)")
        }
        return parts.joined(separator: " · ")
    }
}
