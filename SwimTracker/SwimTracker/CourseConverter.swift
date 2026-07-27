import Foundation

/// A convertible event that may use different nominal distances per course
/// (e.g. 400 Free meters ↔ 500 Free yards).
struct ConverterEvent: Identifiable, Hashable {
    let stroke: Stroke
    /// Distance in meters courses (SCM / LCM).
    let meterDistance: Int
    /// Distance in yards (SCY).
    let yardDistance: Int

    var id: String { "\(stroke.rawValue)|\(meterDistance)|\(yardDistance)" }

    func distance(for course: Course) -> Int {
        course == .scy ? yardDistance : meterDistance
    }

    /// SwimSwam-style label, e.g. "100 Free" or "400/500 Free".
    var label: String {
        if meterDistance == yardDistance {
            return "\(meterDistance) \(stroke.rawValue)"
        }
        return "\(meterDistance)/\(yardDistance) \(stroke.rawValue)"
    }

    static let catalog: [ConverterEvent] = [
        .init(stroke: .butterfly, meterDistance: 50, yardDistance: 50),
        .init(stroke: .butterfly, meterDistance: 100, yardDistance: 100),
        .init(stroke: .butterfly, meterDistance: 200, yardDistance: 200),
        .init(stroke: .backstroke, meterDistance: 50, yardDistance: 50),
        .init(stroke: .backstroke, meterDistance: 100, yardDistance: 100),
        .init(stroke: .backstroke, meterDistance: 200, yardDistance: 200),
        .init(stroke: .breaststroke, meterDistance: 50, yardDistance: 50),
        .init(stroke: .breaststroke, meterDistance: 100, yardDistance: 100),
        .init(stroke: .breaststroke, meterDistance: 200, yardDistance: 200),
        .init(stroke: .freestyle, meterDistance: 50, yardDistance: 50),
        .init(stroke: .freestyle, meterDistance: 100, yardDistance: 100),
        .init(stroke: .freestyle, meterDistance: 200, yardDistance: 200),
        .init(stroke: .freestyle, meterDistance: 400, yardDistance: 500),
        .init(stroke: .freestyle, meterDistance: 800, yardDistance: 1000),
        .init(stroke: .freestyle, meterDistance: 1500, yardDistance: 1650),
        .init(stroke: .medley, meterDistance: 200, yardDistance: 200),
        .init(stroke: .medley, meterDistance: 400, yardDistance: 400),
    ]
}

/// Colorado Timing course conversion — the same model SwimSwam's classic converter uses.
/// Times are worked in hundredths; results are returned in seconds.
enum CourseConverter {
    /// Convert `seconds` from one course to another for the given event.
    /// Returns nil when courses match with no time, or the input is not positive.
    static func convert(seconds: Double, event: ConverterEvent, from: Course, to: Course) -> Double? {
        guard seconds > 0 else { return nil }
        if from == to { return seconds }

        let fromDistance = event.distance(for: from)
        let toDistance = event.distance(for: to)
        let hsecs = seconds * 100.0
        let factor = fFactor(from: from, to: to, fromDistance: fromDistance, toDistance: toDistance)
        let incre = fIncre(
            stroke: event.stroke,
            from: from,
            to: to,
            fromDistance: fromDistance,
            toDistance: toDistance
        )

        let result: Double
        switch (from, to) {
        case (.scy, .lcm), (.scy, .scm):
            result = hsecs * factor + incre
        case (.lcm, .scy), (.lcm, .scm):
            result = (hsecs - incre) / factor
        case (.scm, .scy):
            result = hsecs / factor
        case (.scm, .lcm):
            result = hsecs + incre
        default:
            return nil
        }

        guard result.isFinite, result > 0 else { return nil }
        // Round to the nearest hundredth, matching scoreboard display.
        return result.rounded() / 100.0
    }

    // MARK: Factors (USA Swimming / Colorado Timing)

    private static func fFactor(from: Course, to: Course, fromDistance: Int, toDistance: Int) -> Double {
        let yard: Int
        let meters: Int
        if from == .scy {
            yard = fromDistance
            meters = toDistance
        } else if to == .scy {
            yard = toDistance
            meters = fromDistance
        } else {
            // LCM ↔ SCM
            return 1.0
        }

        let involvesLCM = from == .lcm || to == .lcm
        if involvesLCM {
            if (meters == 400 && yard == 500) || (meters == 800 && yard == 1000) {
                return 0.8925
            }
            if meters == 1500 && yard == 1650 {
                return 1.02
            }
        }
        return 1.11
    }

    /// Increment in hundredths of a second.
    private static func fIncre(
        stroke: Stroke,
        from: Course,
        to: Course,
        fromDistance: Int,
        toDistance: Int
    ) -> Double {
        // SCY ↔ SCM: no turn increment.
        if (from == .scy && to == .scm) || (from == .scm && to == .scy) {
            return 0
        }

        let yard: Int
        let meters: Int
        if from == .scy {
            yard = fromDistance
            meters = toDistance
        } else if to == .scy {
            yard = toDistance
            meters = fromDistance
        } else {
            yard = 0
            meters = max(fromDistance, toDistance)
        }

        let involvesSCY = from == .scy || to == .scy
        let involvesLCM = from == .lcm || to == .lcm
        let involvesSCM = from == .scm || to == .scm

        // LCM ↔ SCY specials
        if involvesLCM && involvesSCY {
            if stroke == .medley && meters == 400 {
                return 640
            }
            // Non-medley distance events (> 200) use the factor only.
            if stroke != .medley && max(yard, meters) > 200 {
                return 0
            }
        }

        // LCM ↔ SCM distance freestyle turn increments
        if involvesLCM && involvesSCM && stroke == .freestyle {
            switch meters {
            case 400: return 640
            case 800: return 1280
            case 1500: return 2400
            default: break
            }
        }

        let unit = incre(for: stroke)
        let distance = involvesSCY ? (meters > 0 ? meters : yard) : meters
        switch distance {
        case 50: return unit
        case 100: return 2 * unit
        case 200: return 4 * unit
        case 400: return 8 * unit
        default: return 0
        }
    }

    /// Per-50 turn increment in hundredths.
    private static func incre(for stroke: Stroke) -> Double {
        switch stroke {
        case .butterfly: return 70
        case .backstroke: return 60
        case .breaststroke: return 100
        case .freestyle, .medley: return 80
        }
    }
}
