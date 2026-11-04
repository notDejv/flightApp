import Foundation
import SwiftData
import Testing
@testable import FlightApp

@MainActor
struct HomeViewModelTests {
    let container: ModelContainer
    let repository: SwiftDataRecentSearchRepository
    let viewModel: HomeViewModel

    init() throws {
        container = try Fixtures.inMemoryContainer()
        let clock = TestClock()
        repository = SwiftDataRecentSearchRepository(context: container.mainContext, ownerID: "jane", now: clock.tick)
        viewModel = HomeViewModel(
            airports: Fixtures.catalog,
            repository: repository,
            now: { Fixtures.day },
            calendar: Fixtures.utcCalendar
        )
    }

    @Test func cannotSearchUntilBothAirportsChosen() {
        #expect(!viewModel.canSearch)
        viewModel.select(Fixtures.tirana, for: .origin)
        #expect(!viewModel.canSearch)
        viewModel.select(Fixtures.rome, for: .destination)
        #expect(viewModel.canSearch)
    }

    @Test func originAndDestinationCannotMatch() {
        viewModel.select(Fixtures.tirana, for: .origin)
        viewModel.select(Fixtures.tirana, for: .destination)

        #expect(viewModel.validationMessage == "Origin and destination cannot be the same.")
        #expect(!viewModel.canSearch)
        #expect(viewModel.search() == nil)
    }

    @Test func movingDepartureAfterArrivalPushesArrival() {
        viewModel.departureDate = Fixtures.date(daysAfter: 10)
        #expect(viewModel.arrivalDate == viewModel.departureDate)
    }

    @Test func typingClearsSelectionAndShowsSuggestions() {
        viewModel.select(Fixtures.tirana, for: .origin)
        #expect(viewModel.suggestions(for: .origin).isEmpty)

        viewModel.updateQuery("Rom", for: .origin)
        #expect(viewModel.selection(for: .origin) == nil)
        #expect(viewModel.suggestions(for: .origin) == [Fixtures.rome])
    }

    @Test func searchSavesRecentAndReturnsCriteria() throws {
        viewModel.select(Fixtures.tirana, for: .origin)
        viewModel.select(Fixtures.rome, for: .destination)

        let criteria = try #require(viewModel.search())
        #expect(criteria.route == "TIA → FCO")
        #expect(viewModel.recentSearches == [criteria])
        #expect(try repository.recentSearches() == [criteria])
    }

    @Test func prefillRestoresForm() {
        let criteria = Fixtures.criteria(
            Fixtures.milan, Fixtures.vienna,
            departure: Fixtures.date(daysAfter: 5),
            arrival: Fixtures.date(daysAfter: 7)
        )
        viewModel.prefill(with: criteria)

        #expect(viewModel.origin == Fixtures.milan)
        #expect(viewModel.destination == Fixtures.vienna)
        #expect(viewModel.query(for: .origin) == Fixtures.milan.displayName)
        #expect(viewModel.departureDate == criteria.departureDate)
        #expect(viewModel.arrivalDate == criteria.arrivalDate)
    }

    @Test func pastDepartureIsRejected() {
        viewModel.select(Fixtures.tirana, for: .origin)
        viewModel.select(Fixtures.rome, for: .destination)
        viewModel.departureDate = Fixtures.date(daysAfter: -1)

        #expect(viewModel.validationMessage == "Departure date can't be in the past.")
        #expect(!viewModel.canSearch)
    }

    @Test func prefillMovesPastTripToTodayKeepingLength() {
        let lastMonth = Fixtures.criteria(
            departure: Fixtures.date(daysAfter: -30),
            arrival: Fixtures.date(daysAfter: -28)
        )
        viewModel.prefill(with: lastMonth)

        #expect(viewModel.departureDate == Fixtures.day)
        #expect(viewModel.arrivalDate == Fixtures.date(daysAfter: 2))
        #expect(viewModel.validationMessage == nil)
    }

    @Test func arrivalStaysWithinSearchableRange() {
        #expect(viewModel.arrivalRange.upperBound == Fixtures.date(daysAfter: SearchCriteria.maxDays - 1))

        // Moving departure earlier pulls a long trip back inside the 14 days.
        viewModel.departureDate = Fixtures.date(daysAfter: 5)
        viewModel.arrivalDate = Fixtures.date(daysAfter: 18)
        viewModel.departureDate = Fixtures.day
        #expect(viewModel.arrivalDate == Fixtures.date(daysAfter: 13))
    }

    @Test func swapExchangesAirports() {
        viewModel.select(Fixtures.tirana, for: .origin)
        viewModel.select(Fixtures.rome, for: .destination)
        viewModel.swapAirports()

        #expect(viewModel.origin == Fixtures.rome)
        #expect(viewModel.destination == Fixtures.tirana)
        #expect(viewModel.query(for: .origin) == Fixtures.rome.displayName)
    }
}

@MainActor
struct SearchResultsViewModelTests {
    @Test func loadsAndGroupsFlightsByDay() async {
        let service = MockFlightService(
            generator: MockFlightGenerator(calendar: Fixtures.utcCalendar),
            latency: .zero,
            now: { Fixtures.day }
        )
        let viewModel = SearchResultsViewModel(
            criteria: Fixtures.criteria(arrival: Fixtures.date(daysAfter: 1)),
            flightService: service,
            calendar: Fixtures.utcCalendar
        )

        await viewModel.load()

        #expect(viewModel.state == .loaded)
        #expect(!viewModel.flights.isEmpty)
        #expect(viewModel.flightsByDay.map(\.day) == [Fixtures.day, Fixtures.date(daysAfter: 1)])
        #expect(viewModel.flightsByDay.flatMap(\.flights) == viewModel.flights)
    }

    @Test func reportsFailure() async {
        let viewModel = SearchResultsViewModel(criteria: Fixtures.criteria(), flightService: FailingFlightService())
        await viewModel.load()
        #expect(viewModel.state == .failed("Network unavailable"))
    }

    @Test func failedRefreshKeepsLoadedResults() async {
        let viewModel = SearchResultsViewModel(criteria: Fixtures.criteria(), flightService: FlakyFlightService())
        await viewModel.load()
        await viewModel.refresh()

        #expect(viewModel.state == .loaded)
        #expect(viewModel.flights == [Fixtures.flight()])
        #expect(viewModel.refreshError == "Network unavailable")
    }
}

@MainActor
struct LoginViewModelTests {
    let session = SessionStore(defaults: Fixtures.isolatedDefaults())

    func makeViewModel() -> LoginViewModel {
        LoginViewModel(authService: MockAuthService(latency: .zero), session: session)
    }

    @Test func requiresBothFields() {
        let viewModel = makeViewModel()
        #expect(!viewModel.canSubmit)
        viewModel.username = "jane"
        #expect(!viewModel.canSubmit)
        viewModel.password = "secret"
        #expect(viewModel.canSubmit)
    }

    @Test func shortPasswordShowsError() async {
        let viewModel = makeViewModel()
        viewModel.username = "jane"
        viewModel.password = "abc"

        await viewModel.login()

        #expect(viewModel.errorMessage == AuthError.passwordTooShort(minimum: 4).errorDescription)
        #expect(!session.isLoggedIn)
    }

    @Test func validLoginSignsIn() async {
        let viewModel = makeViewModel()
        viewModel.username = "jane.doe@example.com"
        viewModel.password = "secret"

        await viewModel.login()

        #expect(session.user?.displayName == "Jane Doe")
        #expect(session.user?.email == "jane.doe@example.com")
    }

    @Test func usernameOfOnlyAtSignsDoesNotCrash() async throws {
        let user = try await MockAuthService(latency: .zero).login(username: "@@", password: "secret")
        #expect(user.displayName == "@@")
    }
}

struct FlightStatusTests {
    let flight = Fixtures.flight() // departs 08:00, lands 09:30 on Fixtures.day

    @Test func statusFollowsTheClock() {
        #expect(flight.status(at: Fixtures.day) == .scheduled)
        #expect(flight.status(at: Fixtures.day.addingTimeInterval(7.5 * 3600)) == .boarding)
        #expect(flight.status(at: Fixtures.day.addingTimeInterval(9 * 3600)) == .departed)
        #expect(flight.status(at: Fixtures.date(daysAfter: 3)) == .landed)
    }

    @Test func cancelledStaysCancelled() {
        var cancelled = flight
        cancelled.status = .cancelled
        #expect(cancelled.status(at: Fixtures.date(daysAfter: 3)) == .cancelled)
    }
}

struct LiveActivitySimulationTests {
    @Test func walksRemainingLifecycle() {
        #expect(LiveActivityService.simulatedSteps(after: .scheduled) == [.boarding, .departed, .landed])
        #expect(LiveActivityService.simulatedSteps(after: .departed) == [.landed])
        #expect(LiveActivityService.simulatedSteps(after: .cancelled).isEmpty)
    }
}
