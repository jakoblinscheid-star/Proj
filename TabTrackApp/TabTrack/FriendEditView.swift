import SwiftUI

/// A modal form for adding a new friend or editing an existing one.
struct FriendEditView: View {
    enum Mode {
        case add
        case edit(name: String, note: String)

        var title: String {
            switch self {
            case .add: return "Add Friend"
            case .edit: return "Edit Friend"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    /// Called with the trimmed-on-save name and note when the user taps Save.
    var onSave: (_ name: String, _ note: String) -> Void

    @State private var name: String
    @State private var note: String
    @FocusState private var nameFocused: Bool

    init(mode: Mode, onSave: @escaping (_ name: String, _ note: String) -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .add:
            _name = State(initialValue: "")
            _note = State(initialValue: "")
        case let .edit(name, note):
            _name = State(initialValue: name)
            _note = State(initialValue: note)
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .focused($nameFocused)
                    TextField("Note (optional)", text: $note)
                        .textInputAutocapitalization(.sentences)
                } footer: {
                    Text("A note can help you remember how you know them.")
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name, note)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear { nameFocused = true }
        }
    }
}

#Preview {
    FriendEditView(mode: .add) { _, _ in }
}
