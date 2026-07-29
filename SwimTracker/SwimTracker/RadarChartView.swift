import SwiftUI

/// Radar (spider) chart of overall scores for each stroke.
struct StrokeRadarChart: View {
    let scores: [StrokeScore]

    /// Outer ring of the chart. World Aquatics base = 1000; expand if any stroke is higher.
    private var maxValue: Double {
        let peak = scores.map(\.value).max() ?? 0
        let ceiling = max(peak, 1000)
        let step = 200.0
        let rounded = ceil(Double(ceiling) / step) * step
        return min(max(rounded, 200), 2000)
    }

    private var ringCount: Int { 5 }

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                let radius = side * 0.34

                ZStack {
                    grid(center: center, radius: radius)
                    axes(center: center, radius: radius)
                    dataShape(center: center, radius: radius)
                    vertexLabels(center: center, radius: radius)
                }
            }
            .frame(height: 280)
            .padding(.vertical, 4)

            scoreLegend
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: - Drawing

    private func grid(center: CGPoint, radius: CGFloat) -> some View {
        Canvas { context, _ in
            for ring in 1...ringCount {
                var path = Path()
                for i in 0..<scores.count {
                    let point = polarPoint(index: i,
                                           value: maxValue * Double(ring) / Double(ringCount),
                                           center: center,
                                           radius: radius)
                    if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                path.closeSubpath()
                context.stroke(path, with: .color(Color.secondary.opacity(0.35)), lineWidth: 1)
            }
        }
    }

    private func axes(center: CGPoint, radius: CGFloat) -> some View {
        Canvas { context, _ in
            for i in 0..<scores.count {
                var path = Path()
                path.move(to: center)
                path.addLine(to: polarPoint(index: i, value: maxValue, center: center, radius: radius))
                context.stroke(path, with: .color(Color.secondary.opacity(0.35)), lineWidth: 1)
            }
        }
    }

    private func dataShape(center: CGPoint, radius: CGFloat) -> some View {
        let points = scores.indices.map { i in
            polarPoint(index: i, value: Double(scores[i].value), center: center, radius: radius)
        }

        return Canvas { context, _ in
            guard points.count >= 3 else { return }

            var fill = Path()
            fill.move(to: points[0])
            for point in points.dropFirst() { fill.addLine(to: point) }
            fill.closeSubpath()
            context.fill(fill, with: .color(Theme.accent.opacity(0.28)))
            context.stroke(fill, with: .color(Theme.accent), lineWidth: 2.5)
        }
    }

    private func vertexLabels(center: CGPoint, radius: CGFloat) -> some View {
        ZStack {
            ForEach(Array(scores.enumerated()), id: \.element.id) { index, score in
                let tip = polarPoint(index: index, value: maxValue, center: center, radius: radius)
                let outward = labelOffset(index: index, distance: 28)
                Text(score.stroke.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .position(x: tip.x + outward.x, y: tip.y + outward.y)
            }
        }
    }

    private var scoreLegend: some View {
        HStack(spacing: 0) {
            ForEach(scores) { score in
                VStack(spacing: 2) {
                    Text(score.stroke.rawValue)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(score.isEmpty ? "—" : "\(score.value)")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(score.isEmpty ? .secondary : Theme.scoreColor(score.value))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Geometry

    /// Angle for axis `index`, with index 0 straight up (negative Y).
    private func angle(for index: Int) -> Double {
        let count = max(scores.count, 1)
        return (-.pi / 2) + (2 * .pi * Double(index) / Double(count))
    }

    private func polarPoint(index: Int, value: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        let t = max(0, min(value, maxValue)) / maxValue
        let a = angle(for: index)
        return CGPoint(
            x: center.x + CGFloat(cos(a)) * radius * CGFloat(t),
            y: center.y + CGFloat(sin(a)) * radius * CGFloat(t)
        )
    }

    private func labelOffset(index: Int, distance: CGFloat) -> CGPoint {
        let a = angle(for: index)
        return CGPoint(x: CGFloat(cos(a)) * distance, y: CGFloat(sin(a)) * distance)
    }

    private var accessibilitySummary: String {
        let parts = scores.map { score in
            score.isEmpty
                ? "\(score.stroke.fullName): none"
                : "\(score.stroke.fullName): \(score.value)"
        }
        return "Stroke scores. " + parts.joined(separator: ". ")
    }
}

#Preview {
    let sample: [(Stroke, Int)] = [
        (.freestyle, 780), (.backstroke, 640), (.breaststroke, 520),
        (.butterfly, 710), (.medley, 690),
    ]
    let scores = sample.map { stroke, points in
        let event = SwimEvent(distance: 100, stroke: stroke, course: .scy)
        let component = ScoreComponent(event: event, points: points, weight: 1)
        return StrokeScore(stroke: stroke, overall: OverallScore(value: points, components: [component]))
    }
    return List {
        Section {
            StrokeRadarChart(scores: scores)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        } header: {
            Text("By stroke")
        }
    }
    .listStyle(.insetGrouped)
    .tint(Theme.accent)
}
