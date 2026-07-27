import SwiftUI

/// A coloured square badge with the stroke's short name.
struct StrokeBadge: View {
    let stroke: Stroke

    var body: some View {
        Text(stroke.rawValue)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .background(Theme.color(for: stroke.fullName),
                        in: RoundedRectangle(cornerRadius: 4, style: .circular))
    }
}

/// A small pill showing World Aquatics points, tinted by performance tier.
struct ScoreBadge: View {
    let points: Int

    private var tint: Color { Theme.scoreColor(points) }

    var body: some View {
        Text("\(points) pts")
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 4, style: .circular))
    }
}
