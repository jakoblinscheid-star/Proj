import SwiftUI
import Charts

/// Best time (with splits) at the top, then progression, then the rest of the times.
struct EventDetailView: View {
    @Environment(Store.self) private var store
    let event: SwimEvent

    @State private var showingAdd = false
    @State private var editingTime: SwimTime? = nil
    @State private var expandedTimeID: String? = nil
    @State private var timePendingDelete: SwimTime? = nil

    private var recorded: [SwimTime] { store.recordedTimes(for: event) }
    private var best: SwimTime? { store.bestTime(for: event) }
    private var otherTimes: [SwimTime] {
        guard let bestID = best?.id else { return Array(recorded.reversed()) }
        return recorded.reversed().filter { $0.id != bestID }
    }

    var body: some View {
        List {
            bestSection
            if recorded.count >= 2 {
                progressionSection
            }
            if !otherTimes.isEmpty {
                otherTimesSection
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(event.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add time", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddTimeView(presetEvent: event, defaultCourse: store.settings.defaultCourse)
        }
        .sheet(item: $editingTime) { time in
            AddTimeView(editing: time, defaultCourse: store.settings.defaultCourse)
        }
        .alert("Delete this time?", isPresented: Binding(
            get: { timePendingDelete != nil },
            set: { if !$0 { timePendingDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let id = timePendingDelete?.id {
                    if expandedTimeID == id { expandedTimeID = nil }
                    store.deleteTime(id: id)
                }
                timePendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                timePendingDelete = nil
            }
        } message: {
            Text("This removes the swim from Times and any linked meet. This can’t be undone.")
        }
    }

    private var bestSection: some View {
        Section {
            if let best {
                Button {
                    editingTime = best
                } label: {
                    bestHeader(best)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        timePendingDelete = best
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button("Edit") { editingTime = best }
                    Button("Delete", role: .destructive) { timePendingDelete = best }
                }

                if best.hasSplits {
                    SplitsBreakdownView(
                        distance: event.distance,
                        unit: event.course.unit,
                        isRelay: event.isRelay,
                        splits: best.splits
                    )
                }
            } else {
                Text("No timed swim yet.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Best time")
        } footer: {
            if best?.hasSplits != true, SwimSplits.supportsSplits(distance: event.distance) {
                Text("Tap to edit or add splits. Swipe left to delete.")
            } else {
                Text("Tap to edit. Swipe left to delete.")
            }
        }
    }

    private func bestHeader(_ best: SwimTime) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(event.fullName)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(event.course.label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline) {
                Text(best.seconds?.asSwimTime ?? "—")
                    .font(.system(size: 36, weight: .bold, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
                Spacer()
                if let score = store.score(for: best) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("SWIM SCORE")
                            .font(.caption2)
                            .tracking(0.5)
                            .foregroundStyle(.secondary)
                        Text("\(score)")
                            .font(.title2.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.scoreColor(score))
                    }
                }
            }

            Text(bestSubtitle(best))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let drop = improvement {
                Label("Dropped \(drop.asSwimTime) since your first swim", systemImage: "arrow.down.right")
                    .font(.caption)
                    .foregroundStyle(Theme.success)
            }

            if !best.hasSplits, SwimSplits.supportsSplits(distance: event.distance) {
                Text("No splits recorded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func bestSubtitle(_ best: SwimTime) -> String {
        if let meetName = store.meetName(for: best) {
            return "\(best.date.asShortDate) · \(meetName)"
        }
        return best.date.asShortDate
    }

    /// Time dropped from the first recorded swim to the best swim (if improved).
    private var improvement: Double? {
        guard let first = recorded.first?.seconds, let best = best?.seconds, first > best else { return nil }
        return first - best
    }

    private var progressionSection: some View {
        Section("Progression") {
            Chart(recorded) { time in
                LineMark(
                    x: .value("Date", time.date),
                    y: .value("Time", time.seconds ?? 0)
                )
                .foregroundStyle(Theme.accent)
                .interpolationMethod(.monotone)

                PointMark(
                    x: .value("Date", time.date),
                    y: .value("Time", time.seconds ?? 0)
                )
                .foregroundStyle(time.id == best?.id ? Theme.success : Theme.accent)
                .symbolSize(time.id == best?.id ? 90 : 50)
            }
            .chartYScale(domain: .automatic(includesZero: false, reversed: true))
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let seconds = value.as(Double.self) {
                            Text(seconds.asSwimTime)
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4))
            }
            .frame(height: 220)
            .padding(.vertical, 8)
        }
    }

    private var otherTimesSection: some View {
        Section {
            ForEach(otherTimes) { time in
                DisclosureGroup(isExpanded: expansionBinding(for: time.id)) {
                    if time.hasSplits {
                        SplitsBreakdownView(
                            distance: event.distance,
                            unit: event.course.unit,
                            isRelay: event.isRelay,
                            splits: time.splits
                        )
                    } else {
                        Text(SwimSplits.supportsSplits(distance: event.distance)
                             ? "No splits recorded"
                             : "Splits aren’t available for this distance")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Button("Edit time") {
                        editingTime = time
                    }
                } label: {
                    TimeRowView(time: time, isBest: false, showsSplitPreview: false)
                }
            }
            .onDelete(perform: deleteOtherTimes)
        } header: {
            Text("Other times")
        } footer: {
            Text("Tap a time to show splits. Edit or swipe to delete.")
        }
    }

    private func expansionBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { expandedTimeID == id },
            set: { expandedTimeID = $0 ? id : (expandedTimeID == id ? nil : expandedTimeID) }
        )
    }

    private func deleteOtherTimes(at offsets: IndexSet) {
        for index in offsets {
            let id = otherTimes[index].id
            if expandedTimeID == id { expandedTimeID = nil }
            store.deleteTime(id: id)
        }
    }
}

/// One row in an event's history: time, score, date, meet, and a PR flag.
struct TimeRowView: View {
    @Environment(Store.self) private var store
    let time: SwimTime
    let isBest: Bool
    var showsSplitPreview: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if let seconds = time.seconds {
                        Text(seconds.asSwimTime)
                            .font(.headline)
                            .monospacedDigit()
                    } else {
                        Text("No time yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if isBest {
                        Text("PR")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                        .background(Theme.success, in: RoundedRectangle(cornerRadius: 3, style: .circular))
                    }
                }
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !time.note.isEmpty {
                    Text(time.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if showsSplitPreview, time.hasSplits {
                    Text(time.splits.count <= 4
                          ? time.splits.map(\.asSwimTime).joined(separator: " · ")
                          : "\(time.splits.count) × 50 splits")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            Spacer(minLength: 8)

            if let score = store.score(for: time) {
                ScoreBadge(points: score)
            }
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        if let meetName = store.meetName(for: time) {
            return "\(time.date.asShortDate) · \(meetName)"
        }
        return time.date.asShortDate
    }
}
