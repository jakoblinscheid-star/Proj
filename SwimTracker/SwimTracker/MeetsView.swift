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

            Text(meetDateLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        var parts = [meet.team, meet.location].filter { !$0.isEmpty }
        parts.append(meet.course.rawValue)
        if meet.hasPrelimsFinals {
            parts.append("P/F")
        }
        return parts.joined(separator: " · ")
    }

    private var meetDateLabel: String {
        let calendar = Calendar.current
        if calendar.isDate(meet.date, inSameDayAs: meet.endDate) {
            return meet.date.asRelativeDay
        }
        return meet.dateRangeLabel
    }
}

#Preview {
    MeetsView()
        .environment(Store())
        .tint(Theme.accent)
}
