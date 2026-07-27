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

#Preview {
    ContentView()
        .environment(Store())
        .tint(Theme.accent)
}
