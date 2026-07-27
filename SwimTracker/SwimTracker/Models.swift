import Foundation
import Observation

/// A swim meet you competed in. The events you swam are stored as `SwimTime`s that
/// reference the meet by `id` (see `Store.results(forMeet:)`).
struct Meet: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    /// The team/club you were swimming under at this meet.
    var team: String = ""
    var location: String = ""
    var date: Date = Date()
}

// MARK: - Swim vocabulary

/// Pool / course type. Each course has its own set of world/US-Open base times,
/// so a "100 Free" in yards is a different event from a "100 Free" in meters.
enum Course: String, Codable, CaseIterable, Identifiable {
    case scy = "SCY"   // short course yards (25y)
    case scm = "SCM"   // short course meters (25m)
    case lcm = "LCM"   // long course meters (50m)

    var id: String { rawValue }

    var label: String {
        switch self {
        case .scy: return "Short Course Yards"
        case .scm: return "Short Course Meters"
        case .lcm: return "Long Course Meters"
        }
    }

    /// Distance unit, e.g. "100 yd" vs "100 m".
    var unit: String { self == .scy ? "yd" : "m" }

    /// Display ordering: yards, short-course meters, then long-course meters.
    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

/// The four strokes plus individual medley.
enum Stroke: String, Codable, CaseIterable, Identifiable {
    case freestyle = "Free"
    case backstroke = "Back"
    case breaststroke = "Breast"
    case butterfly = "Fly"
    case medley = "IM"

    var id: String { rawValue }

    var fullName: String {
        switch self {
        case .freestyle: return "Freestyle"
        case .backstroke: return "Backstroke"
        case .breaststroke: return "Breaststroke"
        case .butterfly: return "Butterfly"
        case .medley: return "Individual Medley"
        }
    }

    /// Conventional heat-sheet ordering (free, back, breast, fly, IM).
    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

/// Whose base times to score against. World Aquatics points are gender specific.
enum Gender: String, Codable, CaseIterable, Identifiable {
    case men = "M"
    case women = "F"

    var id: String { rawValue }
    var label: String { self == .men ? "Men" : "Women" }
}

/// A specific event: a distance + stroke in a particular course. Relays reuse this
/// type with `isRelay == true` and `stroke` acting as the relay type (`.freestyle`
/// or `.medley`); `distance` is then the per-leg distance of a 4-person relay.
struct SwimEvent: Codable, Hashable, Identifiable {
    var distance: Int
    var stroke: Stroke
    var course: Course
    var isRelay: Bool = false

    var id: String { "\(distance)|\(stroke.rawValue)|\(course.rawValue)|\(isRelay ? "R" : "I")" }

    /// The relay type spelled as swimmers say it ("Free" / "Medley").
    private var relayTypeLabel: String { stroke == .medley ? "Medley" : "Free" }

    /// Compact label, e.g. "100 Free", or "400 Free Relay" (yards) / "4×100 Free Relay" (meters).
    var name: String {
        guard isRelay else { return "\(distance) \(stroke.rawValue)" }
        if course == .scy { return "\(distance * 4) \(relayTypeLabel) Relay" }
        return "4×\(distance) \(relayTypeLabel) Relay"
    }

    /// Spelled-out label, e.g. "100 Freestyle" or "4×100 Freestyle Relay".
    var fullName: String {
        guard isRelay else { return "\(distance) \(stroke.fullName)" }
        let type = stroke == .medley ? "Medley" : "Freestyle"
        if course == .scy { return "\(distance * 4) \(type) Relay" }
        return "4×\(distance) \(type) Relay"
    }

    /// Label including the course, e.g. "100 Free · SCY".
    var titleWithCourse: String { "\(name) · \(course.rawValue)" }

    /// Stable ordering: individual events first, then relays; then course/stroke/distance.
    static func < (lhs: SwimEvent, rhs: SwimEvent) -> Bool {
        if lhs.isRelay != rhs.isRelay { return !lhs.isRelay && rhs.isRelay }
        if lhs.course.order != rhs.course.order { return lhs.course.order < rhs.course.order }
        if lhs.stroke.order != rhs.stroke.order { return lhs.stroke.order < rhs.stroke.order }
        return lhs.distance < rhs.distance
    }
}

/// A single swim. Recorded at a meet or on its own. `seconds` is optional so you can
/// log an event you swam and fill in the time later.
struct SwimTime: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var distance: Int
    var stroke: Stroke
    var course: Course
    var seconds: Double? = nil
    var date: Date = Date()
    var meetID: String? = nil
    var isRelay: Bool = false
    var note: String = ""

    var event: SwimEvent { SwimEvent(distance: distance, stroke: stroke, course: course, isRelay: isRelay) }
}

// MARK: - Backward-compatible decoding
//
// Synthesized Codable throws when a key is missing, even for properties that have
// default values. These custom decoders let older saved files (without `team` /
// `isRelay`, or with a non-optional `seconds`) load cleanly. Placing them in
// extensions preserves each struct's memberwise initializer.

extension Meet {
    enum CodingKeys: String, CodingKey { case id, name, team, location, date }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try container.decode(String.self, forKey: .name)
        team = try container.decodeIfPresent(String.self, forKey: .team) ?? ""
        location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
    }
}

extension SwimTime {
    enum CodingKeys: String, CodingKey {
        case id, distance, stroke, course, seconds, date, meetID, isRelay, note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        distance = try container.decode(Int.self, forKey: .distance)
        stroke = try container.decode(Stroke.self, forKey: .stroke)
        course = try container.decode(Course.self, forKey: .course)
        seconds = try container.decodeIfPresent(Double.self, forKey: .seconds)
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        meetID = try container.decodeIfPresent(String.self, forKey: .meetID)
        isRelay = try container.decodeIfPresent(Bool.self, forKey: .isRelay) ?? false
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}

// MARK: - Scoring (World Aquatics points)

/// World Aquatics ("FINA") point scoring: `P = 1000 * (base / time)^3`.
/// Matching the base time is 1000 points; faster is more. Points are truncated
/// to an integer, exactly as World Aquatics defines them.
enum SwimScore {
    static func baseTime(distance: Int, stroke: Stroke, course: Course, gender: Gender) -> Double? {
        BaseTimes.table[gender]?[EventKey(course: course, stroke: stroke, distance: distance)]
    }

    static func points(seconds: Double, distance: Int, stroke: Stroke, course: Course, gender: Gender) -> Int? {
        guard seconds > 0,
              let base = baseTime(distance: distance, stroke: stroke, course: course, gender: gender),
              base > 0
        else { return nil }
        let value = 1000.0 * pow(base / seconds, 3)
        guard value.isFinite, value >= 0 else { return nil }
        return Int(value)
    }
}

private struct EventKey: Hashable {
    let course: Course
    let stroke: Stroke
    let distance: Int
}

/// Base ("1000-point") times in seconds.
///
/// - LCM / SCM use World Aquatics base times (current world records).
/// - SCY uses U.S. Open records (fastest yards time swum in the United States).
///
/// These are the benchmarks a swim of 1000 points would match; update them here
/// when new records are set.
enum BaseTimes {
    static let table: [Gender: [EventKey: Double]] = [
        .men: build(men),
        .women: build(women)
    ]

    /// The catalog of individual events that can be scored for a course, in heat-sheet order.
    static func events(for course: Course) -> [SwimEvent] {
        let keys = (table[.men] ?? [:]).keys.filter { $0.course == course }
        return keys
            .map { SwimEvent(distance: $0.distance, stroke: $0.stroke, course: $0.course) }
            .sorted(by: <)
    }

    /// The standard relay events for a course (per-leg distances of a 4-person relay).
    static func relayEvents(for course: Course) -> [SwimEvent] {
        let freeLegs: [Int]
        let medleyLegs: [Int]
        switch course {
        case .scy, .scm:
            freeLegs = [50, 100, 200]
            medleyLegs = [50, 100]
        case .lcm:
            freeLegs = [100, 200]
            medleyLegs = [100]
        }
        let free = freeLegs.map { SwimEvent(distance: $0, stroke: .freestyle, course: course, isRelay: true) }
        let medley = medleyLegs.map { SwimEvent(distance: $0, stroke: .medley, course: course, isRelay: true) }
        return free + medley
    }

    private static func build(_ entries: [(Course, Stroke, Int, Double)]) -> [EventKey: Double] {
        var result: [EventKey: Double] = [:]
        for (course, stroke, distance, seconds) in entries {
            result[EventKey(course: course, stroke: stroke, distance: distance)] = seconds
        }
        return result
    }

    // MARK: Men

    private static let men: [(Course, Stroke, Int, Double)] = [
        // Long course meters (World Aquatics base times)
        (.lcm, .freestyle, 50, 20.91), (.lcm, .freestyle, 100, 46.40), (.lcm, .freestyle, 200, 102.00),
        (.lcm, .freestyle, 400, 219.96), (.lcm, .freestyle, 800, 452.12), (.lcm, .freestyle, 1500, 870.67),
        (.lcm, .backstroke, 50, 23.55), (.lcm, .backstroke, 100, 51.60), (.lcm, .backstroke, 200, 111.92),
        (.lcm, .breaststroke, 50, 25.95), (.lcm, .breaststroke, 100, 56.88), (.lcm, .breaststroke, 200, 125.48),
        (.lcm, .butterfly, 50, 22.27), (.lcm, .butterfly, 100, 49.45), (.lcm, .butterfly, 200, 110.34),
        (.lcm, .medley, 200, 112.69), (.lcm, .medley, 400, 242.50),

        // Short course meters (World Aquatics base times)
        (.scm, .freestyle, 50, 19.90), (.scm, .freestyle, 100, 44.84), (.scm, .freestyle, 200, 98.61),
        (.scm, .freestyle, 400, 212.25), (.scm, .freestyle, 800, 440.46), (.scm, .freestyle, 1500, 846.88),
        (.scm, .backstroke, 50, 22.11), (.scm, .backstroke, 100, 48.33), (.scm, .backstroke, 200, 105.63),
        (.scm, .breaststroke, 50, 24.95), (.scm, .breaststroke, 100, 55.28), (.scm, .breaststroke, 200, 120.16),
        (.scm, .butterfly, 50, 21.32), (.scm, .butterfly, 100, 47.71), (.scm, .butterfly, 200, 106.85),
        (.scm, .medley, 100, 49.28), (.scm, .medley, 200, 108.88), (.scm, .medley, 400, 234.81),

        // Short course yards (U.S. Open records)
        (.scy, .freestyle, 50, 17.63), (.scy, .freestyle, 100, 39.83), (.scy, .freestyle, 200, 88.33),
        (.scy, .freestyle, 500, 242.31), (.scy, .freestyle, 1000, 512.83), (.scy, .freestyle, 1650, 850.03),
        (.scy, .backstroke, 100, 42.61), (.scy, .backstroke, 200, 94.13),
        (.scy, .breaststroke, 100, 49.51), (.scy, .breaststroke, 200, 106.35),
        (.scy, .butterfly, 100, 42.49), (.scy, .butterfly, 200, 96.41),
        (.scy, .medley, 200, 96.34), (.scy, .medley, 400, 208.82),

        // Short course yards — no official U.S. Open record exists for these events.
        // Drop in a reference time (in seconds) to enable scoring; 0 leaves the
        // event loggable but unscored. e.g. a 46.97 = 46.97, a 1:02.36 = 62.36.
        (.scy, .backstroke, 50, 20.07), (.scy, .breaststroke, 50, 22.96), (.scy, .butterfly, 50, 19.90),
        (.scy, .medley, 100, 46.33)  // Shaine Casas
    ]

    // MARK: Women

    private static let women: [(Course, Stroke, Int, Double)] = [
        // Long course meters (World Aquatics base times)
        (.lcm, .freestyle, 50, 23.61), (.lcm, .freestyle, 100, 51.71), (.lcm, .freestyle, 200, 112.23),
        (.lcm, .freestyle, 400, 234.18), (.lcm, .freestyle, 800, 484.12), (.lcm, .freestyle, 1500, 920.48),
        (.lcm, .backstroke, 50, 26.86), (.lcm, .backstroke, 100, 57.13), (.lcm, .backstroke, 200, 123.14),
        (.lcm, .breaststroke, 50, 29.16), (.lcm, .breaststroke, 100, 64.13), (.lcm, .breaststroke, 200, 137.55),
        (.lcm, .butterfly, 50, 24.43), (.lcm, .butterfly, 100, 54.60), (.lcm, .butterfly, 200, 121.81),
        (.lcm, .medley, 200, 125.70), (.lcm, .medley, 400, 263.65),

        // Short course meters (World Aquatics base times)
        (.scm, .freestyle, 50, 22.83), (.scm, .freestyle, 100, 50.25), (.scm, .freestyle, 200, 110.31),
        (.scm, .freestyle, 400, 230.25), (.scm, .freestyle, 800, 477.42), (.scm, .freestyle, 1500, 908.24),
        (.scm, .backstroke, 50, 25.25), (.scm, .backstroke, 100, 54.02), (.scm, .backstroke, 200, 118.83),
        (.scm, .breaststroke, 50, 28.37), (.scm, .breaststroke, 100, 62.36), (.scm, .breaststroke, 200, 132.72),
        (.scm, .butterfly, 50, 23.94), (.scm, .butterfly, 100, 52.71), (.scm, .butterfly, 200, 119.32),
        (.scm, .medley, 100, 55.11), (.scm, .medley, 200, 121.63), (.scm, .medley, 400, 255.48),

        // Short course yards (U.S. Open records)
        (.scy, .freestyle, 50, 20.37), (.scy, .freestyle, 100, 44.71), (.scy, .freestyle, 200, 99.10),
        (.scy, .freestyle, 500, 264.06), (.scy, .freestyle, 1000, 539.65), (.scy, .freestyle, 1650, 899.62),
        (.scy, .backstroke, 100, 48.10), (.scy, .backstroke, 200, 106.09),
        (.scy, .breaststroke, 100, 55.73), (.scy, .breaststroke, 200, 121.29),
        (.scy, .butterfly, 100, 46.97), (.scy, .butterfly, 200, 108.33),
        (.scy, .medley, 200, 108.37), (.scy, .medley, 400, 234.60),

        // Short course yards — no official U.S. Open record exists for these events.
        // Drop in a reference time (in seconds) to enable scoring; 0 leaves the
        // event loggable but unscored. e.g. a 46.97 = 46.97, a 1:02.36 = 62.36.
        (.scy, .backstroke, 50, 0.0), (.scy, .breaststroke, 50, 0.0), (.scy, .butterfly, 50, 0.0),
        (.scy, .medley, 100, 0.0)
    ]
}

// MARK: - Overall score

/// One event's contribution to an overall score.
struct ScoreComponent: Identifiable, Hashable {
    let event: SwimEvent
    let points: Int
    /// The event's share of the overall. Components of an overall sum to 1.
    let weight: Double

    var id: String { event.id }
}

/// A weighted overall built from a swimmer's best events, Swimcloud-style: a
/// weighted average of the top events (0.4 / 0.4 / 0.15 / 0.05), renormalised
/// when fewer than four events exist so one event equals its own score.
struct OverallScore {
    let value: Int
    /// The events that fed the overall, best-scoring first.
    let components: [ScoreComponent]

    var isEmpty: Bool { components.isEmpty }
}

/// Overall for a single team, for the "By team" list.
struct TeamOverall: Identifiable {
    let team: String
    let overall: OverallScore

    var id: String { team }
}

/// A per-year overall, for the progression graph.
struct YearlyScore: Identifiable {
    let year: Int
    let value: Int

    var id: Int { year }
}

// MARK: - Store

/// App-wide state. Owns the user's data and persists it to disk as JSON in the
/// app's Documents directory, mirroring the sibling TabTrack app's local-first design.
@Observable
final class Store {
    var meets: [Meet] = [] {
        didSet { saveMeets() }
    }

    var times: [SwimTime] = [] {
        didSet { saveTimes() }
    }

    /// Whose base times are used to score times into World Aquatics points.
    var gender: Gender = .men {
        didSet { saveTimes() }
    }

    @ObservationIgnored private let meetsURL: URL
    @ObservationIgnored private let timesURL: URL
    @ObservationIgnored private var isLoading = false

    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        meetsURL = dir.appendingPathComponent("swimtracker.v1.json")
        timesURL = dir.appendingPathComponent("swimtracker.times.v1.json")
        load()
    }

    // MARK: Meets

    /// Meets sorted newest-first.
    var meetsByDate: [Meet] {
        meets.sorted { $0.date > $1.date }
    }

    /// The most recent meets, for the Home page.
    func recentMeets(limit: Int = 5) -> [Meet] {
        Array(meetsByDate.prefix(limit))
    }

    /// Creates a meet and returns its id so callers can immediately attach results.
    @discardableResult
    func addMeet(name: String, team: String, location: String, date: Date) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let meet = Meet(name: trimmed,
                        team: team.trimmingCharacters(in: .whitespacesAndNewlines),
                        location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                        date: date)
        meets.append(meet)
        return meet.id
    }

    func updateMeet(id: String, name: String, team: String, location: String, date: Date) {
        guard let index = meets.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let dateChanged = meets[index].date != date
        meets[index].name = trimmed
        meets[index].team = team.trimmingCharacters(in: .whitespacesAndNewlines)
        meets[index].location = location.trimmingCharacters(in: .whitespacesAndNewlines)
        meets[index].date = date

        // Keep results in sync with the meet date so progression charts stay accurate.
        if dateChanged {
            for i in times.indices where times[i].meetID == id {
                times[i].date = date
            }
        }
    }

    /// Deletes a meet and the results (times/relays) recorded at it.
    func deleteMeet(id: String) {
        times.removeAll { $0.meetID == id }
        meets.removeAll { $0.id == id }
    }

    func meet(id: String) -> Meet? {
        meets.first { $0.id == id }
    }

    // MARK: Times

    /// Distinct individual events the swimmer has an actual time for, in heat-sheet
    /// order. Relays and not-yet-timed entries are excluded from the Times tab.
    var eventsWithTimes: [SwimEvent] {
        let recorded = times.filter { !$0.isRelay && $0.seconds != nil }
        return Array(Set(recorded.map { $0.event })).sorted(by: <)
    }

    /// All times for an event, oldest first.
    func times(for event: SwimEvent) -> [SwimTime] {
        times.filter { $0.event == event }.sorted { $0.date < $1.date }
    }

    /// Times for an event that have an actual clocked time, oldest first.
    func recordedTimes(for event: SwimEvent) -> [SwimTime] {
        times(for: event).filter { $0.seconds != nil }
    }

    /// The fastest recorded time for an event.
    func bestTime(for event: SwimEvent) -> SwimTime? {
        recordedTimes(for: event).min {
            ($0.seconds ?? .greatestFiniteMagnitude) < ($1.seconds ?? .greatestFiniteMagnitude)
        }
    }

    /// World Aquatics points for a single recorded swim, using the current gender.
    /// Relays and not-yet-timed entries have no score.
    func score(for time: SwimTime) -> Int? {
        guard !time.isRelay, let seconds = time.seconds else { return nil }
        return SwimScore.points(seconds: seconds,
                                distance: time.distance,
                                stroke: time.stroke,
                                course: time.course,
                                gender: gender)
    }

    /// Points for the fastest time in an event (the swimmer's best score there).
    func bestScore(for event: SwimEvent) -> Int? {
        guard let best = bestTime(for: event) else { return nil }
        return score(for: best)
    }

    /// Resolved meet name for a recorded time, if it references a meet.
    func meetName(for time: SwimTime) -> String? {
        guard let meetID = time.meetID else { return nil }
        return meet(id: meetID)?.name
    }

    // MARK: Overall scoring

    /// Label for times that count toward an overall but have no team of their own.
    static let unattachedTeam = "Unattached"

    /// Weights applied to a swimmer's top events, best-first: 40% / 40% / 15% / 5%.
    /// When fewer than four events exist they are renormalised so the overall stays
    /// a true weighted average (one event = its own score).
    static let overallWeights: [Double] = [0.4, 0.4, 0.15, 0.05]

    /// Builds a weighted overall from a set of times: the best score per individual
    /// event, then the top four events combined as a renormalised weighted average.
    func overallScore(for source: [SwimTime]) -> OverallScore {
        var bestByEvent: [SwimEvent: Int] = [:]
        for time in source where !time.isRelay && time.seconds != nil {
            guard let points = score(for: time) else { continue }
            if let existing = bestByEvent[time.event], existing >= points { continue }
            bestByEvent[time.event] = points
        }

        let ranked = bestByEvent.sorted { $0.value > $1.value }
        let weights = Array(Store.overallWeights.prefix(ranked.count))
        guard !weights.isEmpty else { return OverallScore(value: 0, components: []) }

        let totalWeight = weights.reduce(0, +)
        var components: [ScoreComponent] = []
        var weightedSum = 0.0
        for (index, weight) in weights.enumerated() {
            let entry = ranked[index]
            let normalized = weight / totalWeight
            components.append(ScoreComponent(event: entry.key, points: entry.value, weight: normalized))
            weightedSum += Double(entry.value) * normalized
        }
        return OverallScore(value: Int(weightedSum.rounded()), components: components)
    }

    /// The overall across every recorded time.
    var allTimesOverall: OverallScore { overallScore(for: times) }

    /// The team a recorded time counts toward, or nil if it should only feed the
    /// all-times overall (a time not linked to any meet). Meets with no team name
    /// group under "Unattached".
    func teamKey(for time: SwimTime) -> String? {
        guard let meetID = time.meetID, let meet = meet(id: meetID) else { return nil }
        let team = meet.team.trimmingCharacters(in: .whitespacesAndNewlines)
        return team.isEmpty ? Store.unattachedTeam : team
    }

    /// Overall score for each team you've competed under, best-first ("Unattached" last).
    var teamOveralls: [TeamOverall] {
        let scored = times.filter { !$0.isRelay && $0.seconds != nil }
        let groups = Dictionary(grouping: scored) { teamKey(for: $0) }
        var result: [TeamOverall] = []
        for (key, group) in groups {
            guard let key else { continue }
            let overall = overallScore(for: group)
            guard !overall.isEmpty else { continue }
            result.append(TeamOverall(team: key, overall: overall))
        }
        return result.sorted { lhs, rhs in
            if (lhs.team == Store.unattachedTeam) != (rhs.team == Store.unattachedTeam) {
                return rhs.team == Store.unattachedTeam
            }
            if lhs.overall.value != rhs.overall.value { return lhs.overall.value > rhs.overall.value }
            return lhs.team < rhs.team
        }
    }

    /// Per-year overall for the progression graph. Pass a team to scope it, or nil
    /// for all times. Each year uses only the swims recorded in that year.
    func yearlyOveralls(team: String? = nil) -> [YearlyScore] {
        var scored = times.filter { !$0.isRelay && $0.seconds != nil }
        if let team {
            scored = scored.filter { teamKey(for: $0) == team }
        }
        let byYear = Dictionary(grouping: scored) { Calendar.current.component(.year, from: $0.date) }
        return byYear
            .compactMap { year, group -> YearlyScore? in
                let overall = overallScore(for: group)
                return overall.isEmpty ? nil : YearlyScore(year: year, value: overall.value)
            }
            .sorted { $0.year < $1.year }
    }

    func addTime(distance: Int, stroke: Stroke, course: Course, seconds: Double?, date: Date, meetID: String?, isRelay: Bool = false, note: String) {
        let time = SwimTime(distance: distance,
                            stroke: stroke,
                            course: course,
                            seconds: normalized(seconds),
                            date: date,
                            meetID: meetID,
                            isRelay: isRelay,
                            note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        times.append(time)
    }

    func updateTime(id: String, distance: Int, stroke: Stroke, course: Course, seconds: Double?, date: Date, meetID: String?, isRelay: Bool, note: String) {
        guard let index = times.firstIndex(where: { $0.id == id }) else { return }
        times[index].distance = distance
        times[index].stroke = stroke
        times[index].course = course
        times[index].seconds = normalized(seconds)
        times[index].date = date
        times[index].meetID = meetID
        times[index].isRelay = isRelay
        times[index].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func deleteTime(id: String) {
        times.removeAll { $0.id == id }
    }

    private func normalized(_ seconds: Double?) -> Double? {
        guard let seconds, seconds > 0 else { return nil }
        return seconds
    }

    // MARK: Meet results

    /// The events swum at a meet (individual + relay), in heat-sheet order.
    func results(forMeet meetID: String) -> [SwimTime] {
        times.filter { $0.meetID == meetID }.sorted { $0.event < $1.event }
    }

    /// A recorded event (with or without a time) attached to a meet.
    func addResult(toMeet meetID: String, event: SwimEvent, seconds: Double?, note: String = "") {
        let date = meet(id: meetID)?.date ?? Date()
        addTime(distance: event.distance,
                stroke: event.stroke,
                course: event.course,
                seconds: seconds,
                date: date,
                meetID: meetID,
                isRelay: event.isRelay,
                note: note)
    }

    // MARK: Persistence

    private struct TimesData: Codable {
        var gender: Gender = .men
        var times: [SwimTime] = []
    }

    private func load() {
        isLoading = true
        defer { isLoading = false }

        if let data = try? Data(contentsOf: meetsURL),
           let decoded = try? JSONDecoder.swimTracker.decode([Meet].self, from: data) {
            meets = decoded
        }

        if let data = try? Data(contentsOf: timesURL),
           let decoded = try? JSONDecoder.swimTracker.decode(TimesData.self, from: data) {
            gender = decoded.gender
            times = decoded.times
        }
    }

    private func saveMeets() {
        guard !isLoading else { return }
        guard let data = try? JSONEncoder.swimTracker.encode(meets) else { return }
        try? data.write(to: meetsURL, options: [.atomic])
    }

    private func saveTimes() {
        guard !isLoading else { return }
        let payload = TimesData(gender: gender, times: times)
        guard let data = try? JSONEncoder.swimTracker.encode(payload) else { return }
        try? data.write(to: timesURL, options: [.atomic])
    }
}

private extension JSONEncoder {
    static let swimTracker: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

private extension JSONDecoder {
    static let swimTracker: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
