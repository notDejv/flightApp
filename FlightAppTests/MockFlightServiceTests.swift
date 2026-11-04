import Foundation
import Testing
@testable import FlightApp

struct MockFlightGeneratorTests {
    let generator = MockFlightGenerator(calendar: Fixtures.utcCalendar)

    @Test func sameRouteAndDayProduceSameFlights() {
        let first = generator.flights(from: Fixtures.tirana, to: Fixtures.rome, on: Fixtures.day, now: Fixtures.day)
        let second = generator.flights(from: Fixtures.tirana, to: Fixtures.rome, on: Fixtures.day, now: Fixtures.day)
        #expect(first == second)
        #expect(!first.isEmpty)
    }

    @Test func flightsMatchRouteDayAndAreSorted() {
        let flights = generator.flights(from: Fixtures.tirana, to: Fixtures.rome, on: Fixtures.day, now: Fixtures.day)
        let nextDay = Fixtures.date(daysAfter: 1)

        #expect(flights.allSatisfy { $0.origin == Fixtures.tirana && $0.destination == Fixtures.rome })
        #expect(flights.allSatisfy { $0.departure >= Fixtures.day && $0.departure < nextDay })
        #expect(flights.allSatisfy { $0.arrival > $0.departure })
        #expect(flights.map(\.departure) == flights.map(\.departure).sorted())
        #expect(Set(flights.map(\.id)).count == flights.count)
    }

    @Test func routeDurationIsSymmetric() {
        #expect(
            MockFlightGenerator.routeDuration(Fixtures.tirana, Fixtures.rome)
                == MockFlightGenerator.routeDuration(Fixtures.rome, Fixtures.tirana)
        )
    }

    @Test(arguments: [
        (hoursFromNow: -3.0, roll: 0.5, expected: FlightStatus.landed),
        (hoursFromNow: -0.5, roll: 0.5, expected: .departed),
        (hoursFromNow: 0.5, roll: 0.5, expected: .boarding),
        (hoursFromNow: 5.0, roll: 0.10, expected: .delayed),
        (hoursFromNow: 5.0, roll: 0.5, expected: .scheduled),
        (hoursFromNow: 5.0, roll: 0.01, expected: .cancelled),
    ])
    func statusFollowsTimeline(hoursFromNow: Double, roll: Double, expected: FlightStatus) {
        let now = Fixtures.day
        let departure = now.addingTimeInterval(hoursFromNow * 3600)
        let arrival = departure.addingTimeInterval(2 * 3600)
        #expect(MockFlightGenerator.status(departure: departure, arrival: arrival, now: now, roll: roll) == expected)
    }
}

struct MockFlightServiceTests {
    let service = MockFlightService(
        generator: MockFlightGenerator(calendar: Fixtures.utcCalendar),
        latency: .zero,
        now: { Fixtures.day }
    )

    @Test func returnsFlightsForEveryDayInRange() async throws {
        let flights = try await service.searchFlights(Fixtures.criteria(arrival: Fixtures.date(daysAfter: 2)))
        let days = Set(flights.map { Fixtures.utcCalendar.startOfDay(for: $0.departure) })

        #expect(days == [Fixtures.day, Fixtures.date(daysAfter: 1), Fixtures.date(daysAfter: 2)])
        #expect(flights.map(\.departure) == flights.map(\.departure).sorted())
    }

    @Test func sameDayRangeSearchesOneDay() async throws {
        let flights = try await service.searchFlights(Fixtures.criteria(arrival: Fixtures.day))
        #expect(flights.allSatisfy { Fixtures.utcCalendar.isDate($0.departure, inSameDayAs: Fixtures.day) })
    }

    @Test func rangeIsCappedAtMaxDays() async throws {
        let flights = try await service.searchFlights(Fixtures.criteria(arrival: Fixtures.date(daysAfter: 60)))
        let days = Set(flights.map { Fixtures.utcCalendar.startOfDay(for: $0.departure) })
        #expect(days.count == MockFlightService.maxDays)
    }
}
