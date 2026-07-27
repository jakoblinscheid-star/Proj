import SwiftUI

/// Root tab bar: Home, Times, Meets, Score, and Convert.
struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            TimesView()
                .tabItem { Label("Times", systemImage: "stopwatch.fill") }

            MeetsView()
                .tabItem { Label("Meets", systemImage: "flag.checkered") }

            ScoreView()
                .tabItem { Label("Score", systemImage: "chart.bar.fill") }

            ConvertView()
                .tabItem { Label("Convert", systemImage: "arrow.left.arrow.right") }
        }
    }
}

/// Reusable placeholder for tabs whose details are still being designed.
struct ComingSoonView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
    }
}

#Preview {
    ContentView()
        .environment(Store())
        .tint(Theme.accent)
}
