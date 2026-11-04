import Foundation
import Observation
import SwiftData

/// Composition root. Builds services and shared stores once and hands them to the UI.
@Observable
@MainActor
final class AppDependencies {
    let modelContainer: ModelContainer
    let airports: AirportCatalog
    let flightService: FlightService
    let authService: AuthService
    let session: SessionStore
    let theme: ThemeStore
    let favorites: FavoritesStore
    let liveActivities: LiveActivityService

    init(
        modelContainer: ModelContainer,
        airports: AirportCatalog = BundleAirportCatalog(),
        flightService: FlightService = MockFlightService(),
        authService: AuthService = MockAuthService(),
        defaults: UserDefaults = .standard
    ) {
        self.modelContainer = modelContainer
        self.airports = airports
        self.flightService = flightService
        self.authService = authService
        session = SessionStore(defaults: defaults)
        theme = ThemeStore(defaults: defaults)
        favorites = FavoritesStore()
        liveActivities = LiveActivityService()

        // Favorites always belong to whoever is signed in, and Live Activities don't
        // outlive the session that started them.
        // The tasks capture the service itself, since they can outlive `self`.
        session.onUserChange = { [unowned self, liveActivities] user in
            favorites.switchRepository(user.map(favoritesRepository(for:)))
            Task { await liveActivities.stopAll() }
        }
        favorites.switchRepository(session.user.map(favoritesRepository(for:)))

        // Only favorites can be tracked, so unfavoriting ends the activity.
        favorites.onRemove = { [liveActivities] flightID in
            Task { await liveActivities.stop(flightID: flightID) }
        }
    }

    func recentSearchRepository(for user: User) -> RecentSearchRepository {
        SwiftDataRecentSearchRepository(context: modelContainer.mainContext, ownerID: user.id)
    }

    func favoritesRepository(for user: User) -> FavoritesRepository {
        SwiftDataFavoritesRepository(context: modelContainer.mainContext, ownerID: user.id)
    }

    static func live() -> AppDependencies {
        do {
            return AppDependencies(modelContainer: try PersistenceStack.makeContainer())
        } catch {
            fatalError("Could not open the data store: \(error)")
        }
    }

    static func preview(loggedIn: Bool = true) -> AppDependencies {
        let defaults = UserDefaults(suiteName: "preview")!
        defaults.removePersistentDomain(forName: "preview")
        let dependencies = AppDependencies(
            modelContainer: try! PersistenceStack.makeContainer(inMemory: true),
            flightService: MockFlightService(latency: .zero),
            defaults: defaults
        )
        if loggedIn {
            dependencies.session.signIn(User(username: "jane.doe", displayName: "Jane Doe", email: "jane.doe@example.com"))
        }
        return dependencies
    }
}
