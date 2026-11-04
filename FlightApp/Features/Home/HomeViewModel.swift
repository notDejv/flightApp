import Foundation
import Observation

enum AirportField: Hashable {
    case origin
    case destination
}

@Observable
@MainActor
final class HomeViewModel {
    private(set) var origin: Airport?
    private(set) var destination: Airport?
    private(set) var originQuery = ""
    private(set) var destinationQuery = ""

    var departureDate: Date {
        didSet {
            if arrivalDate < departureDate { arrivalDate = departureDate }
        }
    }
    var arrivalDate: Date

    private(set) var recentSearches: [SearchCriteria] = []
    private(set) var errorMessage: String?

    private let airports: AirportCatalog
    private let repository: RecentSearchRepository
    private let calendar: Calendar

    init(
        airports: AirportCatalog,
        repository: RecentSearchRepository,
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        self.airports = airports
        self.repository = repository
        self.calendar = calendar
        let today = calendar.startOfDay(for: now)
        departureDate = today
        arrivalDate = calendar.date(byAdding: .day, value: 3, to: today) ?? today
        loadRecentSearches()
    }

    // MARK: Airport fields

    func query(for field: AirportField) -> String {
        field == .origin ? originQuery : destinationQuery
    }

    func selection(for field: AirportField) -> Airport? {
        field == .origin ? origin : destination
    }

    /// Typing into a field clears its selection until a suggestion is picked again.
    func updateQuery(_ text: String, for field: AirportField) {
        switch field {
        case .origin:
            originQuery = text
            if origin?.displayName != text { origin = nil }
        case .destination:
            destinationQuery = text
            if destination?.displayName != text { destination = nil }
        }
    }

    func suggestions(for field: AirportField) -> [Airport] {
        guard selection(for: field) == nil else { return [] }
        return airports.search(query(for: field), limit: 6)
    }

    func select(_ airport: Airport, for field: AirportField) {
        switch field {
        case .origin:
            origin = airport
            originQuery = airport.displayName
        case .destination:
            destination = airport
            destinationQuery = airport.displayName
        }
    }

    func swapAirports() {
        (origin, destination) = (destination, origin)
        (originQuery, destinationQuery) = (destinationQuery, originQuery)
    }

    // MARK: Validation

    var validationMessage: String? {
        if let origin, let destination, origin.code == destination.code {
            return "Origin and destination cannot be the same."
        }
        if calendar.startOfDay(for: arrivalDate) < calendar.startOfDay(for: departureDate) {
            return "Arrival date can't be before the departure date."
        }
        return nil
    }

    var canSearch: Bool {
        origin != nil && destination != nil && validationMessage == nil
    }

    // MARK: Search

    /// Validates the form, records it as a recent search and returns the criteria to navigate to.
    func search() -> SearchCriteria? {
        guard canSearch, let origin, let destination else { return nil }
        let criteria = SearchCriteria(
            origin: origin,
            destination: destination,
            departureDate: calendar.startOfDay(for: departureDate),
            arrivalDate: calendar.startOfDay(for: arrivalDate)
        )
        do {
            try repository.save(criteria)
            errorMessage = nil
        } catch {
            // Saving history must not block the search itself.
            errorMessage = "Couldn't save this search: \(error.localizedDescription)"
        }
        loadRecentSearches()
        return criteria
    }

    func prefill(with criteria: SearchCriteria) {
        select(criteria.origin, for: .origin)
        select(criteria.destination, for: .destination)
        departureDate = criteria.departureDate
        arrivalDate = criteria.arrivalDate
    }

    func loadRecentSearches() {
        do {
            recentSearches = try repository.recentSearches()
        } catch {
            errorMessage = "Couldn't load recent searches: \(error.localizedDescription)"
        }
    }
}
