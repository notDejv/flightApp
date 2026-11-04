import Foundation
import Observation

/// Shared favorites state, so a change in Search Results shows up in the Favorites tab.
/// Backed by the signed-in user's repository; empty while nobody is signed in.
@Observable
@MainActor
final class FavoritesStore {
    private(set) var flights: [Flight] = []
    private(set) var errorMessage: String?

    /// Called with a flight's ID after it's removed, e.g. to end its Live Activity.
    var onRemove: ((String) -> Void)?

    private var ids: Set<String> = []
    private var repository: FavoritesRepository?

    init(repository: FavoritesRepository? = nil) {
        self.repository = repository
        reload()
    }

    /// Points the store at another user's favorites (or none, after logout).
    func switchRepository(_ repository: FavoritesRepository?) {
        self.repository = repository
        // Never keep the previous user's flights around, even if the reload fails.
        flights = []
        ids = []
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
        if perform({ try $0.remove(flightID: flight.id) }) {
            onRemove?(flight.id)
        }
    }

    func reload() {
        perform { _ in }
    }

    func dismissError() {
        errorMessage = nil
    }

    @discardableResult
    private func perform(_ change: (FavoritesRepository) throws -> Void) -> Bool {
        guard let repository else {
            flights = []
            ids = []
            return false
        }
        do {
            try change(repository)
            flights = try repository.favorites()
            ids = Set(flights.map(\.id))
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
