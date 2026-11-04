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

    /// Keeps arrival inside `arrivalRange` when departure moves.
    var departureDate: Date {
        didSet {
            arrivalDate = min(max(arrivalDate, arrivalRange.lowerBound), arrivalRange.upperBound)
        }
    }
    var arrivalDate: Date

    private(set) var recentSearches: [SearchCriteria] = []
    private(set) var errorMessage: String?

    private let airports: AirportCatalog
    private let repository: RecentSearchRepository
    private let calendar: Calendar
    private let now: () -> Date

    init(
        airports: AirportCatalog,
        repository: RecentSearchRepository,
        now: @escaping () -> Date = { .now },
        calendar: Calendar = .current
    ) {
        self.airports = airports
        self.repository = repository
        self.calendar = calendar
        self.now = now
        let today = calendar.startOfDay(for: now())
        departureDate = today
        arrivalDate = calendar.date(byAdding: .day, value: 3, to: today) ?? today
    }

    // MARK: Dates

    /// Today, read each time so a form left open overnight doesn't allow yesterday.
    var earliestDeparture: Date {
        calendar.startOfDay(for: now())
    }

    /// From the departure day to the last day a search covers.
    var arrivalRange: ClosedRange<Date> {
        let start = calendar.startOfDay(for: departureDate)
        let end = calendar.date(byAdding: .day, value: SearchCriteria.maxDays - 1, to: start) ?? start
        return start...end
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
        if calendar.startOfDay(for: departureDate) < earliestDeparture {
            return "Departure date can't be in the past."
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

    /// Restores a recent search. Dates that are now in the past move to today,
    /// keeping the trip's length.
    func prefill(with criteria: SearchCriteria) {
        select(criteria.origin, for: .origin)
        select(criteria.destination, for: .destination)
        let tripDays = calendar.dateComponents([.day], from: criteria.departureDate, to: criteria.arrivalDate).day ?? 0
        departureDate = max(criteria.departureDate, earliestDeparture)
        let arrival = calendar.date(byAdding: .day, value: tripDays, to: departureDate) ?? departureDate
        arrivalDate = min(max(arrival, arrivalRange.lowerBound), arrivalRange.upperBound)
    }

    func loadRecentSearches() {
        do {
            recentSearches = try repository.recentSearches()
        } catch {
            errorMessage = "Couldn't load recent searches: \(error.localizedDescription)"
        }
    }
}
