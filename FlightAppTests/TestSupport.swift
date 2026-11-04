import Foundation
import SwiftData
@testable import FlightApp

enum Fixtures {
    static let tirana = Airport(code: "TIA", city: "Tirana", name: "Tirana International", country: "Albania")
    static let rome = Airport(code: "FCO", city: "Rome", name: "Fiumicino", country: "Italy")
    static let milan = Airport(code: "MXP", city: "Milan", name: "Malpensa", country: "Italy")
    static let vienna = Airport(code: "VIE", city: "Vienna", name: "Vienna International", country: "Austria")

    static let catalog = StaticAirportCatalog(airports: [tirana, rome, milan, vienna])

    static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// 2026-10-12 00:00 UTC
    static let day = Date(timeIntervalSince1970: 1_791_763_200)

    static func date(daysAfter offset: Int, from base: Date = day) -> Date {
        utcCalendar.date(byAdding: .day, value: offset, to: base)!
    }

    static func criteria(
        _ origin: Airport = tirana,
        _ destination: Airport = rome,
        departure: Date = day,
        arrival: Date = date(daysAfter: 3)
    ) -> SearchCriteria {
        SearchCriteria(origin: origin, destination: destination, departureDate: departure, arrivalDate: arrival)
    }

    static func flight(id: String = "TIAFCO-AZ510-20261012") -> Flight {
        Flight(
            id: id,
            flightNumber: "AZ 510",
            airline: "ITA Airways",
            origin: tirana,
            destination: rome,
            departure: day.addingTimeInterval(8 * 3600),
            arrival: day.addingTimeInterval(9.5 * 3600),
            aircraft: "Airbus A320neo",
            terminal: "1",
            gate: "B12",
            status: .scheduled
        )
    }

    @MainActor
    static func inMemoryContainer() throws -> ModelContainer {
        try PersistenceStack.makeContainer(inMemory: true)
    }

    static func isolatedDefaults() -> UserDefaults {
        let suite = "tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}

/// Hands out increasing timestamps so "newest first" ordering is deterministic.
@MainActor
final class TestClock {
    private var current: Date

    init(start: Date = Fixtures.day) { current = start }

    func tick() -> Date {
        current = current.addingTimeInterval(1)
        return current
    }
}

struct FailingFlightService: FlightService {
    struct Failure: LocalizedError {
        var errorDescription: String? { "Network unavailable" }
    }

    func searchFlights(_ criteria: SearchCriteria) async throws -> [Flight] {
        throw Failure()
    }
}

/// Succeeds on the first search, then fails, like a connection dropping mid-session.
actor FlakyFlightService: FlightService {
    private var calls = 0

    func searchFlights(_ criteria: SearchCriteria) async throws -> [Flight] {
        calls += 1
        if calls > 1 { throw FailingFlightService.Failure() }
        return [Fixtures.flight()]
    }
}
