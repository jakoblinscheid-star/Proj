import Foundation

// MARK: - Mapped swim (ready for Store merge)

/// One Data Hub personal-best row mapped into SwimTracker field types.
struct DataHubMappedSwim: Identifiable, Hashable {
    var id: String {
        "\(Int(date.timeIntervalSince1970))|\(distance)|\(stroke.rawValue)|\(course.rawValue)|\(seconds)|\(meetName)"
    }
    var distance: Int
    var stroke: Stroke
    var course: Course
    var seconds: Double
    var date: Date
    var meetName: String
    var team: String
    var splits: [Double]
    var eventCode: String
}

struct DataHubMemberMatch: Identifiable, Hashable {
    var id: String { memberId }
    var memberId: String
    var fullName: String
    var clubName: String
    var lscCode: String
    var swimmerAge: Int?
}

struct DataHubImportSummary: Equatable {
    var importedTimes: Int
    var skippedExisting: Int
    var createdMeets: Int
    var reusedMeets: Int
}

enum DataHubImportError: LocalizedError {
    case invalidDeviceID
    case http(Int, String)
    case decoding
    case noMembers
    case emptyPull
    case mapping(String)

    var errorDescription: String? {
        switch self {
        case .invalidDeviceID:
            return "Could not build a Data Hub device id."
        case .http(let code, let body):
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Data Hub request failed (\(code))." : "Data Hub request failed (\(code)): \(trimmed)"
        case .decoding:
            return "Could not read Data Hub response."
        case .noMembers:
            return "No athletes matched that search."
        case .emptyPull:
            return "No personal bests came back for that athlete."
        case .mapping(let detail):
            return detail
        }
    }
}

// MARK: - Client

actor DataHubClient {
    static let shared = DataHubClient()

    private let timesAPI = URL(string: "https://times-api.usaswimming.org")!
    private let deviceID: String

    init() {
        self.deviceID = Self.makeDeviceID()
    }

    func searchMembers(name: String, isCurrent: Bool = true, lscCode: String? = nil) async throws -> [DataHubMemberMatch] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let body: [String: Any?] = [
            "name": trimmed,
            "isCurrent": isCurrent ? 1 : 0,
            "lscCode": lscCode?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            "orgCode": nil,
        ]
        let raw: [DataHubMemberDTO]
        do {
            raw = try await postJSON(
                path: "/swims/TimesSearch/GetMembersForFilters",
                body: body.compactMapValues { $0 }
            )
        } catch DataHubImportError.http(404, _) {
            return []
        }
        return raw.map {
            DataHubMemberMatch(
                memberId: $0.memberId,
                fullName: $0.fullName,
                clubName: $0.clubName ?? "",
                lscCode: $0.lscCode ?? "",
                swimmerAge: $0.swimmerAge
            )
        }
    }

    func getMember(memberId: String) async throws -> DataHubMemberMatch {
        let raw: DataHubMemberDTO = try await getJSON(path: "/swims/TimesSearch/GetMember/\(memberId)")
        return DataHubMemberMatch(
            memberId: raw.memberId,
            fullName: raw.fullName,
            clubName: raw.clubName ?? "",
            lscCode: raw.lscCode ?? "",
            swimmerAge: raw.swimmerAge
        )
    }

    /// Pulls personal bests only (anonymous Data Hub path). Not full meet history.
    func pullPersonalBests(memberId: String) async throws -> [DataHubMappedSwim] {
        let summary: [DataHubBestSummaryDTO]
        do {
            summary = try await getJSON(
                path: "/swims/TimesSearch/GetBestTimesForMember/\(memberId)"
            )
        } catch DataHubImportError.http(404, _) {
            return []
        }
        guard !summary.isEmpty else { return [] }

        var pairs = Set<DistanceStroke>()
        for row in summary {
            pairs.insert(DistanceStroke(distance: row.distance, stroke: row.strokeAbbreviation))
        }

        var mapped: [DataHubMappedSwim] = []
        mapped.reserveCapacity(pairs.count)
        for pair in pairs.sorted() {
            let rows: [DataHubBestDetailDTO]
            do {
                rows = try await postJSON(
                    path: "/swims/TimesSearch/BestTimes",
                    body: [
                        "memberId": memberId,
                        "distance": pair.distance,
                        "strokeAbbreviation": pair.stroke,
                    ]
                )
            } catch DataHubImportError.http(404, _) {
                continue
            }
            for row in rows {
                if let swim = DataHubMapping.mapDetail(row) {
                    mapped.append(swim)
                }
            }
        }
        return mapped
    }

    // MARK: HTTP

    private func getJSON<T: Decodable>(path: String) async throws -> T {
        try await requestJSON(method: "GET", path: path, body: nil)
    }

    private func postJSON<T: Decodable>(path: String, body: [String: Any]) async throws -> T {
        try await requestJSON(method: "POST", path: path, body: body)
    }

    private func requestJSON<T: Decodable>(method: String, path: String, body: [String: Any]?) async throws -> T {
        let base = timesAPI.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let suffix = path.hasPrefix("/") ? path : "/" + path
        guard let requestURL = URL(string: base + suffix) else {
            throw DataHubImportError.http(-1, "Bad URL")
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("DataHub", forHTTPHeaderField: "AppName")
        request.setValue("Anonymous", forHTTPHeaderField: "Usas-Sub-Id")
        request.setValue(deviceID, forHTTPHeaderField: "Device-Id")
        request.setValue("https://data.usaswimming.org", forHTTPHeaderField: "Origin")
        request.setValue("SwimTracker/1.0", forHTTPHeaderField: "User-Agent")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(code) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw DataHubImportError.http(code, bodyText)
        }
        return try Self.decodeFlexible(data)
    }

    /// Data Hub often returns JSON-encoded JSON strings.
    private static func decodeFlexible<T: Decodable>(_ data: Data) throws -> T {
        let decoder = JSONDecoder()
        if let value = try? decoder.decode(T.self, from: data) {
            return value
        }
        if let wrapped = try? decoder.decode(String.self, from: data),
           let inner = wrapped.data(using: .utf8),
           let value = try? decoder.decode(T.self, from: inner) {
            return value
        }
        throw DataHubImportError.decoding
    }

    /// Match Data Hub SPA Device-Id rearrange (see spike/datahub/CONTRACT.md).
    private static func makeDeviceID() -> String {
        let millis = Int(Date().timeIntervalSince1970 * 1000)
        let raw = Data("platform - vendor - unknown - \(millis)".utf8).base64EncodedString()
        let prefix15 = String(raw.prefix(15))
        let prefix5 = String(raw.prefix(5))
        let rest = raw.count > 15 ? String(raw.dropFirst(15)) : ""
        return prefix15 + prefix5 + rest
    }
}

// MARK: - DTOs / mapping

private struct DistanceStroke: Hashable, Comparable {
    var distance: Int
    var stroke: String
    static func < (lhs: DistanceStroke, rhs: DistanceStroke) -> Bool {
        if lhs.distance != rhs.distance { return lhs.distance < rhs.distance }
        return lhs.stroke < rhs.stroke
    }
}

private struct DataHubMemberDTO: Decodable {
    var memberId: String
    var fullName: String
    var clubName: String?
    var lscCode: String?
    var swimmerAge: Int?
}

private struct DataHubBestSummaryDTO: Decodable {
    var distance: Int
    var strokeAbbreviation: String
    var courseCode: String?
    var swimTime: String?
}

private struct DataHubBestDetailDTO: Decodable {
    var distance: Int
    var strokeAbbreviation: String
    var courseCode: String
    var meetName: String?
    var eventCode: String?
    var swimDate: String
    var clubName: String?
    var swimTime: String
    var splits: [DataHubSplitDTO]?
}

private struct DataHubSplitDTO: Decodable {
    var cumulativeDistance: Double?
    var splitTime: String?
}

enum DataHubMapping {
    private static let strokeMap: [String: Stroke] = [
        "FR": .freestyle,
        "BK": .backstroke,
        "BR": .breaststroke,
        "FL": .butterfly,
        "IM": .medley,
    ]

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, yyyy"
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    static func mapDetail(_ row: DataHubBestDetailDTO) -> DataHubMappedSwim? {
        guard let stroke = strokeMap[row.strokeAbbreviation.uppercased()] else { return nil }
        guard let course = Course(rawValue: row.courseCode.uppercased()) else { return nil }
        guard let seconds = parseSwimTime(row.swimTime) else { return nil }
        guard let date = dateFormatter.date(from: row.swimDate) else { return nil }
        let day = Calendar.current.startOfDay(for: date)
        let meetName = (row.meetName ?? "Unknown meet").trimmingCharacters(in: .whitespacesAndNewlines)
        return DataHubMappedSwim(
            distance: row.distance,
            stroke: stroke,
            course: course,
            seconds: SwimSplits.roundToHundredths(seconds),
            date: day,
            meetName: meetName.isEmpty ? "Unknown meet" : meetName,
            team: (row.clubName ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            splits: mapSplits(distance: row.distance, splits: row.splits),
            eventCode: row.eventCode ?? ""
        )
    }

    static func parseSwimTime(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: ":")
        switch parts.count {
        case 1:
            return Double(parts[0])
        case 2:
            guard let minutes = Double(parts[0]), let seconds = Double(parts[1]) else { return nil }
            return minutes * 60 + seconds
        case 3:
            guard let hours = Double(parts[0]),
                  let minutes = Double(parts[1]),
                  let seconds = Double(parts[2]) else { return nil }
            return hours * 3600 + minutes * 60 + seconds
        default:
            return nil
        }
    }

    /// Keep 50-interval splits only (SwimTracker storage model).
    static func mapSplits(distance: Int, splits: [DataHubSplitDTO]?) -> [Double] {
        guard let splits, !splits.isEmpty else { return [] }
        let interval = 50
        guard distance >= interval, distance % interval == 0 else { return [] }
        let expected = distance / interval
        var byCum: [Int: Double] = [:]
        for split in splits {
            guard let cum = split.cumulativeDistance, let text = split.splitTime,
                  let seconds = parseSwimTime(text) else { continue }
            byCum[Int(cum)] = SwimSplits.roundToHundredths(seconds)
        }
        var values: [Double] = []
        values.reserveCapacity(expected)
        for i in 1...expected {
            guard let value = byCum[i * interval] else { return [] }
            values.append(value)
        }
        return values
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Store merge (skip existing)

extension Store {
    /// Identity used to skip times that are already on device.
    private func dataHubDedupeKey(distance: Int, stroke: Stroke, course: Course, seconds: Double?, date: Date, isRelay: Bool) -> String? {
        guard let seconds, seconds > 0, !isRelay else { return nil }
        let day = Calendar.current.startOfDay(for: date).timeIntervalSince1970
        let hundredths = Int((seconds * 100).rounded())
        return "\(Int(day))|\(distance)|\(stroke.rawValue)|\(course.rawValue)|\(hundredths)"
    }

    private func existingDataHubKeys() -> Set<String> {
        var keys = Set<String>()
        for time in times {
            if let key = dataHubDedupeKey(
                distance: time.distance,
                stroke: time.stroke,
                course: time.course,
                seconds: time.seconds,
                date: time.date,
                isRelay: time.isRelay
            ) {
                keys.insert(key)
            }
        }
        return keys
    }

    private func meetIDMatching(name: String, course: Course, date: Date) -> String? {
        let calendar = Calendar.current
        let needle = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return meets.first(where: { meet in
            guard meet.course == course else { return false }
            guard meet.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == needle else { return false }
            let start = calendar.startOfDay(for: meet.date)
            let end = calendar.startOfDay(for: meet.endDate)
            let day = calendar.startOfDay(for: date)
            return day >= start && day <= end
        })?.id
    }

    /// Imports Data Hub mapped swims, skipping any that already exist (same day, event, course, time).
    @discardableResult
    func importDataHubSwims(_ swims: [DataHubMappedSwim]) -> DataHubImportSummary {
        var summary = DataHubImportSummary(importedTimes: 0, skippedExisting: 0, createdMeets: 0, reusedMeets: 0)
        guard !swims.isEmpty else { return summary }

        var known = existingDataHubKeys()
        var meetCache: [String: String] = [:] // name|course|day → meetID
        var createdMeetIDs = Set<String>()
        var reusedMeetIDs = Set<String>()

        for swim in swims.sorted(by: { $0.date < $1.date }) {
            guard let key = dataHubDedupeKey(
                distance: swim.distance,
                stroke: swim.stroke,
                course: swim.course,
                seconds: swim.seconds,
                date: swim.date,
                isRelay: false
            ) else { continue }

            if known.contains(key) {
                summary.skippedExisting += 1
                continue
            }

            let day = Calendar.current.startOfDay(for: swim.date)
            let cacheKey = "\(swim.meetName.lowercased())|\(swim.course.rawValue)|\(Int(day.timeIntervalSince1970))"
            let meetID: String?
            if let cached = meetCache[cacheKey] {
                meetID = cached
                if !createdMeetIDs.contains(cached) {
                    reusedMeetIDs.insert(cached)
                }
            } else if let existing = meetIDMatching(name: swim.meetName, course: swim.course, date: swim.date) {
                meetID = existing
                meetCache[cacheKey] = existing
                reusedMeetIDs.insert(existing)
            } else if let created = addMeet(
                name: swim.meetName,
                team: swim.team,
                location: "",
                date: day,
                endDate: day,
                course: swim.course,
                hasPrelimsFinals: false
            ) {
                meetID = created
                meetCache[cacheKey] = created
                createdMeetIDs.insert(created)
            } else {
                meetID = nil
            }

            addTime(
                distance: swim.distance,
                stroke: swim.stroke,
                course: swim.course,
                seconds: swim.seconds,
                date: day,
                meetID: meetID,
                isRelay: false,
                note: "",
                splits: swim.splits
            )
            known.insert(key)
            summary.importedTimes += 1
        }

        summary.createdMeets = createdMeetIDs.count
        summary.reusedMeets = reusedMeetIDs.count
        return summary
    }
}
