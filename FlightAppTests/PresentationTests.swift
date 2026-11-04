import Foundation
import Testing
@testable import FlightApp

struct FlightTimelineTests {
    let flight = Fixtures.flight() // 08:00 → 09:30 on the fixture day

    @Test func upcomingCountsDownToDeparture() {
        let now = flight.departure.addingTimeInterval(-(2 * 3600 + 15 * 60))
        let timeline = FlightTimeline(flight: flight, now: now)

        #expect(timeline == .upcoming(departsIn: 2 * 3600 + 15 * 60))
        #expect(timeline.summary == "Departs in 2h 15m")
        #expect(timeline.progress == 0)
    }

    @Test func inAirReportsProgressAndTimeToLanding() {
        let now = flight.departure.addingTimeInterval(45 * 60) // halfway through 90 minutes
        let timeline = FlightTimeline(flight: flight, now: now)

        #expect(timeline.progress == 0.5)
        #expect(timeline.summary == "In the air · lands in 45m")
    }

    @Test func landedAfterArrival() {
        let timeline = FlightTimeline(flight: flight, now: flight.arrival.addingTimeInterval(3 * 86400))
        #expect(timeline.progress == 1)
        #expect(timeline.summary == "Landed 3d ago")
    }

    @Test func cancelledWinsOverTimes() {
        var cancelled = flight
        cancelled.status = .cancelled
        #expect(FlightTimeline(flight: cancelled, now: flight.departure) == .cancelled)
    }

    @Test func storedStatusDoesNotOverrideTime() {
        // Saved as "scheduled" but the clock has moved past arrival.
        #expect(FlightTimeline(flight: flight, now: flight.arrival.addingTimeInterval(60)).progress == 1)
    }

    @Test(arguments: [
        (30.0, "1m"), (9 * 60.0, "9m"), (3600.0, "1h"), (26 * 3600.0, "1d 2h"), (2 * 86400.0, "2d"),
    ])
    func compactDurations(interval: TimeInterval, expected: String) {
        #expect(FlightTimeline.compact(interval) == expected)
    }
}

struct GreetingTests {
    func date(hour: Int) -> Date {
        Fixtures.utcCalendar.date(bySettingHour: hour, minute: 0, second: 0, of: Fixtures.day)!
    }

    @Test(arguments: [(7, "Good morning"), (13, "Good afternoon"), (19, "Good evening"), (2, "Hey, night owl")])
    func followsTimeOfDay(hour: Int, expected: String) {
        #expect(Greeting(date: date(hour: hour), calendar: Fixtures.utcCalendar).text == expected)
    }

    @Test func usesFirstName() {
        let user = User(username: "jane.doe", displayName: "Jane Doe", email: "jane.doe@example.com")
        let greeting = Greeting(date: date(hour: 8), calendar: Fixtures.utcCalendar)
        #expect(greeting.message(for: user) == "Good morning, Jane ☀️")
    }
}
