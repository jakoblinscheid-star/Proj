import SwiftUI

/// Course conversion tab: SCY ↔ SCM ↔ LCM using Colorado Timing factors
/// (same model as SwimSwam's classic converter).
struct ConvertView: View {
    @State private var event: ConverterEvent = ConverterEvent.catalog.first {
        $0.stroke == .freestyle && $0.meterDistance == 100
    } ?? ConverterEvent.catalog[0]
    @State private var fromCourse: Course = .scy
    @State private var toCourse: Course = .lcm
    @State private var minutes = 0
    @State private var seconds = 0
    @State private var hundredths = 0

    private var inputSeconds: Double {
        Double(minutes * 60 + seconds) + Double(hundredths) / 100.0
    }

    private var convertedSeconds: Double? {
        guard fromCourse != toCourse else { return inputSeconds > 0 ? inputSeconds : nil }
        return CourseConverter.convert(
            seconds: inputSeconds,
            event: event,
            from: fromCourse,
            to: toCourse
        )
    }

    private var fromDistanceLabel: String {
        "\(event.distance(for: fromCourse)) \(fromCourse.unit)"
    }

    private var toDistanceLabel: String {
        "\(event.distance(for: toCourse)) \(toCourse.unit)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Event", selection: $event) {
                        ForEach(ConverterEvent.catalog) { item in
                            Text(item.label).tag(item)
                        }
                    }

                    Picker("From", selection: $fromCourse) {
                        ForEach(Course.allCases) { course in
                            Text(course.rawValue).tag(course)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("To", selection: $toCourse) {
                        ForEach(Course.allCases) { course in
                            Text(course.rawValue).tag(course)
                        }
                    }
                    .pickerStyle(.segmented)

                    Button {
                        swapCourses()
                    } label: {
                        Label("Swap courses", systemImage: "arrow.up.arrow.down")
                    }
                    .disabled(fromCourse == toCourse)
                } header: {
                    Text("Event & course")
                } footer: {
                    if event.meterDistance != event.yardDistance {
                        Text("Distance free maps \(event.meterDistance) m ↔ \(event.yardDistance) yd.")
                    }
                }

                Section {
                    SwimTimeWheels(minutes: $minutes, seconds: $seconds, hundredths: $hundredths)
                } header: {
                    Text("Time · \(fromCourse.rawValue) · \(fromDistanceLabel)")
                }

                Section {
                    if fromCourse == toCourse {
                        Text("Pick different From and To courses.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if let convertedSeconds {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(convertedSeconds.asSwimTime)
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Theme.accent)
                            Text("\(event.stroke.fullName) · \(toCourse.rawValue) · \(toDistanceLabel)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    } else {
                        Text("Enter a time to convert.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Converted")
                } footer: {
                    Text("Uses Colorado Timing factors (SwimSwam classic). Estimates only — turns and underwater skill vary by swimmer.")
                }
            }
            .navigationTitle("Convert")
        }
    }

    private func swapCourses() {
        let previousFrom = fromCourse
        fromCourse = toCourse
        toCourse = previousFrom
    }
}

#Preview {
    ConvertView()
        .tint(Theme.accent)
}
