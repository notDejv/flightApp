import SwiftUI

struct FavoritesView: View {
    @Environment(FavoritesStore.self) private var favorites

    var body: some View {
        NavigationStack {
            Group {
                if favorites.flights.isEmpty {
                    MascotEmptyState(
                        mood: .sleepy,
                        title: "No favorite flights",
                        message: "Tap the heart on a search result and it'll nap here until you need it."
                    )
                    .background { SkyBackground() }
                } else {
                    list
                }
            }
            .animation(.default, value: favorites.flights)
            .navigationTitle("Favorite Flights")
            .navigationDestination(for: Flight.self) { flight in
                FlightDetailsView(flight: flight)
            }
        }
    }

    private var list: some View {
        List {
            ForEach(favorites.flights) { flight in
                NavigationLink(value: flight) {
                    FlightRow(flight: flight) {
                        Text(flight.departure, format: .dateTime.day().month(.abbreviated))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions {
                    Button("Remove", systemImage: "heart.slash", role: .destructive) {
                        favorites.remove(flight)
                    }
                }
            }
            .onDelete { offsets in
                offsets.map { favorites.flights[$0] }.forEach(favorites.remove)
            }
        }
        .listStyle(.insetGrouped)
        .skyBackground()
        .toolbar { EditButton() }
    }
}
