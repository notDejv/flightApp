import Foundation

protocol FlightService: Sendable {
    func searchFlights(_ criteria: SearchCriteria) async throws -> [Flight]
}

/// Serves generated mock flights for any route, simulating network latency.
struct MockFlightService: FlightService {
    var generator = MockFlightGenerator()
    var latency: Duration = .milliseconds(600)
    var now: @Sendable () -> Date = { .now }

    /// Upper bound on how many days of a date range are searched.
    static let maxDays = 14

    func searchFlights(_ criteria: SearchCriteria) async throws -> [Flight] {
        try await Task.sleep(for: latency)

        let calendar = generator.calendar
        var day = calendar.startOfDay(for: criteria.departureDate)
        let lastDay = calendar.startOfDay(for: criteria.arrivalDate)
        let currentTime = now()

        var flights: [Flight] = []
        var searchedDays = 0
        while day <= lastDay, searchedDays < Self.maxDays {
            flights += generator.flights(
                from: criteria.origin, to: criteria.destination, on: day, now: currentTime
            )
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
            searchedDays += 1
        }
        return flights.sorted { $0.departure < $1.departure }
    }
}
