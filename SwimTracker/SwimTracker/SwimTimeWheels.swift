import SwiftUI

/// Three side-by-side wheels for entering a swim time (minutes / seconds / hundredths).
struct SwimTimeWheels: View {
    @Binding var minutes: Int
    @Binding var seconds: Int
    @Binding var hundredths: Int

    var body: some View {
        HStack(spacing: 0) {
            wheel(title: "min", selection: $minutes, range: 0..<60)
            separator(":")
            wheel(title: "sec", selection: $seconds, range: 0..<60, padded: true)
            separator(".")
            wheel(title: "1/100", selection: $hundredths, range: 0..<100, padded: true)
        }
        .frame(height: 130)
    }

    private func wheel(title: String, selection: Binding<Int>, range: Range<Int>, padded: Bool = false) -> some View {
        VStack(spacing: 2) {
            Picker(title, selection: selection) {
                ForEach(range, id: \.self) { value in
                    Text(padded ? String(format: "%02d", value) : "\(value)").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func separator(_ symbol: String) -> some View {
        Text(symbol)
            .font(.title2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.bottom, 16)
    }
}
