import SwiftUI

/// Edit the men's 1000-point base times used for scoring. Changes save on device
/// as overrides; Reset restores the baked-in defaults from `BaseTimes.swift`.
struct BaseTimesView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var courseFilter: Course = .scy
    @State private var editingEvent: SwimEvent? = nil
    @State private var confirmingReset = false

    private var events: [SwimEvent] {
        BaseTimes.events(for: courseFilter)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Course", selection: $courseFilter) {
                        ForEach(Course.allCases) { course in
                            Text(course.rawValue).tag(course)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                Section {
                    ForEach(events) { event in
                        Button {
                            editingEvent = event
                        } label: {
                            BaseTimeRow(
                                event: event,
                                seconds: store.baseSeconds(for: event),
                                isCustom: store.hasCustomBaseTime(for: event)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    Text("Tap an event when a record falls. Custom times are saved on this device; Reset All restores the app defaults.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Base Times")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset All", role: .destructive) {
                        confirmingReset = true
                    }
                    .disabled(store.baseTimeOverrides.isEmpty)
                }
            }
            .confirmationDialog("Reset all base times to app defaults?", isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("Reset All", role: .destructive) {
                    store.resetAllBaseTimes()
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(item: $editingEvent) { event in
                BaseTimeEditorSheet(event: event)
            }
        }
    }
}

private struct BaseTimeRow: View {
    let event: SwimEvent
    let seconds: Double?
    let isCustom: Bool

    var body: some View {
        HStack(spacing: 12) {
            StrokeBadge(stroke: event.stroke)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(isCustom ? "Custom" : "Default")
                    .font(.caption)
                    .foregroundStyle(isCustom ? Theme.accent : .secondary)
            }

            Spacer(minLength: 8)

            Text(seconds?.asSwimTime ?? "—")
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(seconds == nil ? .secondary : .primary)
        }
        .padding(.vertical, 2)
    }
}

private struct BaseTimeEditorSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    let event: SwimEvent

    @State private var minutes: Int
    @State private var seconds: Int
    @State private var hundredths: Int

    init(event: SwimEvent) {
        self.event = event
        // Placeholder; real values set in onAppear via store.
        _minutes = State(initialValue: 0)
        _seconds = State(initialValue: 0)
        _hundredths = State(initialValue: 0)
    }

    private var totalSeconds: Double {
        Double(minutes) * 60 + Double(seconds) + Double(hundredths) / 100.0
    }

    private var factoryDefault: Double? {
        BaseTimes.defaultSeconds(for: event)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Event", value: event.titleWithCourse)
                    if let factoryDefault {
                        LabeledContent("App default", value: factoryDefault.asSwimTime)
                    } else {
                        LabeledContent("App default", value: "None (unscored)")
                    }
                }

                Section {
                    SwimTimeWheels(minutes: $minutes, seconds: $seconds, hundredths: $hundredths)
                } header: {
                    Text("1000-point base time")
                } footer: {
                    Text(totalSeconds > 0
                         ? "A swim of \(totalSeconds.asSwimTime) scores 1000 points."
                         : "Enter the new record / base time.")
                    .monospacedDigit()
                }

                if store.hasCustomBaseTime(for: event) {
                    Section {
                        Button("Revert to app default") {
                            store.clearBaseTimeOverride(for: event)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Edit Base Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.setBaseTime(for: event, seconds: totalSeconds)
                        dismiss()
                    }
                    .disabled(totalSeconds <= 0)
                }
            }
            .onAppear {
                let seed = store.baseSeconds(for: event) ?? factoryDefault ?? 0
                let components = seed.swimTimeComponents
                minutes = components.minutes
                seconds = components.seconds
                hundredths = components.hundredths
            }
        }
        .presentationDetents([.medium, .large])
    }
}
