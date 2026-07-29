import WidgetKit
import SwiftUI

struct GoalsTimelineEntry: TimelineEntry {
    let date: Date
    let snapshot: GoalsWidgetSnapshot
}

struct GoalsProvider: TimelineProvider {
    func placeholder(in context: Context) -> GoalsTimelineEntry {
        GoalsTimelineEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (GoalsTimelineEntry) -> Void) {
        let snapshot = context.isPreview && GoalsWidgetStore.load().entries.isEmpty
            ? GoalsWidgetSnapshot.placeholder
            : GoalsWidgetStore.load()
        completion(GoalsTimelineEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GoalsTimelineEntry>) -> Void) {
        let entry = GoalsTimelineEntry(date: Date(), snapshot: GoalsWidgetStore.load())
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct GoalsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: GoalsWidgetKind.id, provider: GoalsProvider()) { entry in
            GoalsWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    widgetBackground
                }
        }
        .configurationDisplayName("Goals")
        .description("Track all-time and meet goal times from SwimTracker.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }

    private var widgetBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.22, blue: 0.38),
                Color(red: 0.03, green: 0.12, blue: 0.22)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Views

private let accent = Color(red: 0.055, green: 0.647, blue: 0.914)
private let success = Color(red: 0.204, green: 0.827, blue: 0.600)
private let danger = Color(red: 0.973, green: 0.443, blue: 0.443)

struct GoalsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GoalsTimelineEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemLarge:
            listView(limit: 6)
        default:
            listView(limit: 3)
        }
    }

    private var smallView: some View {
        Group {
            if let goal = entry.snapshot.entries.first {
                VStack(alignment: .leading, spacing: 6) {
                    Text("GOALS")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(accent)
                    Text(goal.eventName)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(goal.course)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.65))
                    Spacer(minLength: 0)
                    goalBlock(
                        label: goal.primaryLabel,
                        goalSeconds: goal.primaryGoal,
                        bestSeconds: goal.primaryBest,
                        compact: true
                    )
                }
            } else {
                emptyView
            }
        }
    }

    private func listView(limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Goals")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                if !entry.snapshot.seasonLabel.isEmpty {
                    Text(entry.snapshot.seasonLabel)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }

            if entry.snapshot.entries.isEmpty {
                emptyView
            } else {
                ForEach(Array(entry.snapshot.entries.prefix(limit))) { goal in
                    goalRow(goal)
                    if goal.id != entry.snapshot.entries.prefix(limit).last?.id {
                        Divider().overlay(.white.opacity(0.12))
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func goalRow(_ goal: GoalsWidgetEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.eventName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(goal.course)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 3) {
                if goal.allTimeGoal != nil {
                    goalBlock(
                        label: "AT",
                        goalSeconds: goal.allTimeGoal,
                        bestSeconds: goal.allTimeBest,
                        compact: true
                    )
                }
                if goal.meetGoal != nil {
                    goalBlock(
                        label: "Meet",
                        goalSeconds: goal.meetGoal,
                        bestSeconds: goal.seasonBest,
                        compact: true
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func goalBlock(label: String, goalSeconds: Double?, bestSeconds: Double?, compact: Bool) -> some View {
        if let goalSeconds {
            let met = bestSeconds.map { $0 <= goalSeconds } ?? false
            let gap = bestSeconds.map { $0 - goalSeconds }
            VStack(alignment: compact ? .trailing : .leading, spacing: 1) {
                Text("\(label) \(goalSeconds.asWidgetSwimTime)")
                    .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                if let bestSeconds {
                    if met {
                        Text("Hit · \(bestSeconds.asWidgetSwimTime)")
                            .font(.caption2)
                            .foregroundStyle(success)
                            .monospacedDigit()
                    } else if let gap {
                        Text("\(bestSeconds.asWidgetSwimTime) · +\(gap.asWidgetSwimTime)")
                            .font(.caption2)
                            .foregroundStyle(danger)
                            .monospacedDigit()
                    }
                } else {
                    Text("No swim yet")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
    }

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("GOALS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(accent)
            Text("No goals yet")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Set all-time or meet goals in SwimTracker.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Placeholder

extension GoalsWidgetSnapshot {
    static let placeholder = GoalsWidgetSnapshot(
        updatedAt: Date(),
        seasonLabel: "2025–26",
        entries: [
            GoalsWidgetEntry(
                id: "100|Free|SCY|I",
                eventName: "100 Free",
                course: "SCY",
                allTimeGoal: 48.50,
                allTimeBest: 49.82,
                meetGoal: 49.20,
                seasonBest: 50.11
            ),
            GoalsWidgetEntry(
                id: "200|IM|SCY|I",
                eventName: "200 IM",
                course: "SCY",
                allTimeGoal: 1 * 60 + 58.00,
                allTimeBest: 2 * 60 + 1.40,
                meetGoal: nil,
                seasonBest: nil
            ),
            GoalsWidgetEntry(
                id: "100|Fly|SCY|I",
                eventName: "100 Fly",
                course: "SCY",
                allTimeGoal: 54.00,
                allTimeBest: 53.40,
                meetGoal: 54.50,
                seasonBest: 54.20
            )
        ]
    )
}

#Preview(as: .systemSmall) {
    GoalsWidget()
} timeline: {
    GoalsTimelineEntry(date: .now, snapshot: .placeholder)
}

#Preview(as: .systemMedium) {
    GoalsWidget()
} timeline: {
    GoalsTimelineEntry(date: .now, snapshot: .placeholder)
}
