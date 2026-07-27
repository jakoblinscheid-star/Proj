import SwiftUI

/// Home screen: the grand total, a searchable list of friends, and an add button.
struct ContentView: View {
    @Environment(Store.self) private var store
    @State private var searchText = ""
    @State private var showingAdd = false

    private var visibleFriends: [Friend] {
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !term.isEmpty else { return store.friends }
        return store.friends.filter { $0.name.lowercased().contains(term) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.friends.isEmpty {
                    EmptyStateView { showingAdd = true }
                } else {
                    friendsList
                }
            }
            .navigationTitle("TabTrack")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) {
                TotalHeaderView(total: store.grandTotal)
            }
            .navigationDestination(for: String.self) { friendID in
                FriendDetailView(friendID: friendID)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add friend", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                FriendEditView(mode: .add) { name, note in
                    store.addFriend(name: name, note: note)
                }
            }
        }
    }

    private var friendsList: some View {
        List {
            ForEach(visibleFriends) { friend in
                NavigationLink(value: friend.id) {
                    FriendRowView(friend: friend)
                }
            }
            .onDelete(perform: deleteFriends)
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "Search friends")
        .overlay {
            if visibleFriends.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    private func deleteFriends(at offsets: IndexSet) {
        let ids = offsets.map { visibleFriends[$0].id }
        for id in ids { store.deleteFriend(id: id) }
    }
}

/// Sticky header showing the total amount owed to you across everyone.
struct TotalHeaderView: View {
    let total: Double

    var body: some View {
        VStack(spacing: 2) {
            Text("Total owed to you")
                .font(.caption)
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(.secondary)
            Text(total.asCurrency)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(total > 0 ? Theme.success : Color.secondary)
                .contentTransition(.numericText())
                .animation(.snappy, value: total)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

/// One row in the friends list: avatar, name, optional note, and current balance.
struct FriendRowView: View {
    let friend: Friend

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(name: friend.name)

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.name)
                    .font(.headline)
                    .lineLimit(1)
                if !friend.note.isEmpty {
                    Text(friend.note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text(friend.balance.asCurrency)
                .font(.headline.monospacedDigit())
                .foregroundStyle(friend.balance > 0 ? Theme.success : Color.secondary)
        }
        .padding(.vertical, 4)
    }
}

/// Coloured, initialled avatar bubble.
struct AvatarView: View {
    let name: String
    var size: CGFloat = 42

    var body: some View {
        Text(Theme.initials(for: name))
            .font(.system(size: size * 0.38, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Theme.avatarColor(for: name), in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
    }
}

/// Shown when there are no friends yet.
struct EmptyStateView: View {
    var onAdd: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No friends yet", systemImage: "person.2")
        } description: {
            Text("Add a friend to start tracking what they owe you.")
        } actions: {
            Button(action: onAdd) {
                Label("Add your first friend", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    ContentView()
        .environment(Store())
}
