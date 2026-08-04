import SwiftUI

/// Search Data Hub and import personal bests, skipping times already on device.
struct DataHubImportView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var includeHistorical = false
    @State private var lscCode = ""
    @State private var matches: [DataHubMemberMatch] = []
    @State private var selected: DataHubMemberMatch?
    @State private var preview: [DataHubMappedSwim] = []
    @State private var isSearching = false
    @State private var isLoadingPreview = false
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var summary: DataHubImportSummary?

    private var newCount: Int {
        preview.filter { !storeAlreadyHas($0) }.count
    }

    private var existingCount: Int {
        preview.count - newCount
    }

    var body: some View {
        Form {
            Section {
                TextField("Name or member ID", text: $query)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                TextField("LSC (optional)", text: $lscCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Toggle("Include historical members", isOn: $includeHistorical)
                Button {
                    Task { await search() }
                } label: {
                    if isSearching {
                        ProgressView()
                    } else {
                        Label("Search Data Hub", systemImage: "magnifyingglass")
                    }
                }
                .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
            } header: {
                Text("Athlete")
            } footer: {
                Text("Pulls personal bests from USA Swimming Data Hub. Times you already have (same day, event, course, and time) are skipped.")
            }

            if !matches.isEmpty {
                Section("Matches") {
                    ForEach(matches) { match in
                        Button {
                            Task { await loadPreview(for: match) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(match.fullName)
                                        .foregroundStyle(.primary)
                                    Text(subtitle(for: match))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selected?.memberId == match.memberId {
                                    if isLoadingPreview {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Theme.accent)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if let selected, !preview.isEmpty {
                Section {
                    ForEach(preview) { swim in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(swim.distance) \(swim.stroke.rawValue) \(swim.course.rawValue)")
                                    .font(.body.weight(.medium))
                                Text(swim.meetName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(swim.date.asShortDate)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(swim.seconds.asSwimTime)
                                    .monospacedDigit()
                                if storeAlreadyHas(swim) {
                                    Text("Already in app")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("New")
                                        .font(.caption2)
                                        .foregroundStyle(Theme.success)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Preview · \(selected.fullName)")
                } footer: {
                    Text("\(newCount) new · \(existingCount) already stored. Import adds only the new ones.")
                }

                Section {
                    Button {
                        importSelected()
                    } label: {
                        if isImporting {
                            ProgressView()
                        } else {
                            Label("Import \(newCount) new time\(newCount == 1 ? "" : "s")", systemImage: "square.and.arrow.down")
                        }
                    }
                    .disabled(newCount == 0 || isImporting)
                }
            }

            if let summary {
                Section("Last import") {
                    Text("Added \(summary.importedTimes) time\(summary.importedTimes == 1 ? "" : "s")")
                    Text("Skipped \(summary.skippedExisting) already stored")
                    Text("Created \(summary.createdMeets) meet\(summary.createdMeets == 1 ? "" : "s")")
                    if summary.reusedMeets > 0 {
                        Text("Linked to \(summary.reusedMeets) existing meet\(summary.reusedMeets == 1 ? "" : "s")")
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Import times")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }

    private func subtitle(for match: DataHubMemberMatch) -> String {
        var parts: [String] = []
        if !match.clubName.isEmpty { parts.append(match.clubName) }
        if !match.lscCode.isEmpty { parts.append(match.lscCode) }
        if let age = match.swimmerAge { parts.append("Age \(age)") }
        parts.append(match.memberId)
        return parts.joined(separator: " · ")
    }

    private func storeAlreadyHas(_ swim: DataHubMappedSwim) -> Bool {
        let calendar = Calendar.current
        let hundredths = Int((swim.seconds * 100).rounded())
        return store.times.contains { time in
            guard !time.isRelay, let seconds = time.seconds, seconds > 0 else { return false }
            guard time.distance == swim.distance,
                  time.stroke == swim.stroke,
                  time.course == swim.course else { return false }
            guard calendar.isDate(time.date, inSameDayAs: swim.date) else { return false }
            return Int((seconds * 100).rounded()) == hundredths
        }
    }

    @MainActor
    private func search() async {
        errorMessage = nil
        summary = nil
        preview = []
        selected = nil
        matches = []
        isSearching = true
        defer { isSearching = false }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let lsc = lscCode.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            // Hex-ish member ids from Data Hub are 14 chars; allow direct lookup.
            if trimmed.count >= 10, trimmed.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) == nil {
                let member = try await DataHubClient.shared.getMember(memberId: trimmed.uppercased())
                matches = [member]
                await loadPreview(for: member)
                return
            }

            let found = try await DataHubClient.shared.searchMembers(
                name: trimmed,
                isCurrent: !includeHistorical,
                lscCode: lsc.isEmpty ? nil : lsc
            )
            if found.isEmpty {
                errorMessage = DataHubImportError.noMembers.localizedDescription
            }
            matches = found
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadPreview(for match: DataHubMemberMatch) async {
        errorMessage = nil
        summary = nil
        selected = match
        preview = []
        isLoadingPreview = true
        defer { isLoadingPreview = false }

        do {
            let swims = try await DataHubClient.shared.pullPersonalBests(memberId: match.memberId)
            if swims.isEmpty {
                errorMessage = DataHubImportError.emptyPull.localizedDescription
            }
            preview = swims.sorted {
                if $0.date != $1.date { return $0.date > $1.date }
                if $0.distance != $1.distance { return $0.distance < $1.distance }
                return $0.stroke.order < $1.stroke.order
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importSelected() {
        guard !preview.isEmpty else { return }
        isImporting = true
        defer { isImporting = false }
        let result = store.importDataHubSwims(preview)
        summary = result
        // Refresh “Already in app” badges after merge.
        preview = preview
        errorMessage = nil
    }
}
