import Foundation
import Observation

/// Shared favorites state, so a change in Search Results shows up in the Favorites tab.
/// Backed by the signed-in user's repository; empty while nobody is signed in.
@Observable
@MainActor
final class FavoritesStore {
    private(set) var flights: [Flight] = []
    private(set) var errorMessage: String?

    private var ids: Set<String> = []
    private var repository: FavoritesRepository?

    init(repository: FavoritesRepository? = nil) {
        self.repository = repository
        reload()
    }

    /// Points the store at another user's favorites (or none, after logout).
    func switchRepository(_ repository: FavoritesRepository?) {
        self.repository = repository
        reload()
    }

    func isFavorite(_ flight: Flight) -> Bool {
        ids.contains(flight.id)
    }

    func toggle(_ flight: Flight) {
        if isFavorite(flight) {
            remove(flight)
        } else {
            perform { try $0.add(flight) }
        }
    }

    func remove(_ flight: Flight) {
        perform { try $0.remove(flightID: flight.id) }
    }

    func reload() {
        perform { _ in }
    }

    private func perform(_ change: (FavoritesRepository) throws -> Void) {
        guard let repository else {
            flights = []
            ids = []
            return
        }
        do {
            try change(repository)
            flights = try repository.favorites()
            ids = Set(flights.map(\.id))
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
