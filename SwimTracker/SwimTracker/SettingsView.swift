import SwiftUI
import UniformTypeIdentifiers

/// Profile preferences: scoring gender, default course, and Times sort.
struct SettingsView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var showingBaseTimes = false
    @State private var exportDocument: SwimTrackerBackupDocument?
    @State private var showingExporter = false
    @State private var showingImportConfirm = false
    @State private var showingImporter = false
    @State private var alert: SettingsAlert?

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section {
                    Picker("Score as", selection: $store.settings.gender) {
                        ForEach(Gender.allCases) { gender in
                            Text(gender.rawValue).tag(gender)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Scoring")
                } footer: {
                    Text("Times badges and Your Score use \(store.settings.gender.rawValue.lowercased()) World Aquatics base times. Calc can still score either gender.")
                }

                Section {
                    Picker("Default course", selection: $store.settings.defaultCourse) {
                        ForEach(Course.allCases) { course in
                            Text(course.rawValue).tag(course)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Defaults")
                } footer: {
                    Text("Pre-selects \(store.settings.defaultCourse.rawValue) when adding times, meet results, Calc, Convert, and Base Times.")
                }

                Section {
                    Picker("Times sort", selection: $store.settings.timesSortMode) {
                        ForEach(TimesSortMode.allCases) { mode in
                            Label(mode.rawValue, systemImage: mode.systemImage).tag(mode)
                        }
                    }
                } header: {
                    Text("Score preferences")
                } footer: {
                    Text("Default ordering on the Times tab. Changing sort there also updates this setting.")
                }

                Section("Base times") {
                    Button {
                        showingBaseTimes = true
                    } label: {
                        Label("Edit base times", systemImage: "trophy.fill")
                    }
                }

                Section {
                    Button {
                        prepareExport()
                    } label: {
                        Label("Export data", systemImage: "square.and.arrow.up")
                    }

                    Button(role: .destructive) {
                        showingImportConfirm = true
                    } label: {
                        Label("Import data…", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Export a JSON backup of your meets, times, base times, and settings. Import replaces everything currently on this device.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingBaseTimes) {
                BaseTimesView()
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: store.backupExportFilename.replacingOccurrences(of: ".json", with: "")
            ) { result in
                exportDocument = nil
                if case .failure(let error) = result {
                    alert = .message("Export failed", error.localizedDescription)
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .confirmationDialog(
                "Replace all data?",
                isPresented: $showingImportConfirm,
                titleVisibility: .visible
            ) {
                Button("Choose Backup File", role: .destructive) {
                    showingImporter = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Importing replaces your meets, times, base times, and settings with the backup file. This cannot be undone.")
            }
            .alert(item: $alert) { item in
                Alert(title: Text(item.title), message: Text(item.message), dismissButton: .default(Text("OK")))
            }
        }
    }

    private func prepareExport() {
        do {
            exportDocument = SwimTrackerBackupDocument(data: try store.exportBackup())
            showingExporter = true
        } catch {
            alert = .message("Export failed", error.localizedDescription)
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            alert = .message("Import failed", error.localizedDescription)
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let data = try Data(contentsOf: url)
                try store.importBackup(from: data)
                let meetCount = store.meets.count
                let timeCount = store.times.count
                alert = .message(
                    "Import complete",
                    "Restored \(meetCount) meet\(meetCount == 1 ? "" : "s") and \(timeCount) time\(timeCount == 1 ? "" : "s")."
                )
            } catch is DecodingError {
                alert = .message("Import failed", BackupError.unreadableFile.localizedDescription)
            } catch {
                alert = .message("Import failed", error.localizedDescription)
            }
        }
    }
}

/// FileDocument wrapper so Settings can use SwiftUI's fileExporter.
struct SwimTrackerBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct SettingsAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    static func message(_ title: String, _ message: String) -> SettingsAlert {
        SettingsAlert(title: title, message: message)
    }
}

#Preview {
    SettingsView()
        .environment(Store())
        .tint(Theme.accent)
}
