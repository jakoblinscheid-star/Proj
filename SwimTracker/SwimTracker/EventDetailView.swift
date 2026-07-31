import SwiftUI
import Charts

/// Best time (with splits) at the top, then progression, then the rest of the times.
/// Opening splits from longer races appear here as extracted performances.
struct EventDetailView: View {
    @Environment(Store.self) private var store
    let event: SwimEvent

    @State private var showingAdd = false
    @State private var editingTime: SwimTime? = nil
    @State private var expandedTimeID: String? = nil
    @State private var performancePendingDelete: EventPerformance? = nil

    private var performances: [EventPerformance] { store.performances(for: event) }
    private var best: EventPerformance? { store.bestPerformance(for: event) }
    private var otherPerformances: [EventPerformance] {
        guard let bestID = best?.id else { return Array(performances.reversed()) }
        return performances.reversed().filter { $0.id != bestID }
    }

    var body: some View {
        List {
            bestSection
            if performances.count >= 2 {
                progressionSection
            }
            if !otherPerformances.isEmpty {
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
        .alert(deleteAlertTitle, isPresented: Binding(
            get: { performancePendingDelete != nil },
            set: { if !$0 { performancePendingDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let performance = performancePendingDelete {
                    if expandedTimeID == performance.id { expandedTimeID = nil }
                    store.deleteTime(id: performance.source.id)
                }
                performancePendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                performancePendingDelete = nil
            }
        } message: {
            Text(deleteAlertMessage)
        }
    }

    private var deleteAlertTitle: String {
        performancePendingDelete?.isExtracted == true
            ? "Delete parent swim?"
            : "Delete this time?"
    }

    private var deleteAlertMessage: String {
        if let performance = performancePendingDelete, performance.isExtracted {
            return "This opening split comes from \(performance.source.event.name). Deleting removes that swim from Times and any linked meet. This can’t be undone."
        }
        return "This removes the swim from Times and any linked meet. This can’t be undone."
    }

    private var bestSection: some View {
        Section {
            if let best {
                Button {
                    editingTime = best.source
                } label: {
                    bestHeader(best)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        performancePendingDelete = best
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button("Edit") { editingTime = best.source }
                    Button("Delete", role: .destructive) { performancePendingDelete = best }
                }

                if !best.isExtracted, best.source.hasSplits {
                    SplitsBreakdownView(
                        distance: event.distance,
                        unit: event.course.unit,
                        isRelay: event.isRelay,
                        splits: best.source.splits
                    )
                }
            } else {
                Text("No timed swim yet.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Best time")
        } footer: {
            if let best, best.isExtracted {
                Text("Opening split from \(best.source.event.name). Tap to edit the parent swim.")
            } else if best?.source.hasSplits != true, SwimSplits.supportsSplits(distance: event.distance) {
                Text("Tap to edit or add splits. Swipe left to delete.")
            } else {
                Text("Tap to edit. Swipe left to delete.")
            }
        }
    }

    private func bestHeader(_ best: EventPerformance) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(event.fullName)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(event.course.label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline) {
                Text(best.seconds.asSwimTime)
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

            Text(subtitle(for: best))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let drop = improvement {
                Label("Dropped \(drop.asSwimTime) since your first swim", systemImage: "arrow.down.right")
                    .font(.caption)
                    .foregroundStyle(Theme.success)
            }

            if best.isExtracted {
                Text(best.extractedFromLabel ?? "Extracted opening split")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !best.source.hasSplits, SwimSplits.supportsSplits(distance: event.distance) {
                Text("No splits recorded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func subtitle(for performance: EventPerformance) -> String {
        var parts = [performance.date.asShortDate]
        if let meetName = store.meetName(for: performance.source) {
            parts.append(meetName)
        }
        if let round = performance.round {
            parts.append(round.shortLabel)
        }
        return parts.joined(separator: " · ")
    }

    /// Time dropped from the first performance to the best (if improved).
    private var improvement: Double? {
        guard let first = performances.first?.seconds, let best = best?.seconds, first > best else { return nil }
        return first - best
    }

    private var progressionSection: some View {
        Section("Progression") {
            ExpandableChartContainer(title: "\(event.name) progression") {
                progressionChart(orientation: .vertical, height: 220)
            } expanded: { orientation in
                progressionChart(
                    orientation: orientation,
                    height: orientation == .horizontal
                        ? max(320, CGFloat(performances.count) * 44)
                        : 320
                )
            }
        }
    }

    @ViewBuilder
    private func progressionChart(orientation: ChartOrientation, height: CGFloat) -> some View {
        switch orientation {
        case .vertical:
            Chart(performances) { performance in
                LineMark(
                    x: .value("Date", performance.date),
                    y: .value("Time", performance.seconds)
                )
                .foregroundStyle(Theme.accent)
                .interpolationMethod(.monotone)

                PointMark(
                    x: .value("Date", performance.date),
                    y: .value("Time", performance.seconds)
                )
                .foregroundStyle(performance.id == best?.id ? Theme.success : Theme.accent)
                .symbolSize(performance.id == best?.id ? 90 : 50)
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
            .frame(height: height)
            .padding(.vertical, 8)

        case .horizontal:
            Chart(performances) { performance in
                LineMark(
                    x: .value("Time", performance.seconds),
                    y: .value("Date", performance.date)
                )
                .foregroundStyle(Theme.accent)
                .interpolationMethod(.monotone)

                PointMark(
                    x: .value("Time", performance.seconds),
                    y: .value("Date", performance.date)
                )
                .foregroundStyle(performance.id == best?.id ? Theme.success : Theme.accent)
                .symbolSize(performance.id == best?.id ? 90 : 50)
            }
            .chartXScale(domain: .automatic(includesZero: false, reversed: true))
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let seconds = value.as(Double.self) {
                            Text(seconds.asSwimTime)
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, format: .dateTime.month(.abbreviated).day())
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: height)
            .padding(.vertical, 8)
        }
    }

    private var otherTimesSection: some View {
        Section {
            ForEach(otherPerformances) { performance in
                DisclosureGroup(isExpanded: expansionBinding(for: performance.id)) {
                    if performance.isExtracted {
                        Text("Opening split from \(performance.source.event.name). Edit the parent swim to change this time.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if performance.source.hasSplits {
                        SplitsBreakdownView(
                            distance: event.distance,
                            unit: event.course.unit,
                            isRelay: event.isRelay,
                            splits: performance.source.splits
                        )
                    } else {
                        Text(SwimSplits.supportsSplits(distance: event.distance)
                             ? "No splits recorded"
                             : "Splits aren’t available for this distance")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Button(performance.isExtracted ? "Edit parent swim" : "Edit time") {
                        editingTime = performance.source
                    }
                } label: {
                    PerformanceRowView(performance: performance, isBest: false)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        performancePendingDelete = performance
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        } header: {
            Text("Other times")
        } footer: {
            Text("Extracted opening splits are labeled. Edit or swipe to delete the parent swim.")
        }
    }

    private func expansionBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { expandedTimeID == id },
            set: { expandedTimeID = $0 ? id : (expandedTimeID == id ? nil : expandedTimeID) }
        )
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
        var parts = [time.date.asShortDate]
        if let meetName = store.meetName(for: time) {
            parts.append(meetName)
        }
        if let round = time.round {
            parts.append(round.shortLabel)
        }
        return parts.joined(separator: " · ")
    }
}

/// Row for an official or extracted performance in event history.
private struct PerformanceRowView: View {
    @Environment(Store.self) private var store
    let performance: EventPerformance
    let isBest: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(performance.seconds.asSwimTime)
                        .font(.headline)
                        .monospacedDigit()
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
                if let label = performance.extractedFromLabel {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !performance.source.note.isEmpty {
                    Text(performance.source.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if let score = store.score(for: performance) {
                ScoreBadge(points: score)
            }
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        var parts = [performance.date.asShortDate]
        if let meetName = store.meetName(for: performance.source) {
            parts.append(meetName)
        }
        if let round = performance.round {
            parts.append(round.shortLabel)
        }
        return parts.joined(separator: " · ")
    }
}
