import SwiftUI

/// A single friend's tab: their balance, itemised debts, and an add-item form.
struct FriendDetailView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    let friendID: String

    @State private var newDescription = ""
    @State private var newAmount = ""
    @State private var showingEdit = false
    @FocusState private var descFocused: Bool

    private var friend: Friend? { store.friend(id: friendID) }

    var body: some View {
        Group {
            if let friend {
                content(for: friend)
            } else {
                ContentUnavailableView("Friend not found", systemImage: "questionmark.circle")
            }
        }
        .navigationTitle(friend?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if friend != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { showingEdit = true }
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            if let friend {
                FriendEditView(mode: .edit(name: friend.name, note: friend.note)) { name, note in
                    store.updateFriend(id: friend.id, name: name, note: note)
                }
            }
        }
    }

    private func content(for friend: Friend) -> some View {
        List {
            Section {
                HStack {
                    AvatarView(name: friend.name, size: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Owes you")
                            .font(.caption)
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                        Text(friend.balance.asCurrency)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(friend.balance > 0 ? Theme.success : Color.secondary)
                            .contentTransition(.numericText())
                            .animation(.snappy, value: friend.balance)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            Section("Items") {
                if friend.items.isEmpty {
                    Text("No items yet — add one below.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(friend.items) { item in
                        ItemRowView(item: item) { paid in
                            store.setItemPaid(item.id, paid: paid, in: friend.id)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            store.deleteItem(friend.items[index].id, from: friend.id)
                        }
                    }
                }
            }

            Section("Add an item") {
                addItemForm(for: friend)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func addItemForm(for friend: Friend) -> some View {
        VStack(spacing: 10) {
            TextField("What for? (e.g. Lunch)", text: $newDescription)
                .textInputAutocapitalization(.sentences)
                .focused($descFocused)

            HStack {
                TextField("0.00", text: $newAmount)
                    .keyboardType(.decimalPad)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    addItem(to: friend)
                } label: {
                    Text("Add")
                        .frame(maxWidth: 80)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canAdd)
            }
        }
        .padding(.vertical, 4)
    }

    private var canAdd: Bool {
        !newDescription.trimmingCharacters(in: .whitespaces).isEmpty
            && (parsedAmount ?? -1) >= 0
    }

    private var parsedAmount: Double? {
        Double(newAmount.replacingOccurrences(of: ",", with: "."))
    }

    private func addItem(to friend: Friend) {
        guard let amount = parsedAmount else { return }
        store.addItem(to: friend.id, description: newDescription, amount: amount)
        newDescription = ""
        newAmount = ""
        descFocused = false
    }
}

/// A single debt item row with a tap-to-toggle "paid" checkbox.
struct ItemRowView: View {
    let item: DebtItem
    var onTogglePaid: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onTogglePaid(!item.paid)
            } label: {
                Image(systemName: item.paid ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.paid ? Theme.success : Color.secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.description)
                    .strikethrough(item.paid)
                    .foregroundStyle(item.paid ? .secondary : .primary)
                Text(item.date.asShortDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(item.amount.asCurrency)
                .font(.body.monospacedDigit())
                .strikethrough(item.paid)
                .foregroundStyle(item.paid ? .secondary : .primary)
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    let store = Store()
    store.addFriend(name: "Alex Rivera", note: "College roommate")
    store.addItem(to: store.friends[0].id, description: "Concert tickets", amount: 85)
    store.addItem(to: store.friends[0].id, description: "Pizza", amount: 12.5)
    return NavigationStack {
        FriendDetailView(friendID: store.friends[0].id)
    }
    .environment(store)
}
