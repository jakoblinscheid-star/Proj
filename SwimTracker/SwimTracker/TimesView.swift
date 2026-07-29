import SwiftUI

/// Times tab: your best time in every event you've swum, sortable by swim score
/// or by event. Tap an event to see all of its times and a progression graph.
struct TimesView: View {
    @Environment(Store.self) private var store

    @State private var showingAdd = false
    @State private var showingBaseTimes = false
    @State private var courseFilter: Course? = nil

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Group {
                if store.times.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .navigationTitle("Times")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 12) {
                        goalsLink
                        baseTimesButton
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort by", selection: $store.settings.timesSortMode) {
                            ForEach(TimesSortMode.allCases) { mode in
                                Label(mode.rawValue, systemImage: mode.systemImage).tag(mode)
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) { addButton }
            }
            .sheet(isPresented: $showingAdd) {
                AddTimeView(defaultCourse: store.settings.defaultCourse)
            }
            .sheet(isPresented: $showingBaseTimes) {
                BaseTimesView()
            }
            .navigationDestination(for: SwimEvent.self) { event in
                EventDetailView(event: event)
            }
        }
    }

    // MARK: Content

    private var content: some View {
        VStack(spacing: 0) {
            Picker("Course", selection: $courseFilter) {
                Text("All").tag(Course?.none)
                ForEach(Course.allCases) { course in
                    Text(course.rawValue).tag(Course?.some(course))
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            eventsList
        }
    }

    private var eventsList: some View {
        List {
            switch store.settings.timesSortMode {
            case .score:
                Section {
                    ForEach(eventsSortedByScore) { event in
                        eventLink(event)
                    }
                } footer: {
                    Text("World Aquatics points (\(store.settings.gender.rawValue.lowercased())), best time per event — including opening splits from longer races. All-time goals shown under each best.")
                }
            case .event:
                ForEach(coursesToShow) { course in
                    Section(course.label) {
                        ForEach(events(for: course)) { event in
                            eventLink(event)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func eventLink(_ event: SwimEvent) -> some View {
        NavigationLink(value: event) {
            BestTimeRowView(event: event)
        }
    }

    // MARK: Derived data

    private var filteredEvents: [SwimEvent] {
        store.eventsWithTimes.filter { courseFilter == nil || $0.course == courseFilter }
    }

    private var eventsSortedByScore: [SwimEvent] {
        filteredEvents.sorted { lhs, rhs in
            let l = store.bestScore(for: lhs) ?? -1
            let r = store.bestScore(for: rhs) ?? -1
            if l != r { return l > r }
            return lhs < rhs
        }
    }

    private var coursesToShow: [Course] {
        Course.allCases.filter { course in
            (courseFilter == nil || courseFilter == course) && filteredEvents.contains { $0.course == course }
        }
    }

    private func events(for course: Course) -> [SwimEvent] {
        filteredEvents.filter { $0.course == course }.sorted(by: <)
    }

    // MARK: Toolbar pieces

    private var goalsLink: some View {
        NavigationLink {
            GoalsView()
        } label: {
            Label("Goals", systemImage: "target")
        }
    }

    private var baseTimesButton: some View {
        Button {
            showingBaseTimes = true
        } label: {
            Label("Base Times", systemImage: "trophy.fill")
        }
    }

    private var addButton: some View {
        Button {
            showingAdd = true
        } label: {
            Label("Add time", systemImage: "plus")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No times yet", systemImage: "stopwatch.fill")
        } description: {
            Text("Add a swim to start tracking your best times and swim scores.")
        } actions: {
            Button {
                showingAdd = true
            } label: {
                Label("Add your first time", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Best time row

/// One row in the Times list: an event, its best time, and the swim score.
struct BestTimeRowView: View {
    @Environment(Store.self) private var store
    let event: SwimEvent

    private var best: EventPerformance? { store.bestPerformance(for: event) }
    private var count: Int { store.performances(for: event).count }
    private var allTimeGoal: Double? { store.goals(for: event)?.allTimeSeconds }

    var body: some View {
        HStack(spacing: 12) {
            StrokeBadge(stroke: event.stroke)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.name)
                    .font(.headline)
                Text("\(event.course.rawValue) · \(count) \(count == 1 ? "swim" : "swims")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                if let best {
                    Text(best.seconds.asSwimTime)
                        .font(.headline)
                        .monospacedDigit()
                    if let allTimeGoal {
                        Text("Goal \(allTimeGoal.asSwimTime)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                if let score = store.bestScore(for: event) {
                    ScoreBadge(points: score)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TimesView()
        .environment(Store())
        .tint(Theme.accent)
}
