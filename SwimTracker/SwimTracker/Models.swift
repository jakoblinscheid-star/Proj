import Foundation
import Observation

/// Heat session for a result at a prelims/finals meet.
enum MeetRound: String, Codable, CaseIterable, Identifiable {
    case prelims = "Prelims"
    case finals = "Finals"

    var id: String { rawValue }

    /// Compact label for list rows, e.g. "Prelim" / "Final".
    var shortLabel: String {
        switch self {
        case .prelims: return "Prelim"
        case .finals: return "Final"
        }
    }

    /// Stable ordering: prelims before finals.
    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

/// A swim meet you competed in. The events you swam are stored as `SwimTime`s that
/// reference the meet by `id` (see `Store.results(forMeet:)`).
struct Meet: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    /// The team/club you were swimming under at this meet.
    var team: String = ""
    var location: String = ""
    /// First day of the meet (also used for result dates and sorting).
    var date: Date = Date()
    /// Last day of the meet. Same as `date` for a single-day meet.
    var endDate: Date = Date()
    /// Pool length / course for every event at this meet.
    var course: Course = .scy
    /// When true, results at this meet can be tagged Prelims or Finals.
    var hasPrelimsFinals: Bool = false

    /// Inclusive date range label, e.g. "Jul 1, 2026" or "Jul 1–3, 2026".
    var dateRangeLabel: String {
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: endDate) {
            return date.asShortDate
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        if calendar.component(.year, from: date) == calendar.component(.year, from: endDate) {
            let startFormatter = DateFormatter()
            startFormatter.dateFormat = "MMM d"
            let endFormatter = DateFormatter()
            endFormatter.dateFormat = "MMM d, yyyy"
            return "\(startFormatter.string(from: date))–\(endFormatter.string(from: endDate))"
        }
        return "\(formatter.string(from: date)) – \(formatter.string(from: endDate))"
    }
}

/// Helpers for relay leg metadata (4-person relays).
enum RelayLegInfo {
    static let legs = Array(1...4)

    /// Conventional medley order: back, breast, fly, free.
    static func defaultMedleyStroke(forLeg leg: Int) -> Stroke {
        switch leg {
        case 1: return .backstroke
        case 2: return .breaststroke
        case 3: return .butterfly
        default: return .freestyle
        }
    }

    static var medleyStrokes: [Stroke] {
        [.backstroke, .breaststroke, .butterfly, .freestyle]
    }
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

/// Whose base times to score against. World Aquatics points are gender-specific.
enum Gender: String, Codable, CaseIterable, Identifiable {
    case male = "Male"
    case female = "Female"

    var id: String { rawValue }
}

/// How the Times tab orders events.
enum TimesSortMode: String, Codable, CaseIterable, Identifiable {
    case score = "Swim score"
    case event = "Event"

    var id: String { rawValue }

    var systemImage: String { self == .score ? "rosette" : "list.number" }
}

/// User preferences persisted separately from meet/time data.
struct AppSettings: Codable, Equatable {
    /// Gender used for Times badges, Your Score, and score previews.
    var gender: Gender = .male
    /// Pre-selected course when adding times, meet results, Calc, Convert, and Base Times.
    var defaultCourse: Course = .scy
    /// Default (and remembered) sort order on the Times tab.
    var timesSortMode: TimesSortMode = .score

    enum CodingKeys: String, CodingKey {
        case gender, defaultCourse, timesSortMode
    }

    init(
        gender: Gender = .male,
        defaultCourse: Course = .scy,
        timesSortMode: TimesSortMode = .score
    ) {
        self.gender = gender
        self.defaultCourse = defaultCourse
        self.timesSortMode = timesSortMode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gender = try container.decodeIfPresent(Gender.self, forKey: .gender) ?? .male
        defaultCourse = try container.decodeIfPresent(Course.self, forKey: .defaultCourse) ?? .scy
        timesSortMode = try container.decodeIfPresent(TimesSortMode.self, forKey: .timesSortMode) ?? .score
    }
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
    /// Final time (individual) or whole-relay team time (relay).
    var seconds: Double? = nil
    /// Interval time for each 50 of the race. Empty when splits were not recorded.
    /// When present, count must equal `distance / 50` and every value must be > 0.
    var splits: [Double] = []
    var date: Date = Date()
    var meetID: String? = nil
    var isRelay: Bool = false
    var note: String = ""
    /// Prelims or Finals when the linked meet uses prelims/finals. Nil otherwise.
    var round: MeetRound? = nil
    /// Which leg you swam (1–4). Nil for individual swims.
    var relayLeg: Int? = nil
    /// Stroke for that leg (required for medley; free relays use freestyle).
    var relayLegStroke: Stroke? = nil
    /// Your personal leg split time.
    var relayLegSeconds: Double? = nil
    /// True when this was the lead-off leg (typically leg 1).
    var isRelayLeadOff: Bool = false

    var event: SwimEvent { SwimEvent(distance: distance, stroke: stroke, course: course, isRelay: isRelay) }

    /// True when a full set of 50-interval splits is stored for this swim.
    var hasSplits: Bool { SwimSplits.isComplete(splits, distance: distance, isRelay: isRelay) }
}

// MARK: - Backward-compatible decoding
//
// Synthesized Codable throws when a key is missing, even for properties that have
// default values. These custom decoders let older saved files (without `team` /
// `isRelay`, or with a non-optional `seconds`) load cleanly. Placing them in
// extensions preserves each struct's memberwise initializer.

extension Meet {
    enum CodingKeys: String, CodingKey {
        case id, name, team, location, date, endDate, course, hasPrelimsFinals
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try container.decode(String.self, forKey: .name)
        team = try container.decodeIfPresent(String.self, forKey: .team) ?? ""
        location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate) ?? date
        course = try container.decodeIfPresent(Course.self, forKey: .course) ?? .scy
        hasPrelimsFinals = try container.decodeIfPresent(Bool.self, forKey: .hasPrelimsFinals) ?? false
    }
}

extension SwimTime {
    enum CodingKeys: String, CodingKey {
        case id, distance, stroke, course, seconds, splits, date, meetID, isRelay, note, round
        case relayLeg, relayLegStroke, relayLegSeconds, isRelayLeadOff
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        distance = try container.decode(Int.self, forKey: .distance)
        stroke = try container.decode(Stroke.self, forKey: .stroke)
        course = try container.decode(Course.self, forKey: .course)
        seconds = try container.decodeIfPresent(Double.self, forKey: .seconds)
        splits = try container.decodeIfPresent([Double].self, forKey: .splits) ?? []
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        meetID = try container.decodeIfPresent(String.self, forKey: .meetID)
        isRelay = try container.decodeIfPresent(Bool.self, forKey: .isRelay) ?? false
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        round = try container.decodeIfPresent(MeetRound.self, forKey: .round)
        relayLeg = try container.decodeIfPresent(Int.self, forKey: .relayLeg)
        relayLegStroke = try container.decodeIfPresent(Stroke.self, forKey: .relayLegStroke)
        relayLegSeconds = try container.decodeIfPresent(Double.self, forKey: .relayLegSeconds)
        isRelayLeadOff = try container.decodeIfPresent(Bool.self, forKey: .isRelayLeadOff) ?? false
    }
}

/// A pending or composed event result (used while creating a meet, and as the
/// save payload from `ResultEntryView`).
struct ResultDraft: Identifiable {
    var id: String = UUID().uuidString
    var event: SwimEvent
    var seconds: Double?
    var note: String
    var splits: [Double] = []
    var round: MeetRound? = nil
    var relayLeg: Int? = nil
    var relayLegStroke: Stroke? = nil
    var relayLegSeconds: Double? = nil
    var isRelayLeadOff: Bool = false
}

// MARK: - Splits

/// Helpers for 50-interval split storage and aggregated display (50s, 100s, …).
enum SwimSplits {
    /// How many 50s make up an individual event. Relays and odd distances return 0.
    static func fiftyCount(distance: Int, isRelay: Bool = false) -> Int {
        guard !isRelay, distance >= 100, distance % 50 == 0 else { return 0 }
        return distance / 50
    }

    static func supportsSplits(distance: Int, isRelay: Bool = false) -> Bool {
        fiftyCount(distance: distance, isRelay: isRelay) >= 2
    }

    static func isComplete(_ splits: [Double], distance: Int, isRelay: Bool = false) -> Bool {
        let expected = fiftyCount(distance: distance, isRelay: isRelay)
        return expected >= 2
            && splits.count == expected
            && splits.allSatisfy { $0 > 0 }
    }

    /// Segment lengths for the view control (e.g. 200 → 50, 100).
    static func displayModes(distance: Int, isRelay: Bool = false) -> [Int] {
        guard supportsSplits(distance: distance, isRelay: isRelay) else { return [] }
        let preferred = [50, 100, 200, 500]
        var modes = preferred.filter { $0 < distance && distance % $0 == 0 }
        let half = distance / 2
        if half >= 50, half % 50 == 0, half < distance, !modes.contains(half) {
            modes.append(half)
            modes.sort()
        }
        return modes
    }

    /// Collapse 50-interval splits into larger equal segments (e.g. 4×50 → 2×100).
    static func aggregate(_ splits: [Double], segmentDistance: Int) -> [Double]? {
        guard segmentDistance >= 50, segmentDistance % 50 == 0 else { return nil }
        let group = segmentDistance / 50
        guard group > 0, !splits.isEmpty, splits.count % group == 0 else { return nil }
        return stride(from: 0, to: splits.count, by: group).map { index in
            splits[index..<(index + group)].reduce(0, +)
        }
    }

    static func rangeLabel(index: Int, segmentDistance: Int, unit: String) -> String {
        let start = index * segmentDistance
        let end = start + segmentDistance
        return "\(start)–\(end) \(unit)"
    }

    static func modeLabel(_ segmentDistance: Int) -> String {
        "\(segmentDistance)s"
    }

    /// Persist only a complete set of 50 splits; otherwise store nothing.
    static func normalized(_ splits: [Double], distance: Int, isRelay: Bool = false) -> [Double] {
        isComplete(splits, distance: distance, isRelay: isRelay) ? splits : []
    }
}

// MARK: - Scoring (World Aquatics points)

/// World Aquatics ("FINA") point scoring: `P = 1000 * (base / time)^3`.
/// Matching the base time is 1000 points; faster is more. Points are truncated
/// to an integer, exactly as World Aquatics defines them. Base times are
/// gender-specific (see `Gender` / `BaseTimes`).
enum SwimScore {
    static func points(seconds: Double, base: Double) -> Int? {
        guard seconds > 0, base > 0 else { return nil }
        let value = 1000.0 * pow(base / seconds, 3)
        guard value.isFinite, value >= 0 else { return nil }
        return Int(value)
    }

    /// Swim time for a World Aquatics score: `base ÷ ∛(points ÷ 1000)`.
    static func seconds(points: Int, base: Double) -> Double? {
        guard points > 0, base > 0 else { return nil }
        let seconds = base / pow(Double(points) / 1000.0, 1.0 / 3.0)
        guard seconds.isFinite, seconds > 0 else { return nil }
        return seconds
    }
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
struct OverallScore: Hashable {
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

/// One point on the Score tab progression chart (calendar year or season month).
struct ProgressionScore: Identifiable {
    let periodStart: Date
    let value: Int
    /// Short axis label, e.g. "2025" or "Aug '25".
    let label: String

    var id: TimeInterval { periodStart.timeIntervalSinceReferenceDate }
}

/// Overall score scoped to a single stroke, for the Home radar chart.
struct StrokeScore: Identifiable, Hashable {
    let stroke: Stroke
    let overall: OverallScore

    var id: String { stroke.id }
    var value: Int { overall.value }
    var isEmpty: Bool { overall.isEmpty }
}

// MARK: - Goals

/// Target clock times for one individual event. All-time and meet goals are
/// independent; either may be unset.
struct EventGoals: Identifiable, Codable, Hashable {
    var distance: Int
    var stroke: Stroke
    var course: Course
    /// Career target time for this event.
    var allTimeSeconds: Double? = nil
    /// Generic meet target; progress uses best time in the current Aug–Jul season.
    var meetSeconds: Double? = nil

    var id: String { event.id }
    var event: SwimEvent { SwimEvent(distance: distance, stroke: stroke, course: course) }

    var hasAnyGoal: Bool { allTimeSeconds != nil || meetSeconds != nil }

    init(event: SwimEvent, allTimeSeconds: Double? = nil, meetSeconds: Double? = nil) {
        distance = event.distance
        stroke = event.stroke
        course = event.course
        self.allTimeSeconds = allTimeSeconds
        self.meetSeconds = meetSeconds
    }
}

/// School-year season window used for meet-goal progress: August 1 – July 31.
enum SwimSeason {
    /// Inclusive start and exclusive end of the Aug–Jul season containing `date`.
    static func range(containing date: Date = Date(), calendar: Calendar = .current) -> (start: Date, end: Date) {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let startYear = month >= 8 ? year : year - 1
        let start = calendar.date(from: DateComponents(year: startYear, month: 8, day: 1))!
        let end = calendar.date(from: DateComponents(year: startYear + 1, month: 8, day: 1))!
        return (start, end)
    }

    /// Short label for the current season, e.g. "2025–26".
    static func label(containing date: Date = Date(), calendar: Calendar = .current) -> String {
        let startYear = calendar.component(.year, from: range(containing: date, calendar: calendar).start)
        let endShort = String(format: "%02d", (startYear + 1) % 100)
        return "\(startYear)–\(endShort)"
    }

    static func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let bounds = range(containing: Date(), calendar: calendar)
        return date >= bounds.start && date < bounds.end
    }
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

    /// Per-event overrides of the baked-in 1000-point base times.
    /// Keyed by `BaseTimes.key(gender:course:stroke:distance:)`. Empty means use defaults.
    var baseTimeOverrides: [String: Double] = [:] {
        didSet { saveBaseTimes() }
    }

    /// Profile preferences: scoring gender, default course, Times sort.
    var settings: AppSettings = AppSettings() {
        didSet { saveSettings() }
    }

    /// Per-event all-time and meet goal times.
    var goals: [EventGoals] = [] {
        didSet { saveGoals() }
    }

    @ObservationIgnored private let meetsURL: URL
    @ObservationIgnored private let timesURL: URL
    @ObservationIgnored private let baseTimesURL: URL
    @ObservationIgnored private let settingsURL: URL
    @ObservationIgnored private let goalsURL: URL
    @ObservationIgnored private var isLoading = false

    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        meetsURL = dir.appendingPathComponent("swimtracker.v1.json")
        timesURL = dir.appendingPathComponent("swimtracker.times.v1.json")
        baseTimesURL = dir.appendingPathComponent("swimtracker.basetimes.v1.json")
        settingsURL = dir.appendingPathComponent("swimtracker.settings.v1.json")
        goalsURL = dir.appendingPathComponent("swimtracker.goals.v1.json")
        load()
    }

    // MARK: Meets

    /// Meets sorted newest-first.
    var meetsByDate: [Meet] {
        meets.sorted { $0.date > $1.date }
    }

    /// Meets that start today or later, soonest first.
    func upcomingMeets() -> [Meet] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return meets
            .filter { calendar.startOfDay(for: $0.date) >= today }
            .sorted { $0.date < $1.date }
    }

    /// Past meets (started before today), newest first — for the Home page.
    func recentMeets(limit: Int = 5) -> [Meet] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let past = meets
            .filter { calendar.startOfDay(for: $0.date) < today }
            .sorted { $0.date > $1.date }
        return Array(past.prefix(limit))
    }

    /// Whole days from today until the meet's start date (0 = today).
    func daysUntilMeet(_ meet: Meet) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: meet.date)
        return calendar.dateComponents([.day], from: today, to: start).day ?? 0
    }

    /// Creates a meet and returns its id so callers can immediately attach results.
    @discardableResult
    func addMeet(
        name: String,
        team: String,
        location: String,
        date: Date,
        endDate: Date,
        course: Course,
        hasPrelimsFinals: Bool = false
    ) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let start = date
        let end = max(endDate, start)
        let meet = Meet(name: trimmed,
                        team: team.trimmingCharacters(in: .whitespacesAndNewlines),
                        location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                        date: start,
                        endDate: end,
                        course: course,
                        hasPrelimsFinals: hasPrelimsFinals)
        meets.append(meet)
        return meet.id
    }

    func updateMeet(
        id: String,
        name: String,
        team: String,
        location: String,
        date: Date,
        endDate: Date,
        course: Course,
        hasPrelimsFinals: Bool
    ) {
        guard let index = meets.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let start = date
        let end = max(endDate, start)
        let dateChanged = meets[index].date != start
        let courseChanged = meets[index].course != course
        let prelimsFinalsCleared = meets[index].hasPrelimsFinals && !hasPrelimsFinals
        meets[index].name = trimmed
        meets[index].team = team.trimmingCharacters(in: .whitespacesAndNewlines)
        meets[index].location = location.trimmingCharacters(in: .whitespacesAndNewlines)
        meets[index].date = start
        meets[index].endDate = end
        meets[index].course = course
        meets[index].hasPrelimsFinals = hasPrelimsFinals

        // Keep results in sync with the meet date / course / round mode.
        if dateChanged || courseChanged || prelimsFinalsCleared {
            for i in times.indices where times[i].meetID == id {
                if dateChanged { times[i].date = start }
                if courseChanged { times[i].course = course }
                if prelimsFinalsCleared { times[i].round = nil }
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

    /// Fastest recorded time for an event in the current Aug–Jul season.
    func bestTimeInCurrentSeason(for event: SwimEvent) -> SwimTime? {
        recordedTimes(for: event)
            .filter { SwimSeason.contains($0.date) }
            .min {
                ($0.seconds ?? .greatestFiniteMagnitude) < ($1.seconds ?? .greatestFiniteMagnitude)
            }
    }

    // MARK: Goals

    /// Goals that have at least one target set, heat-sheet order.
    var eventsWithGoals: [EventGoals] {
        goals.filter(\.hasAnyGoal).sorted { $0.event < $1.event }
    }

    func goals(for event: SwimEvent) -> EventGoals? {
        goals.first { $0.event == event && $0.hasAnyGoal }
    }

    /// Sets or clears goals for an event. Clearing both removes the entry.
    func setGoals(for event: SwimEvent, allTimeSeconds: Double?, meetSeconds: Double?) {
        let allTime = normalized(allTimeSeconds)
        let meet = normalized(meetSeconds)
        var next = goals
        next.removeAll { $0.event == event }
        if allTime != nil || meet != nil {
            next.append(EventGoals(event: event, allTimeSeconds: allTime, meetSeconds: meet))
        }
        goals = next
    }

    func clearGoals(for event: SwimEvent) {
        setGoals(for: event, allTimeSeconds: nil, meetSeconds: nil)
    }

    /// Seconds above goal (positive = still to drop). Nil when there is no comparison swim.
    func goalGap(goalSeconds: Double, bestSeconds: Double?) -> Double? {
        guard let bestSeconds else { return nil }
        return bestSeconds - goalSeconds
    }

    /// True when a comparison swim has matched or beaten the goal.
    func isGoalMet(goalSeconds: Double, bestSeconds: Double?) -> Bool {
        guard let bestSeconds else { return false }
        return bestSeconds <= goalSeconds
    }

    /// World Aquatics points for a single recorded swim, using the profile gender
    /// from Settings. Relays and not-yet-timed entries have no score.
    func score(for time: SwimTime) -> Int? {
        guard !time.isRelay, let seconds = time.seconds,
              let base = baseSeconds(for: time.event)
        else { return nil }
        return SwimScore.points(seconds: seconds, base: base)
    }

    /// Effective 1000-point base time for an event (override, else baked-in default).
    /// Defaults to the profile gender from Settings when `gender` is omitted.
    func baseSeconds(for event: SwimEvent, gender: Gender? = nil) -> Double? {
        let resolved = gender ?? settings.gender
        let key = BaseTimes.key(gender: resolved, for: event)
        if let override = baseTimeOverrides[key] {
            return override > 0 ? override : nil
        }
        return BaseTimes.defaultSeconds(for: event, gender: resolved)
    }

    /// Whether this event's base time has been customized on device.
    func hasCustomBaseTime(for event: SwimEvent, gender: Gender? = nil) -> Bool {
        let resolved = gender ?? settings.gender
        return baseTimeOverrides[BaseTimes.key(gender: resolved, for: event)] != nil
    }

    /// Update one event's base time. Matching the baked-in default clears the override.
    func setBaseTime(for event: SwimEvent, gender: Gender? = nil, seconds: Double) {
        let resolved = gender ?? settings.gender
        let key = BaseTimes.key(gender: resolved, for: event)
        let rounded = (seconds * 100).rounded() / 100
        var next = baseTimeOverrides
        if let factory = BaseTimes.defaultSeconds(for: event, gender: resolved), abs(factory - rounded) < 0.005 {
            next.removeValue(forKey: key)
        } else if rounded > 0 {
            next[key] = rounded
        } else {
            // Explicit 0 disables scoring for this event.
            next[key] = 0
        }
        baseTimeOverrides = next
    }

    func clearBaseTimeOverride(for event: SwimEvent, gender: Gender? = nil) {
        let resolved = gender ?? settings.gender
        var next = baseTimeOverrides
        next.removeValue(forKey: BaseTimes.key(gender: resolved, for: event))
        baseTimeOverrides = next
    }

    func resetAllBaseTimes() {
        baseTimeOverrides = [:]
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

    /// Overall for all times, or only swims that count toward a specific team.
    func overall(team: String? = nil) -> OverallScore {
        guard let team else { return allTimesOverall }
        let scoped = times.filter { teamKey(for: $0) == team }
        return overallScore(for: scoped)
    }

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
    /// for all times. Each year uses only that year's swims (best times from other
    /// years never carry over).
    func yearlyOveralls(team: String? = nil) -> [ProgressionScore] {
        let scored = scoredTimes(team: team)
        let calendar = Calendar.current
        let byYear = Dictionary(grouping: scored) { calendar.component(.year, from: $0.date) }
        return byYear
            .compactMap { year, group -> ProgressionScore? in
                let overall = overallScore(for: group)
                guard !overall.isEmpty else { return nil }
                guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else {
                    return nil
                }
                return ProgressionScore(periodStart: start, value: overall.value, label: String(year))
            }
            .sorted { $0.periodStart < $1.periodStart }
    }

    /// Monthly season-to-date overalls for the progression graph. A swimming season
    /// starts each August; each point is the overall from that season's August
    /// through the end of the month, so the chart resets to 0 in August.
    func seasonMonthlyOveralls(team: String? = nil) -> [ProgressionScore] {
        let scored = scoredTimes(team: team)
        guard let earliest = scored.map(\.date).min() else { return [] }

        let calendar = Calendar.current
        let latestSwim = scored.map(\.date).max() ?? earliest
        let endMonth = max(monthStart(of: latestSwim, calendar: calendar),
                           monthStart(of: Date(), calendar: calendar))

        // Walk every month from the first swim through now so August resets stay visible.
        var cursor = monthStart(of: earliest, calendar: calendar)
        var points: [ProgressionScore] = []
        let labelFormatter = DateFormatter()
        labelFormatter.dateFormat = "MMM ''yy"

        while cursor <= endMonth {
            let seasonBegin = Self.seasonStart(containing: cursor, calendar: calendar)
            let monthEnd = endOfMonth(containing: cursor, calendar: calendar)
            let window = scored.filter { $0.date >= seasonBegin && $0.date <= monthEnd }
            let value = overallScore(for: window).value
            points.append(
                ProgressionScore(
                    periodStart: cursor,
                    value: value,
                    label: labelFormatter.string(from: cursor)
                )
            )
            guard let next = calendar.date(byAdding: .month, to: cursor) else { break }
            cursor = next
        }
        return points
    }

    /// Non-relay timed swims, optionally scoped to a team.
    private func scoredTimes(team: String?) -> [SwimTime] {
        var scored = times.filter { !$0.isRelay && $0.seconds != nil }
        if let team {
            scored = scored.filter { teamKey(for: $0) == team }
        }
        return scored
    }

    /// August 1 of the swimming season that contains `date` (season runs Aug–Jul).
    static func seasonStart(containing date: Date, calendar: Calendar = .current) -> Date {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let seasonYear = month >= 8 ? year : year - 1
        return calendar.date(from: DateComponents(year: seasonYear, month: 8, day: 1))
            ?? date
    }

    private func monthStart(of date: Date, calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private func endOfMonth(containing date: Date, calendar: Calendar) -> Date {
        let start = monthStart(of: date, calendar: calendar)
        guard let nextMonth = calendar.date(byAdding: .month, to: start) else { return date }
        return nextMonth.addingTimeInterval(-1)
    }

    /// Overall score for every stroke (Free / Back / Breast / Fly / IM), heat-sheet
    /// order. Strokes with no scored swims still appear with an empty overall (0)
    /// so the Home radar always has five axes.
    var strokeOveralls: [StrokeScore] {
        Stroke.allCases.map { stroke in
            let scoped = times.filter { !$0.isRelay && $0.stroke == stroke && $0.seconds != nil }
            return StrokeScore(stroke: stroke, overall: overallScore(for: scoped))
        }
    }

    func addTime(
        distance: Int,
        stroke: Stroke,
        course: Course,
        seconds: Double?,
        date: Date,
        meetID: String?,
        isRelay: Bool = false,
        note: String,
        splits: [Double] = [],
        round: MeetRound? = nil,
        relayLeg: Int? = nil,
        relayLegStroke: Stroke? = nil,
        relayLegSeconds: Double? = nil,
        isRelayLeadOff: Bool = false
    ) {
        let resolvedRound = resolvedRound(round, meetID: meetID)
        let time = SwimTime(distance: distance,
                            stroke: stroke,
                            course: course,
                            seconds: normalized(seconds),
                            splits: SwimSplits.normalized(splits, distance: distance, isRelay: isRelay),
                            date: date,
                            meetID: meetID,
                            isRelay: isRelay,
                            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                            round: resolvedRound,
                            relayLeg: isRelay ? relayLeg : nil,
                            relayLegStroke: isRelay ? relayLegStroke : nil,
                            relayLegSeconds: isRelay ? normalized(relayLegSeconds) : nil,
                            isRelayLeadOff: isRelay && isRelayLeadOff)
        times.append(time)
    }

    func updateTime(
        id: String,
        distance: Int,
        stroke: Stroke,
        course: Course,
        seconds: Double?,
        date: Date,
        meetID: String?,
        isRelay: Bool,
        note: String,
        splits: [Double] = [],
        round: MeetRound? = nil,
        relayLeg: Int? = nil,
        relayLegStroke: Stroke? = nil,
        relayLegSeconds: Double? = nil,
        isRelayLeadOff: Bool = false
    ) {
        guard let index = times.firstIndex(where: { $0.id == id }) else { return }
        times[index].distance = distance
        times[index].stroke = stroke
        times[index].course = course
        times[index].seconds = normalized(seconds)
        times[index].splits = SwimSplits.normalized(splits, distance: distance, isRelay: isRelay)
        times[index].date = date
        times[index].meetID = meetID
        times[index].isRelay = isRelay
        times[index].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        times[index].round = resolvedRound(round, meetID: meetID)
        times[index].relayLeg = isRelay ? relayLeg : nil
        times[index].relayLegStroke = isRelay ? relayLegStroke : nil
        times[index].relayLegSeconds = isRelay ? normalized(relayLegSeconds) : nil
        times[index].isRelayLeadOff = isRelay && isRelayLeadOff
    }

    /// Round is only kept when the linked meet is a prelims/finals meet.
    private func resolvedRound(_ round: MeetRound?, meetID: String?) -> MeetRound? {
        guard let meetID, let meet = meet(id: meetID), meet.hasPrelimsFinals else { return nil }
        return round
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
    /// Prelims sort before finals when the same event appears twice.
    func results(forMeet meetID: String) -> [SwimTime] {
        times.filter { $0.meetID == meetID }.sorted {
            if $0.event != $1.event { return $0.event < $1.event }
            return ($0.round?.order ?? 0) < ($1.round?.order ?? 0)
        }
    }

    /// A recorded event (with or without a time) attached to a meet.
    func addResult(toMeet meetID: String, draft: ResultDraft) {
        let meet = meet(id: meetID)
        let date = meet?.date ?? Date()
        let course = meet?.course ?? draft.event.course
        let event = SwimEvent(distance: draft.event.distance, stroke: draft.event.stroke, course: course, isRelay: draft.event.isRelay)
        addTime(distance: event.distance,
                stroke: event.stroke,
                course: event.course,
                seconds: draft.seconds,
                date: date,
                meetID: meetID,
                isRelay: event.isRelay,
                note: draft.note,
                splits: draft.splits,
                round: draft.round,
                relayLeg: draft.relayLeg,
                relayLegStroke: draft.relayLegStroke,
                relayLegSeconds: draft.relayLegSeconds,
                isRelayLeadOff: draft.isRelayLeadOff)
    }

    // MARK: Persistence

    private struct TimesData: Codable {
        var times: [SwimTime] = []

        enum CodingKeys: String, CodingKey { case times, gender }

        init(times: [SwimTime]) { self.times = times }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            times = try container.decodeIfPresent([SwimTime].self, forKey: .times) ?? []
            // Older files stored a gender toggle; profile gender now lives in settings.
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(times, forKey: .times)
        }
    }

    private struct BaseTimesData: Codable {
        var overrides: [String: Double] = [:]
    }

    private struct GoalsData: Codable {
        var goals: [EventGoals] = []
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
            times = decoded.times
        }

        if let data = try? Data(contentsOf: baseTimesURL),
           let decoded = try? JSONDecoder.swimTracker.decode(BaseTimesData.self, from: data) {
            baseTimeOverrides = decoded.overrides
        }

        if let data = try? Data(contentsOf: settingsURL),
           let decoded = try? JSONDecoder.swimTracker.decode(AppSettings.self, from: data) {
            settings = decoded
        }

        if let data = try? Data(contentsOf: goalsURL),
           let decoded = try? JSONDecoder.swimTracker.decode(GoalsData.self, from: data) {
            goals = decoded.goals
        }

        publishGoalsWidgetSnapshot()
    }

    private func saveMeets() {
        guard !isLoading else { return }
        guard let data = try? JSONEncoder.swimTracker.encode(meets) else { return }
        try? data.write(to: meetsURL, options: [.atomic])
    }

    private func saveTimes() {
        guard !isLoading else { return }
        let payload = TimesData(times: times)
        guard let data = try? JSONEncoder.swimTracker.encode(payload) else { return }
        try? data.write(to: timesURL, options: [.atomic])
        publishGoalsWidgetSnapshot()
    }

    private func saveBaseTimes() {
        guard !isLoading else { return }
        let payload = BaseTimesData(overrides: baseTimeOverrides)
        guard let data = try? JSONEncoder.swimTracker.encode(payload) else { return }
        try? data.write(to: baseTimesURL, options: [.atomic])
    }

    private func saveSettings() {
        guard !isLoading else { return }
        guard let data = try? JSONEncoder.swimTracker.encode(settings) else { return }
        try? data.write(to: settingsURL, options: [.atomic])
    }

    private func saveGoals() {
        guard !isLoading else { return }
        let payload = GoalsData(goals: goals)
        guard let data = try? JSONEncoder.swimTracker.encode(payload) else { return }
        try? data.write(to: goalsURL, options: [.atomic])
        publishGoalsWidgetSnapshot()
    }

    /// Writes a compact goals payload for the Home Screen widget and asks WidgetKit to refresh.
    func publishGoalsWidgetSnapshot() {
        let entries = eventsWithGoals.map { entry in
            GoalsWidgetEntry(
                id: entry.id,
                eventName: entry.event.name,
                course: entry.course.rawValue,
                allTimeGoal: entry.allTimeSeconds,
                allTimeBest: bestTime(for: entry.event)?.seconds,
                meetGoal: entry.meetSeconds,
                seasonBest: bestTimeInCurrentSeason(for: entry.event)?.seconds
            )
        }
        GoalsWidgetStore.save(
            GoalsWidgetSnapshot(
                updatedAt: Date(),
                seasonLabel: SwimSeason.label(),
                entries: entries
            )
        )
        WidgetBridge.reloadGoals()
    }

    // MARK: Backup (import / export)

    /// Bundles meets, times, base-time overrides, settings, and goals into one JSON file.
    func exportBackup() throws -> Data {
        let backup = SwimTrackerBackup(
            formatVersion: SwimTrackerBackup.currentFormatVersion,
            exportedAt: Date(),
            meets: meets,
            times: times,
            baseTimeOverrides: baseTimeOverrides,
            settings: settings,
            goals: goals
        )
        return try JSONEncoder.swimTrackerPretty.encode(backup)
    }

    /// Suggested filename for a newly exported backup, e.g. `SwimTracker-Backup-2026-07-29.json`.
    var backupExportFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "SwimTracker-Backup-\(formatter.string(from: Date())).json"
    }

    /// Replaces all on-device data with the contents of a backup file.
    func importBackup(from data: Data) throws {
        let backup = try JSONDecoder.swimTracker.decode(SwimTrackerBackup.self, from: data)
        guard backup.formatVersion == SwimTrackerBackup.currentFormatVersion else {
            throw BackupError.unsupportedVersion(backup.formatVersion)
        }

        isLoading = true
        meets = backup.meets
        times = backup.times
        baseTimeOverrides = backup.baseTimeOverrides
        settings = backup.settings
        goals = backup.goals
        isLoading = false

        saveMeets()
        saveTimes()
        saveBaseTimes()
        saveSettings()
        saveGoals()
    }
}

/// Single-file backup of everything SwimTracker stores locally.
struct SwimTrackerBackup: Codable {
    static let currentFormatVersion = 1

    var formatVersion: Int
    var exportedAt: Date
    var meets: [Meet]
    var times: [SwimTime]
    var baseTimeOverrides: [String: Double]
    var settings: AppSettings
    var goals: [EventGoals]

    enum CodingKeys: String, CodingKey {
        case formatVersion, exportedAt, meets, times, baseTimeOverrides, settings, goals
    }

    init(
        formatVersion: Int,
        exportedAt: Date,
        meets: [Meet],
        times: [SwimTime],
        baseTimeOverrides: [String: Double],
        settings: AppSettings,
        goals: [EventGoals] = []
    ) {
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.meets = meets
        self.times = times
        self.baseTimeOverrides = baseTimeOverrides
        self.settings = settings
        self.goals = goals
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try container.decode(Int.self, forKey: .formatVersion)
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        meets = try container.decode([Meet].self, forKey: .meets)
        times = try container.decode([SwimTime].self, forKey: .times)
        baseTimeOverrides = try container.decodeIfPresent([String: Double].self, forKey: .baseTimeOverrides) ?? [:]
        settings = try container.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
        goals = try container.decodeIfPresent([EventGoals].self, forKey: .goals) ?? []
    }
}

enum BackupError: LocalizedError {
    case unsupportedVersion(Int)
    case unreadableFile

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return "This backup format (v\(version)) is not supported by this version of SwimTracker."
        case .unreadableFile:
            return "Could not read that file. Choose a SwimTracker backup JSON export."
        }
    }
}

private extension JSONEncoder {
    static let swimTracker: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let swimTrackerPretty: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
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
