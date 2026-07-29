import SwiftUI

/// Digit-push swim time entry (scoreboard style).
/// Each tapped digit shifts existing digits left: 1 → `0:00.01`, then 0 → `0:00.10`, … → `1:02.36`.
struct SwimTimePad: View {
    @Binding var seconds: Double

    @State private var rawDigits: Int = 0

    private static let maxDigits = 6 // up to 99:59.99 as MMSSHH digits

    var body: some View {
        VStack(spacing: 16) {
            Text(displayText)
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(rawDigits > 0 ? Theme.accent : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .accessibilityLabel("Time \(displayText)")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(1...9, id: \.self) { digit in
                    padKey("\(digit)") { push(digit) }
                }
                padKey("C") { clear() }
                    .foregroundStyle(Theme.danger)
                padKey("0") { push(0) }
                padKey("⌫") { backspace() }
            }
        }
        .onAppear { syncDigitsFromSeconds() }
        .onChange(of: seconds) { _, _ in
            let fromDigits = Self.seconds(from: rawDigits)
            if abs(fromDigits - seconds) >= 0.001 {
                syncDigitsFromSeconds()
            }
        }
    }

    private var displayText: String {
        rawDigits > 0 ? Self.seconds(from: rawDigits).asSwimTime : "0:00.00"
    }

    private func push(_ digit: Int) {
        guard digit >= 0, digit <= 9 else { return }
        let next = rawDigits * 10 + digit
        guard String(next).count <= Self.maxDigits else { return }
        rawDigits = next
        seconds = Self.seconds(from: rawDigits)
    }

    private func backspace() {
        rawDigits /= 10
        seconds = Self.seconds(from: rawDigits)
    }

    private func clear() {
        rawDigits = 0
        seconds = 0
    }

    private func syncDigitsFromSeconds() {
        rawDigits = Self.rawDigits(from: max(seconds, 0))
    }

    /// Digits are interpreted as `MMSSHH` from the right (not total hundredths).
    static func seconds(from rawDigits: Int) -> Double {
        guard rawDigits > 0 else { return 0 }
        let hundredths = rawDigits % 100
        let secs = (rawDigits / 100) % 100
        let minutes = rawDigits / 10_000
        return Double(minutes * 60 + secs) + Double(hundredths) / 100.0
    }

    static func rawDigits(from seconds: Double) -> Int {
        guard seconds > 0 else { return 0 }
        let totalHundredths = Int((seconds * 100).rounded())
        let minutes = totalHundredths / 6000
        let secs = (totalHundredths % 6000) / 100
        let hundredths = totalHundredths % 100
        return minutes * 10_000 + secs * 100 + hundredths
    }

    private func padKey(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
