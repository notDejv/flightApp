import Foundation
import SwiftData
import Testing
@testable import FlightApp

@MainActor
struct RecentSearchRepositoryTests {
    let container: ModelContainer
    let clock = TestClock()

    init() throws {
        container = try Fixtures.inMemoryContainer()
    }

    func makeRepository(owner: String = "jane", limit: Int = 10) -> SwiftDataRecentSearchRepository {
        SwiftDataRecentSearchRepository(context: container.mainContext, ownerID: owner, limit: limit, now: clock.tick)
    }

    @Test func newestSearchComesFirst() throws {
        let repository = makeRepository()
        try repository.save(Fixtures.criteria(Fixtures.tirana, Fixtures.rome))
        try repository.save(Fixtures.criteria(Fixtures.tirana, Fixtures.milan))

        #expect(try repository.recentSearches().map(\.destination) == [Fixtures.milan, Fixtures.rome])
    }

    @Test func repeatingASearchMovesItToTopWithoutDuplicating() throws {
        let repository = makeRepository()
        try repository.save(Fixtures.criteria(Fixtures.tirana, Fixtures.rome))
        try repository.save(Fixtures.criteria(Fixtures.tirana, Fixtures.milan))
        try repository.save(Fixtures.criteria(Fixtures.tirana, Fixtures.rome))

        #expect(try repository.recentSearches().map(\.destination) == [Fixtures.rome, Fixtures.milan])
    }

    @Test func sameRouteOnDifferentDatesIsSeparateEntry() throws {
        let repository = makeRepository()
        try repository.save(Fixtures.criteria(departure: Fixtures.day))
        try repository.save(Fixtures.criteria(departure: Fixtures.date(daysAfter: 1)))

        #expect(try repository.recentSearches().count == 2)
    }

    @Test func keepsOnlyTheNewestEntriesUpToLimit() throws {
        let repository = makeRepository(limit: 3)
        for offset in 0..<5 {
            try repository.save(Fixtures.criteria(
                departure: Fixtures.date(daysAfter: offset),
                arrival: Fixtures.date(daysAfter: offset + 1)
            ))
        }

        let departures = try repository.recentSearches().map(\.departureDate)
        #expect(departures == [4, 3, 2].map { Fixtures.date(daysAfter: $0) })
    }

    @Test func persistsAcrossRepositoryInstances() throws {
        try makeRepository().save(Fixtures.criteria())
        #expect(try makeRepository().recentSearches() == [Fixtures.criteria()])
    }

    @Test func searchesAreScopedToTheirOwner() throws {
        try makeRepository(owner: "jane").save(Fixtures.criteria(Fixtures.tirana, Fixtures.rome))
        try makeRepository(owner: "john").save(Fixtures.criteria(Fixtures.tirana, Fixtures.milan))

        #expect(try makeRepository(owner: "jane").recentSearches().map(\.destination) == [Fixtures.rome])
        #expect(try makeRepository(owner: "john").recentSearches().map(\.destination) == [Fixtures.milan])
    }

    @Test func limitIsPerOwner() throws {
        let jane = makeRepository(owner: "jane", limit: 1)
        try makeRepository(owner: "john", limit: 1).save(Fixtures.criteria(Fixtures.tirana, Fixtures.milan))
        try jane.save(Fixtures.criteria(Fixtures.tirana, Fixtures.rome))

        #expect(try makeRepository(owner: "john").recentSearches().count == 1)
    }
}

@MainActor
struct FavoritesTests {
    let container: ModelContainer
    let clock = TestClock()

    init() throws {
        container = try Fixtures.inMemoryContainer()
    }

    func makeRepository(owner: String = "jane") -> SwiftDataFavoritesRepository {
        SwiftDataFavoritesRepository(context: container.mainContext, ownerID: owner, now: clock.tick)
    }

    @Test func addingTwiceStoresOnce() throws {
        let repository = makeRepository()
        try repository.add(Fixtures.flight())
        try repository.add(Fixtures.flight())

        #expect(try repository.favorites() == [Fixtures.flight()])
    }

    @Test func removeDeletesOnlyThatFlight() throws {
        let repository = makeRepository()
        try repository.add(Fixtures.flight(id: "a"))
        try repository.add(Fixtures.flight(id: "b"))
        try repository.remove(flightID: "a")

        #expect(try repository.favorites().map(\.id) == ["b"])
    }

    @Test func storeToggleAddsAndRemoves() {
        let store = FavoritesStore(repository: makeRepository())
        let flight = Fixtures.flight()

        store.toggle(flight)
        #expect(store.isFavorite(flight))
        #expect(store.flights == [flight])

        store.toggle(flight)
        #expect(!store.isFavorite(flight))
        #expect(store.flights.isEmpty)
    }

    @Test func storeLoadsPersistedFavorites() {
        FavoritesStore(repository: makeRepository()).toggle(Fixtures.flight())

        let reopened = FavoritesStore(repository: makeRepository())
        #expect(reopened.isFavorite(Fixtures.flight()))
    }

    @Test func newestFavoriteComesFirst() {
        let store = FavoritesStore(repository: makeRepository())
        store.toggle(Fixtures.flight(id: "older"))
        store.toggle(Fixtures.flight(id: "newer"))

        #expect(store.flights.map(\.id) == ["newer", "older"])
    }

    @Test func sameFlightCanBeFavoritedByDifferentUsers() throws {
        try makeRepository(owner: "jane").add(Fixtures.flight())
        try makeRepository(owner: "john").add(Fixtures.flight())
        try makeRepository(owner: "jane").remove(flightID: Fixtures.flight().id)

        #expect(try makeRepository(owner: "jane").favorites().isEmpty)
        #expect(try makeRepository(owner: "john").favorites() == [Fixtures.flight()])
    }

    @Test func removingReportsTheFlight() {
        let store = FavoritesStore(repository: makeRepository())
        var removed: [String] = []
        store.onRemove = { removed.append($0) }

        store.toggle(Fixtures.flight())
        #expect(removed.isEmpty)
        store.toggle(Fixtures.flight())
        #expect(removed == [Fixtures.flight().id])
    }

    @Test func storeWithoutRepositoryIsEmpty() {
        let store = FavoritesStore()
        store.toggle(Fixtures.flight())
        #expect(store.flights.isEmpty)
    }

    @Test func favoritesFollowTheSignedInUser() throws {
        let dependencies = AppDependencies(
            modelContainer: container,
            airports: Fixtures.catalog,
            defaults: Fixtures.isolatedDefaults()
        )
        let jane = User(username: "jane", displayName: "Jane", email: "jane@example.com")
        let john = User(username: "john", displayName: "John", email: "john@example.com")

        dependencies.session.signIn(jane)
        dependencies.favorites.toggle(Fixtures.flight())
        dependencies.session.logout()
        #expect(dependencies.favorites.flights.isEmpty)

        dependencies.session.signIn(john)
        #expect(dependencies.favorites.flights.isEmpty)

        dependencies.session.logout()
        dependencies.session.signIn(jane)
        #expect(dependencies.favorites.flights == [Fixtures.flight()])
    }
}

@MainActor
struct PreferenceStoreTests {
    @Test func sessionPersistsUntilLogout() {
        let defaults = Fixtures.isolatedDefaults()
        let user = User(username: "jane", displayName: "Jane", email: "jane@example.com")

        SessionStore(defaults: defaults).signIn(user)
        let restored = SessionStore(defaults: defaults)
        #expect(restored.user == user)

        restored.logout()
        #expect(SessionStore(defaults: defaults).user == nil)
    }

    @Test func themeDefaultsToSystemAndPersists() {
        let defaults = Fixtures.isolatedDefaults()
        let store = ThemeStore(defaults: defaults)
        #expect(store.theme == .system)

        store.theme = .dark
        #expect(ThemeStore(defaults: defaults).theme == .dark)
    }
}
