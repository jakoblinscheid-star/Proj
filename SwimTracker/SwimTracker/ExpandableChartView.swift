import SwiftUI

/// Compact vs expanded chart layout. Horizontal swaps axes so category labels
/// stack vertically instead of crowding the X axis.
enum ChartOrientation: String, CaseIterable, Identifiable {
    case vertical = "Vertical"
    case horizontal = "Horizontal"
    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .vertical: return "chart.xyaxis.line"
        case .horizontal: return "chart.bar.xaxis"
        }
    }
}

/// Wraps a list-sized chart with an Expand control that opens a fullscreen
/// reader. Expanded view defaults to horizontal and can toggle orientation.
struct ExpandableChartContainer<CompactContent: View, ExpandedContent: View>: View {
    let title: String
    var supportsOrientationToggle: Bool = true
    @ViewBuilder var compact: () -> CompactContent
    @ViewBuilder var expanded: (_ orientation: ChartOrientation) -> ExpandedContent

    @State private var isExpanded = false
    @State private var orientation: ChartOrientation = .horizontal

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Button {
                orientation = supportsOrientationToggle ? .horizontal : .vertical
                isExpanded = true
            } label: {
                Label("Expand", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .accessibilityHint(supportsOrientationToggle
                               ? "Opens a larger chart you can flip horizontal"
                               : "Opens a larger chart")

            compact()
        }
        .fullScreenCover(isPresented: $isExpanded) {
            NavigationStack {
                VStack(spacing: 12) {
                    if supportsOrientationToggle {
                        Picker("Orientation", selection: $orientation) {
                            ForEach(ChartOrientation.allCases) { option in
                                Label(option.rawValue, systemImage: option.systemImage)
                                    .tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .accessibilityLabel("Chart orientation")
                    }

                    ScrollView {
                        expanded(orientation)
                            .frame(maxWidth: .infinity, minHeight: expandedMinHeight)
                            .padding(.horizontal)
                            .padding(.bottom)
                    }
                }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { isExpanded = false }
                    }
                }
            }
        }
    }

    private var expandedMinHeight: CGFloat {
        orientation == .horizontal ? 360 : 280
    }
}
