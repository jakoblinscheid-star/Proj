import SwiftUI

/// Enter interval times for each 50. Tap a row to edit it inline with the shared time pad.
/// Final time is the sum of all 50s once every split is entered.
struct SplitEntrySection: View {
    let distance: Int
    let unit: String
    let isRelay: Bool
    /// Parallel to each 50; `0` means not entered yet.
    @Binding var splits: [Double]
    /// Called with the split total when complete, or `0` while incomplete.
    var onFinalFromSplits: ((Double) -> Void)? = nil

    @State private var editingIndex: Int = 0

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
                Button {
                    editingIndex = index
                } label: {
                    HStack {
                        Text(SwimSplits.rangeLabel(index: index, segmentDistance: 50, unit: unit))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(splits[safe: index].map { $0 > 0 ? $0.asSwimTime : "Add" } ?? "Add")
                            .foregroundStyle(valueColor(for: index))
                            .monospacedDigit()
                    }
                }
                .buttonStyle(.plain)

                if editingIndex == index {
                    SwimTimePad(seconds: binding(for: index))
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
                }
            }

            HStack {
                Text("Final time")
                Spacer()
                Text(splitTotal?.asSwimTime ?? "—")
                    .monospacedDigit()
                    .foregroundStyle(splitTotal != nil ? Theme.accent : .secondary)
            }

            if enteredCount > 0 {
                Button("Clear splits", role: .destructive) {
                    splits = Array(repeating: 0, count: expectedCount)
                }
            }
        } header: {
            Text("Splits (each 50)")
        } footer: {
            Text(footerText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            resizeIfNeeded()
            publishFinalFromSplits()
        }
        .onChange(of: distance) { _, _ in
            resizeIfNeeded()
            publishFinalFromSplits()
        }
        .onChange(of: isRelay) { _, _ in
            resizeIfNeeded()
            publishFinalFromSplits()
        }
        .onChange(of: splits) { _, _ in
            publishFinalFromSplits()
        }
    }

    private func valueColor(for index: Int) -> Color {
        if editingIndex == index { return Theme.accent }
        guard let value = splits[safe: index], value > 0 else { return Theme.accent }
        return .primary
    }

    private func binding(for index: Int) -> Binding<Double> {
        Binding(
            get: { splits[safe: index] ?? 0 },
            set: { newValue in
                guard splits.indices.contains(index) else { return }
                splits[index] = newValue
            }
        )
    }

    private var footerText: String {
        if let splitTotal {
            return "Final time is the sum of your 50s: \(splitTotal.asSwimTime)."
        }
        return "Enter all \(expectedCount) fifties. Final time is their sum; incomplete splits are discarded on save."
    }

    private func publishFinalFromSplits() {
        guard expectedCount >= 2 else { return }
        onFinalFromSplits?(splitTotal ?? 0)
    }

    private func resizeIfNeeded() {
        guard expectedCount >= 2 else {
            if !splits.isEmpty { splits = [] }
            editingIndex = 0
            return
        }
        if splits.count < expectedCount {
            splits.append(contentsOf: Array(repeating: 0, count: expectedCount - splits.count))
        } else if splits.count > expectedCount {
            splits = Array(splits.prefix(expectedCount))
        }
        if editingIndex >= expectedCount {
            editingIndex = max(expectedCount - 1, 0)
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

private extension Array where Element == Double {
    subscript(safe index: Int) -> Double? {
        indices.contains(index) ? self[index] : nil
    }
}
