import SwiftUI

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
            NavigationStack {
                ResultEntryView(
                    draft: editingDraft,
                    fixedCourse: meet?.course,
                    defaultCourse: meet?.course ?? store.settings.defaultCourse
                ) { draft in
                    applyResult(draft)
                }
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
                Label(meet.dateRangeLabel, systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Label(meet.course.label, systemImage: "ruler")
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
        return ResultDraft(
            event: result.event,
            seconds: result.seconds,
            note: result.note,
            splits: result.splits,
            relayLeg: result.relayLeg,
            relayLegStroke: result.relayLegStroke,
            relayLegSeconds: result.relayLegSeconds,
            isRelayLeadOff: result.isRelayLeadOff
        )
    }

    private func applyResult(_ draft: ResultDraft) {
        if let editingResultID,
           let existing = results.first(where: { $0.id == editingResultID }) {
            store.updateTime(
                id: editingResultID,
                distance: draft.event.distance,
                stroke: draft.event.stroke,
                course: meet?.course ?? draft.event.course,
                seconds: draft.seconds,
                date: existing.date,
                meetID: meetID,
                isRelay: draft.event.isRelay,
                note: draft.note,
                splits: draft.splits,
                relayLeg: draft.relayLeg,
                relayLegStroke: draft.relayLegStroke,
                relayLegSeconds: draft.relayLegSeconds,
                isRelayLeadOff: draft.isRelayLeadOff
            )
        } else {
            store.addResult(toMeet: meetID, draft: draft)
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
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !result.note.isEmpty {
                    Text(result.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if result.hasSplits {
                    Text(result.splits.count <= 4
                          ? result.splits.map(\.asSwimTime).joined(separator: " · ")
                          : "\(result.splits.count) × 50 splits")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
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
                if let leg = result.relayLegSeconds {
                    Text("Leg \(leg.asSwimTime)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                if let score = store.score(for: result) {
                    ScoreBadge(points: score)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        var parts = [result.event.course.rawValue]
        if result.isRelay {
            parts.append("Relay")
            if let leg = result.relayLeg {
                parts.append("Leg \(leg)")
            }
            if result.event.stroke == .medley, let stroke = result.relayLegStroke {
                parts.append(stroke.rawValue)
            }
            if result.isRelayLeadOff {
                parts.append("Lead-off")
            }
        }
        return parts.joined(separator: " · ")
    }
}
