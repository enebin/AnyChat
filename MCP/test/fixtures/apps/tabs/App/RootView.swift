import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                HomeView()
            }
            Tab("Settings", systemImage: "gear") {
                Text("Settings")
            }
        }
    }
}

struct HomeView: View {
    var body: some View {
        NavigationStack {
            List(1...3, id: \.self) { item in
                Text("Item \(item)")
            }
            .navigationTitle("Home")
        }
    }
}
