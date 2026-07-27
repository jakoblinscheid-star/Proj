import Foundation

/// Men's 1000-point base times used for World Aquatics scoring.
///
/// - LCM / SCM: World Aquatics base times (world records).
/// - SCY: U.S. Open records (fastest yards time in the U.S.).
///
/// Baked-in defaults live here (one event per line). Prefer updating a single
/// time in the app via **Base Times** — that writes an on-device override and
/// does not require rebuilding. Change this file only when you want a new
/// factory default for a fresh install.
enum BaseTimes {
    /// Stable key for overrides / lookups.
    static func key(course: Course, stroke: Stroke, distance: Int) -> String {
        "\(course.rawValue)|\(stroke.rawValue)|\(distance)"
    }

    static func key(for event: SwimEvent) -> String {
        key(course: event.course, stroke: event.stroke, distance: event.distance)
    }

    /// Baked-in default in seconds, or nil when unset / zero (event loggable, unscored).
    static func defaultSeconds(for event: SwimEvent) -> Double? {
        guard let seconds = defaultTable[key(for: event)], seconds > 0 else { return nil }
        return seconds
    }

    /// The catalog of individual events that can be scored for a course, in heat-sheet order.
    static func events(for course: Course) -> [SwimEvent] {
        defaults
            .filter { $0.course == course }
            .map { SwimEvent(distance: $0.distance, stroke: $0.stroke, course: $0.course) }
            .sorted(by: <)
    }

    /// Every individual event that has a default row (including unscored zeros).
    static var allEvents: [SwimEvent] {
        defaults
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

    // MARK: Defaults (men)

    private struct Entry {
        let course: Course
        let stroke: Stroke
        let distance: Int
        let seconds: Double
    }

    private static let defaultTable: [String: Double] = {
        var table: [String: Double] = [:]
        for entry in defaults {
            table[key(course: entry.course, stroke: entry.stroke, distance: entry.distance)] = entry.seconds
        }
        return table
    }()

    /// One event per line. Seconds as a Double (1:42.00 → 102.00).
    private static let defaults: [Entry] = [
        // MARK: LCM — World Aquatics
        Entry(course: .lcm, stroke: .freestyle, distance: 50, seconds: 20.91),
        Entry(course: .lcm, stroke: .freestyle, distance: 100, seconds: 46.40),
        Entry(course: .lcm, stroke: .freestyle, distance: 200, seconds: 102.00), // 1:42.00
        Entry(course: .lcm, stroke: .freestyle, distance: 400, seconds: 219.96), // 3:39.96
        Entry(course: .lcm, stroke: .freestyle, distance: 800, seconds: 452.12), // 7:32.12
        Entry(course: .lcm, stroke: .freestyle, distance: 1500, seconds: 870.67), // 14:30.67
        Entry(course: .lcm, stroke: .backstroke, distance: 50, seconds: 23.55),
        Entry(course: .lcm, stroke: .backstroke, distance: 100, seconds: 51.60),
        Entry(course: .lcm, stroke: .backstroke, distance: 200, seconds: 111.92), // 1:51.92
        Entry(course: .lcm, stroke: .breaststroke, distance: 50, seconds: 25.95),
        Entry(course: .lcm, stroke: .breaststroke, distance: 100, seconds: 56.88),
        Entry(course: .lcm, stroke: .breaststroke, distance: 200, seconds: 125.48), // 2:05.48
        Entry(course: .lcm, stroke: .butterfly, distance: 50, seconds: 22.27),
        Entry(course: .lcm, stroke: .butterfly, distance: 100, seconds: 49.45),
        Entry(course: .lcm, stroke: .butterfly, distance: 200, seconds: 110.34), // 1:50.34
        Entry(course: .lcm, stroke: .medley, distance: 200, seconds: 112.69), // 1:52.69
        Entry(course: .lcm, stroke: .medley, distance: 400, seconds: 242.50), // 4:02.50

        // MARK: SCM — World Aquatics
        Entry(course: .scm, stroke: .freestyle, distance: 50, seconds: 19.90),
        Entry(course: .scm, stroke: .freestyle, distance: 100, seconds: 44.84),
        Entry(course: .scm, stroke: .freestyle, distance: 200, seconds: 98.61), // 1:38.61
        Entry(course: .scm, stroke: .freestyle, distance: 400, seconds: 212.25), // 3:32.25
        Entry(course: .scm, stroke: .freestyle, distance: 800, seconds: 440.46), // 7:20.46
        Entry(course: .scm, stroke: .freestyle, distance: 1500, seconds: 846.88), // 14:06.88
        Entry(course: .scm, stroke: .backstroke, distance: 50, seconds: 22.11),
        Entry(course: .scm, stroke: .backstroke, distance: 100, seconds: 48.33),
        Entry(course: .scm, stroke: .backstroke, distance: 200, seconds: 105.63), // 1:45.63
        Entry(course: .scm, stroke: .breaststroke, distance: 50, seconds: 24.95),
        Entry(course: .scm, stroke: .breaststroke, distance: 100, seconds: 55.28),
        Entry(course: .scm, stroke: .breaststroke, distance: 200, seconds: 120.16), // 2:00.16
        Entry(course: .scm, stroke: .butterfly, distance: 50, seconds: 21.32),
        Entry(course: .scm, stroke: .butterfly, distance: 100, seconds: 47.71),
        Entry(course: .scm, stroke: .butterfly, distance: 200, seconds: 106.85), // 1:46.85
        Entry(course: .scm, stroke: .medley, distance: 100, seconds: 49.28),
        Entry(course: .scm, stroke: .medley, distance: 200, seconds: 108.88), // 1:48.88
        Entry(course: .scm, stroke: .medley, distance: 400, seconds: 234.81), // 3:54.81

        // MARK: SCY — U.S. Open
        Entry(course: .scy, stroke: .freestyle, distance: 50, seconds: 17.63),
        Entry(course: .scy, stroke: .freestyle, distance: 100, seconds: 39.83),
        Entry(course: .scy, stroke: .freestyle, distance: 200, seconds: 88.33), // 1:28.33
        Entry(course: .scy, stroke: .freestyle, distance: 500, seconds: 242.31), // 4:02.31
        Entry(course: .scy, stroke: .freestyle, distance: 1000, seconds: 512.83), // 8:32.83
        Entry(course: .scy, stroke: .freestyle, distance: 1650, seconds: 850.03), // 14:10.03
        Entry(course: .scy, stroke: .backstroke, distance: 100, seconds: 42.61),
        Entry(course: .scy, stroke: .backstroke, distance: 200, seconds: 94.13), // 1:34.13
        Entry(course: .scy, stroke: .breaststroke, distance: 100, seconds: 49.51),
        Entry(course: .scy, stroke: .breaststroke, distance: 200, seconds: 106.35), // 1:46.35
        Entry(course: .scy, stroke: .butterfly, distance: 100, seconds: 42.49),
        Entry(course: .scy, stroke: .butterfly, distance: 200, seconds: 96.41), // 1:36.41
        Entry(course: .scy, stroke: .medley, distance: 200, seconds: 96.34), // 1:36.34
        Entry(course: .scy, stroke: .medley, distance: 400, seconds: 208.82), // 3:28.82

        // SCY — no official U.S. Open; reference times (0 = loggable but unscored)
        Entry(course: .scy, stroke: .backstroke, distance: 50, seconds: 20.07),
        Entry(course: .scy, stroke: .breaststroke, distance: 50, seconds: 22.96),
        Entry(course: .scy, stroke: .butterfly, distance: 50, seconds: 19.90),
        Entry(course: .scy, stroke: .medley, distance: 100, seconds: 46.33), // Shaine Casas
    ]
}
