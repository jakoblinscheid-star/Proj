import SwiftUI

/// Enter interval times for each 50, plus an editable final. Tap a row to edit
/// inline. When only one value is left blank, it is filled automatically.
struct SplitEntrySection: View {
    let distance: Int
    let unit: String
    let isRelay: Bool
    /// Parallel to each 50; `0` means not entered yet.
    @Binding var splits: [Double]
    @Binding var finalSeconds: Double

    private enum EditingField: Equatable {
        case split(Int)
        case final
    }

    @State private var editingField: EditingField = .split(0)

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

    private var footerIsWarning: Bool {
        if let splitTotal, finalSeconds > 0 {
            return abs(splitTotal - finalSeconds) >= 0.005
        }
        guard finalSeconds > 0,
              SwimSplits.singleMissingField(
                splits: splits,
                finalSeconds: finalSeconds,
                distance: distance,
                isRelay: isRelay
              ) != nil else { return false }
        return SwimSplits.solvedMissingValue(
            splits: splits,
            finalSeconds: finalSeconds,
            distance: distance,
            isRelay: isRelay
        ) == nil
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
                valueRow(
                    title: SwimSplits.rangeLabel(index: index, segmentDistance: 50, unit: unit),
                    seconds: splits[safe: index] ?? 0,
                    field: .split(index)
                )

                if editingField == .split(index) {
                    SwimTimePad(seconds: binding(for: .split(index)))
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
                }
            }

            valueRow(title: "Final time", seconds: finalSeconds, field: .final)

            if editingField == .final {
                SwimTimePad(seconds: binding(for: .final))
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
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
        .onAppear {
            resizeIfNeeded()
            autofillIfNeeded()
        }
        .onChange(of: distance) { _, _ in
            resizeIfNeeded()
            autofillIfNeeded()
        }
        .onChange(of: isRelay) { _, _ in
            resizeIfNeeded()
            autofillIfNeeded()
        }
        .onChange(of: splits) { _, _ in
            autofillIfNeeded()
        }
        .onChange(of: finalSeconds) { _, _ in
            autofillIfNeeded()
        }
    }

    private func valueRow(title: String, seconds: Double, field: EditingField) -> some View {
        Button {
            editingField = field
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Text(seconds > 0 ? seconds.asSwimTime : "Add")
                    .foregroundStyle(valueColor(seconds: seconds, field: field))
                    .monospacedDigit()
            }
        }
        .buttonStyle(.plain)
    }

    private func valueColor(seconds: Double, field: EditingField) -> Color {
        if editingField == field { return Theme.accent }
        return seconds > 0 ? .primary : Theme.accent
    }

    private func binding(for field: EditingField) -> Binding<Double> {
        switch field {
        case .final:
            return $finalSeconds
        case .split(let index):
            return Binding(
                get: { splits[safe: index] ?? 0 },
                set: { newValue in
                    guard splits.indices.contains(index) else { return }
                    splits[index] = newValue
                }
            )
        }
    }

    private var footerText: String {
        if let splitTotal, finalSeconds > 0 {
            if abs(splitTotal - finalSeconds) < 0.005 {
                return "Splits sum to \(splitTotal.asSwimTime), matching the final time."
            }
            return "Splits don’t add up — total \(splitTotal.asSwimTime) vs final \(finalSeconds.asSwimTime)."
        }
        if let missing = SwimSplits.singleMissingField(
            splits: splits,
            finalSeconds: finalSeconds,
            distance: distance,
            isRelay: isRelay
        ) {
            if SwimSplits.solvedMissingValue(
                splits: splits,
                finalSeconds: finalSeconds,
                distance: distance,
                isRelay: isRelay
            ) == nil {
                return "Can’t solve the missing value — check that the final is larger than the other splits."
            }
            switch missing {
            case .final:
                return "Final time will fill in from the splits."
            case .split(let index):
                let label = SwimSplits.rangeLabel(index: index, segmentDistance: 50, unit: unit)
                return "\(label) will fill in from the final and other splits."
            }
        }
        return "Enter the 50s and final. When only one value is left, it’s calculated for you."
    }

    private func autofillIfNeeded() {
        guard expectedCount >= 2 else { return }
        guard let missing = SwimSplits.singleMissingField(
            splits: splits,
            finalSeconds: finalSeconds,
            distance: distance,
            isRelay: isRelay
        ) else { return }
        // Don’t overwrite the field the user is actively editing.
        switch (missing, editingField) {
        case (.final, .final):
            return
        case (.split(let a), .split(let b)) where a == b:
            return
        default:
            break
        }
        guard let value = SwimSplits.solvedMissingValue(
            splits: splits,
            finalSeconds: finalSeconds,
            distance: distance,
            isRelay: isRelay
        ) else { return }

        switch missing {
        case .final:
            finalSeconds = value
        case .split(let index):
            resizeIfNeeded()
            guard splits.indices.contains(index) else { return }
            splits[index] = value
        }
    }

    private func resizeIfNeeded() {
        guard expectedCount >= 2 else {
            if !splits.isEmpty { splits = [] }
            editingField = .split(0)
            return
        }
        if splits.count < expectedCount {
            splits.append(contentsOf: Array(repeating: 0, count: expectedCount - splits.count))
        } else if splits.count > expectedCount {
            splits = Array(splits.prefix(expectedCount))
        }
        if case .split(let index) = editingField, index >= expectedCount {
            editingField = .split(max(expectedCount - 1, 0))
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
