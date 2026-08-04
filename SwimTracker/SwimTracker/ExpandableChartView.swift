import SwiftUI

/// Wraps a list-sized chart with an Expand control that opens a fullscreen reader.
struct ExpandableChartContainer<CompactContent: View, ExpandedContent: View>: View {
    let title: String
    @ViewBuilder var compact: () -> CompactContent
    @ViewBuilder var expanded: () -> ExpandedContent

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Button {
                isExpanded = true
            } label: {
                Label("Expand", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .accessibilityHint("Opens a larger chart")

            compact()
        }
        .fullScreenCover(isPresented: $isExpanded) {
            NavigationStack {
                ScrollView {
                    expanded()
                        .frame(maxWidth: .infinity, minHeight: 280)
                        .padding(.horizontal)
                        .padding(.bottom)
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
}
