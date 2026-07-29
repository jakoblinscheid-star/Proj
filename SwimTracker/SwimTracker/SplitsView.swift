import SwiftUI

/// Enter interval times for each 50. Tap a row to edit it with the shared time pad.
struct SplitEntrySection: View {
    let distance: Int
    let unit: String
    let isRelay: Bool
    /// Parallel to each 50; `0` means not entered yet.
    @Binding var splits: [Double]
    /// Optional final time used to compare against the split total.
    var finalSeconds: Double = 0
    var onUseSplitTotal: ((Double) -> Void)? = nil

    private var expectedCount: Int {
        SwimSplits.fiftyCount(distance: distance, isRelay: isRelay)
    }

    private var enteredCount: Int {
        splits.prefix(expectedCount).filter { $0 > 0 }.count
    }

    private var completeSplits: [Double]? {
        let values = Array(splits.prefix(expectedCount))
        guard SwimSplits.isComplete(values, distance: distance, isRelay: isRelay) else { return nil }
        return values
    }

    private var splitTotal: Double? {
        completeSplits?.reduce(0, +)
    }

    @ViewBuilder
    var body: some View {
        if expectedCount >= 2 {
            entrySection
            if let completeSplits {
                SplitsDisplaySection(
                    distance: distance,
                    unit: unit,
                    isRelay: isRelay,
                    splits: completeSplits
                )
            }
        }
    }

    private var entrySection: some View {
        Section {
            ForEach(0..<expectedCount, id: \.self) { index in
                NavigationLink {
                    SplitEditorView(
                        title: SwimSplits.rangeLabel(index: index, segmentDistance: 50, unit: unit),
                        seconds: splits[safe: index] ?? 0
                    ) { value in
                        resizeIfNeeded()
                        if splits.indices.contains(index) {
                            splits[index] = value
                        }
                    }
                } label: {
                    HStack {
                        Text(SwimSplits.rangeLabel(index: index, segmentDistance: 50, unit: unit))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(splits[safe: index].map { $0 > 0 ? $0.asSwimTime : "Add" } ?? "Add")
                            .foregroundStyle(splits[safe: index].map { $0 > 0 ? Color.primary : Theme.accent } ?? Theme.accent)
                            .monospacedDigit()
                    }
                }
            }

            if let splitTotal {
                HStack {
                    Text("Split total")
                    Spacer()
                    Text(splitTotal.asSwimTime)
                        .monospacedDigit()
                        .foregroundStyle(footerIsWarning ? Theme.danger : .primary)
                }

                Button("Set final time from splits") {
                    onUseSplitTotal?(splitTotal)
                }
            }

            if enteredCount > 0 {
                Button("Clear splits", role: .destructive) {
                    splits = Array(repeating: 0, count: expectedCount)
                }
            }
        } header: {
            Text("Splits (each 50)")
        } footer: {
            Label(footerText, systemImage: footerIsWarning ? "exclamationmark.triangle.fill" : "info.circle")
                .font(.footnote)
                .foregroundStyle(footerIsWarning ? Theme.danger : .secondary)
                .symbolRenderingMode(.hierarchical)
        }
        .onAppear { resizeIfNeeded() }
        .onChange(of: distance) { _, _ in resizeIfNeeded() }
        .onChange(of: isRelay) { _, _ in resizeIfNeeded() }
    }

    private var footerIsWarning: Bool {
        guard let splitTotal, finalSeconds > 0 else { return false }
        return abs(splitTotal - finalSeconds) >= 0.005
    }

    private var footerText: String {
        if let splitTotal {
            if finalSeconds > 0 {
                if abs(splitTotal - finalSeconds) < 0.005 {
                    return "Splits sum to \(splitTotal.asSwimTime), matching the final time."
                }
                return "Splits don’t add up — total \(splitTotal.asSwimTime) vs final \(finalSeconds.asSwimTime)."
            }
            return "Splits sum to \(splitTotal.asSwimTime). Save them, or set the final time from the total."
        }
        return "Enter all \(expectedCount) fifties to save splits. Incomplete splits are discarded on save."
    }

    private func resizeIfNeeded() {
        guard expectedCount >= 2 else {
            if !splits.isEmpty { splits = [] }
            return
        }
        if splits.count < expectedCount {
            splits.append(contentsOf: Array(repeating: 0, count: expectedCount - splits.count))
        } else if splits.count > expectedCount {
            splits = Array(splits.prefix(expectedCount))
        }
    }
}

/// Read-only split list with a segmented control for 50 / 100 / … aggregation.
struct SplitsDisplaySection: View {
    let distance: Int
    let unit: String
    let isRelay: Bool
    let splits: [Double]
    var header: String? = "Split breakdown"

    var body: some View {
        if SwimSplits.isComplete(splits, distance: distance, isRelay: isRelay) {
            Section {
                SplitsBreakdownView(distance: distance, unit: unit, isRelay: isRelay, splits: splits)
            } header: {
                if let header {
                    Text(header)
                }
            }
        }
    }
}

/// Segmented 50 / 100 / … breakdown for embedding in a parent section.
struct SplitsBreakdownView: View {
    let distance: Int
    let unit: String
    let isRelay: Bool
    let splits: [Double]

    @State private var segmentDistance: Int = 50

    private var modes: [Int] {
        SwimSplits.displayModes(distance: distance, isRelay: isRelay)
    }

    private var aggregated: [Double] {
        SwimSplits.aggregate(splits, segmentDistance: segmentDistance) ?? splits
    }

    var body: some View {
        if SwimSplits.isComplete(splits, distance: distance, isRelay: isRelay), !modes.isEmpty {
            Group {
                if modes.count > 1 {
                    Picker("Split by", selection: $segmentDistance) {
                        ForEach(modes, id: \.self) { mode in
                            Text(SwimSplits.modeLabel(mode)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                ForEach(Array(aggregated.enumerated()), id: \.offset) { index, value in
                    HStack {
                        Text(SwimSplits.rangeLabel(index: index, segmentDistance: segmentDistance, unit: unit))
                        Spacer()
                        Text(value.asSwimTime)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear { reconcileMode() }
            .onChange(of: distance) { _, _ in reconcileMode() }
        }
    }

    private func reconcileMode() {
        if !modes.contains(segmentDistance) {
            segmentDistance = modes.first ?? 50
        }
    }
}

/// Pushed editor for one 50-split (keeps parent sheets open — no nested sheet).
struct SplitEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let onSave: (Double) -> Void

    @State private var timeSeconds: Double

    init(title: String, seconds initial: Double, onSave: @escaping (Double) -> Void) {
        self.title = title
        self.onSave = onSave
        _timeSeconds = State(initialValue: max(initial, 0))
    }

    var body: some View {
        Form {
            Section {
                SwimTimePad(seconds: $timeSeconds)
            } footer: {
                Text(timeSeconds > 0 ? timeSeconds.asSwimTime : "Enter a split")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(timeSeconds > 0 ? Theme.accent : .secondary)
                    .monospacedDigit()
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(timeSeconds)
                    dismiss()
                }
                .disabled(timeSeconds <= 0)
            }
        }
    }
}

private extension Array where Element == Double {
    subscript(safe index: Int) -> Double? {
        indices.contains(index) ? self[index] : nil
    }
}
