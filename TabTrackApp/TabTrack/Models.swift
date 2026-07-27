import Foundation
import Observation

/// A single thing a friend owes you (what it was for, how much, and whether they've paid).
struct DebtItem: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var description: String
    var amount: Double
    var date: Date = Date()
    var paid: Bool = false
}

/// A person you're keeping a tab on, plus everything they currently owe you.
struct Friend: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var note: String = ""
    var items: [DebtItem] = []

    /// Outstanding balance: the sum of unpaid items.
    var balance: Double {
        items.reduce(0) { $0 + ($1.paid ? 0 : $1.amount) }
    }
}

/// App-wide state. Owns the list of friends and persists it to disk as JSON,
/// mirroring the original web app's local-first `localStorage` behaviour.
@Observable
final class Store {
    var friends: [Friend] = [] {
        didSet { save() }
    }

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private var isLoading = false

    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = dir.appendingPathComponent("tabtrack.v1.json")
        load()
    }

    /// Total owed to you across every friend.
    var grandTotal: Double {
        friends.reduce(0) { $0 + $1.balance }
    }

    // MARK: - Friend mutations

    func addFriend(name: String, note: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let friend = Friend(name: trimmed, note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        friends.insert(friend, at: 0)
    }

    func updateFriend(id: String, name: String, note: String) {
        guard let index = friends.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        friends[index].name = trimmed
        friends[index].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func deleteFriend(id: String) {
        friends.removeAll { $0.id == id }
    }

    // MARK: - Item mutations

    func addItem(to friendID: String, description: String, amount: Double) {
        guard let index = friends.firstIndex(where: { $0.id == friendID }) else { return }
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, amount >= 0 else { return }
        let rounded = (amount * 100).rounded() / 100
        friends[index].items.append(DebtItem(description: trimmed, amount: rounded))
    }

    func deleteItem(_ itemID: String, from friendID: String) {
        guard let index = friends.firstIndex(where: { $0.id == friendID }) else { return }
        friends[index].items.removeAll { $0.id == itemID }
    }

    func setItemPaid(_ itemID: String, paid: Bool, in friendID: String) {
        guard let fIndex = friends.firstIndex(where: { $0.id == friendID }),
              let iIndex = friends[fIndex].items.firstIndex(where: { $0.id == itemID }) else { return }
        friends[fIndex].items[iIndex].paid = paid
    }

    func friend(id: String) -> Friend? {
        friends.first { $0.id == id }
    }

    // MARK: - Persistence

    private func load() {
        isLoading = true
        defer { isLoading = false }
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder.tabTrack.decode([Friend].self, from: data) else {
            return
        }
        friends = decoded
    }

    private func save() {
        guard !isLoading else { return }
        guard let data = try? JSONEncoder.tabTrack.encode(friends) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}

private extension JSONEncoder {
    static let tabTrack: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

private extension JSONDecoder {
    static let tabTrack: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
