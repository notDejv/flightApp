import Foundation
import Observation

@Observable
@MainActor
final class SearchResultsViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    let criteria: SearchCriteria
    private(set) var flights: [Flight] = []
    private(set) var state: State = .idle
    /// Set when a refresh fails while results are already on screen; those results stay.
    var refreshError: String?

    private let flightService: FlightService
    private let calendar: Calendar

    init(criteria: SearchCriteria, flightService: FlightService, calendar: Calendar = .current) {
        self.criteria = criteria
        self.flightService = flightService
        self.calendar = calendar
    }

    /// Results grouped by departure day, in order.
    var flightsByDay: [(day: Date, flights: [Flight])] {
        let groups = Dictionary(grouping: flights) { calendar.startOfDay(for: $0.departure) }
        return groups.keys.sorted().map { ($0, groups[$0] ?? []) }
    }

    /// First load only; later loads go through `refresh()`.
    func load() async {
        guard state == .idle else { return }
        state = .loading
        await fetch()
    }

    /// Pull-to-refresh, or Try Again after a failure (which shows the loader again).
    func refresh() async {
        if case .failed = state { state = .loading }
        await fetch()
    }

    private func fetch() async {
        do {
            flights = try await flightService.searchFlights(criteria)
            state = .loaded
            refreshError = nil
        } catch is CancellationError {
            if state == .loading { state = .idle }
        } catch {
            if state == .loaded {
                refreshError = error.localizedDescription
            } else {
                state = .failed(error.localizedDescription)
            }
        }
    }
}
