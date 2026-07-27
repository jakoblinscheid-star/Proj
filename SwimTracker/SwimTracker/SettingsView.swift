import SwiftUI

/// Profile preferences: scoring gender, default course, and Times sort.
struct SettingsView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var showingBaseTimes = false

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
        }
    }
}

#Preview {
    SettingsView()
        .environment(Store())
        .tint(Theme.accent)
}
