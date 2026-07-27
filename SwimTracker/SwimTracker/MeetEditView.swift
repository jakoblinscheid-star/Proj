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
                ResultEntryView(
                    draft: editingDraft,
                    defaultCourse: store.settings.defaultCourse
                ) { event, seconds, note, splits in
                    applyDraft(event: event, seconds: seconds, note: note, splits: splits)
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

    private func applyDraft(event: SwimEvent, seconds: Double?, note: String, splits: [Double]) {
        if let editingDraftID, let index = drafts.firstIndex(where: { $0.id == editingDraftID }) {
            drafts[index].event = event
            drafts[index].seconds = seconds
            drafts[index].note = note
            drafts[index].splits = splits
        } else {
            drafts.append(ResultDraft(event: event, seconds: seconds, note: note, splits: splits))
        }
    }

    private func save() {
        switch mode {
        case .add:
            if let meetID = store.addMeet(name: name, team: team, location: location, date: date) {
                for draft in drafts {
                    store.addResult(toMeet: meetID, event: draft.event, seconds: draft.seconds, note: draft.note, splits: draft.splits)
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
    var splits: [Double] = []
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
