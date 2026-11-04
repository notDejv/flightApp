import SwiftUI

struct MainTabView: View {
    enum Tab: Hashable {
        case home, favorites, profile, more
    }

    let dependencies: AppDependencies
    let user: User
    @State private var selection: Tab = .home
    @Environment(FavoritesStore.self) private var favorites

    var body: some View {
        TabView(selection: $selection) {
            HomeView(dependencies: dependencies, user: user)
                .tabItem { Label("Home", systemImage: "airplane.departure") }
                .tag(Tab.home)

            FavoritesView()
                .tabItem { Label("Favorite Flights", systemImage: "heart") }
                .badge(favorites.flights.count)
                .tag(Tab.favorites)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(Tab.profile)

            MoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
                .tag(Tab.more)
        }
        .alert(
            "Couldn't update favorites",
            isPresented: Binding(
                get: { favorites.errorMessage != nil },
                set: { if !$0 { favorites.dismissError() } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(favorites.errorMessage ?? "")
        }
    }
}
