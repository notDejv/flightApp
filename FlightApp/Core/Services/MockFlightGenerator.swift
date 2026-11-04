import Foundation

/// Deterministically generates a schedule for a route and day.
///
/// The same route and day always yield the same flights (and ids), so favorites
/// keep matching search results across launches.
struct MockFlightGenerator: Sendable {
    struct Airline: Sendable {
        let code: String
        let name: String
    }

    static let airlines: [Airline] = [
        Airline(code: "AZ", name: "ITA Airways"),
        Airline(code: "W6", name: "Wizz Air"),
        Airline(code: "FR", name: "Ryanair"),
        Airline(code: "LH", name: "Lufthansa"),
        Airline(code: "TK", name: "Turkish Airlines"),
        Airline(code: "OS", name: "Austrian Airlines"),
        Airline(code: "A3", name: "Aegean Airlines"),
        Airline(code: "U2", name: "easyJet"),
        Airline(code: "AF", name: "Air France"),
        Airline(code: "BA", name: "British Airways"),
    ]

    static let aircraft = [
        "Airbus A320neo", "Airbus A321neo", "Airbus A220-300",
        "Boeing 737-800", "Boeing 737 MAX 8", "Embraer E195-E2", "ATR 72-600",
    ]

    var calendar: Calendar = .current

    func flights(from origin: Airport, to destination: Airport, on day: Date, now: Date) -> [Flight] {
        let dayStart = calendar.startOfDay(for: day)
        let dayKey = SearchCriteria.dayKey(dayStart, calendar: calendar)
        var rng = SplitMix64(seed: Self.stableHash("\(origin.code)-\(destination.code)-\(dayKey)"))
        let routeMinutes = Self.routeDuration(origin, destination)

        var flights: [Flight] = []
        var usedNumbers = Set<String>()
        let count = Int.random(in: 2...4, using: &rng)

        for _ in 0..<count {
            let airline = Self.airlines[Int.random(in: 0..<Self.airlines.count, using: &rng)]
            let number = "\(airline.code) \(Int.random(in: 100...2999, using: &rng))"
            guard usedNumbers.insert(number).inserted else { continue }

            let minutesFromMidnight = Int.random(in: 6...21, using: &rng) * 60
                + [0, 15, 30, 45][Int.random(in: 0..<4, using: &rng)]
            let durationMinutes = routeMinutes + Int.random(in: -10...15, using: &rng)
            guard
                let departure = calendar.date(byAdding: .minute, value: minutesFromMidnight, to: dayStart),
                let arrival = calendar.date(byAdding: .minute, value: durationMinutes, to: departure)
            else { continue }

            let gateLetter = ["A", "B", "C", "D"][Int.random(in: 0..<4, using: &rng)]
            let roll = Double.random(in: 0..<1, using: &rng)

            flights.append(Flight(
                id: "\(origin.code)\(destination.code)-\(number.replacingOccurrences(of: " ", with: ""))-\(dayKey)",
                flightNumber: number,
                airline: airline.name,
                origin: origin,
                destination: destination,
                departure: departure,
                arrival: arrival,
                aircraft: Self.aircraft[Int.random(in: 0..<Self.aircraft.count, using: &rng)],
                terminal: "\(Int.random(in: 1...3, using: &rng))",
                gate: "\(gateLetter)\(Int.random(in: 1...30, using: &rng))",
                status: Self.status(departure: departure, arrival: arrival, now: now, roll: roll)
            ))
        }
        return flights.sorted { $0.departure < $1.departure }
    }

    static func status(departure: Date, arrival: Date, now: Date, roll: Double) -> FlightStatus {
        if roll < 0.06 { return .cancelled }
        if now >= arrival { return .landed }
        if now >= departure { return .departed }
        if departure.timeIntervalSince(now) < 45 * 60 { return .boarding }
        if roll < 0.18 { return .delayed }
        return .scheduled
    }

    /// Base block time for a route, symmetric in both directions (60–210 min).
    static func routeDuration(_ a: Airport, _ b: Airport) -> Int {
        let pair = [a.code, b.code].sorted().joined(separator: "-")
        return 60 + Int(stableHash(pair) % 150)
    }

    /// FNV-1a. `String.hashValue` is randomized per launch, so it can't be used here.
    static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01b3
        }
        return hash
    }
}

struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
