import Foundation

enum FlightStatus: String, Codable, Sendable, CaseIterable {
    case scheduled
    case boarding
    case delayed
    case departed
    case landed
    case cancelled

    var title: String {
        switch self {
        case .scheduled: "On Time"
        case .boarding: "Boarding"
        case .delayed: "Delayed"
        case .departed: "Departed"
        case .landed: "Landed"
        case .cancelled: "Cancelled"
        }
    }
}

struct Flight: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let flightNumber: String
    let airline: String
    let origin: Airport
    let destination: Airport
    let departure: Date
    let arrival: Date
    let aircraft: String
    let terminal: String
    let gate: String
    var status: FlightStatus

    var duration: TimeInterval { arrival.timeIntervalSince(departure) }

    /// Status as of `now`. The stored `status` is a snapshot from when the flight was
    /// fetched, so a favorite saved days ago would otherwise still read "Boarding".
    /// Only cancelled and delayed are kept from the snapshot.
    func status(at now: Date) -> FlightStatus {
        if status == .cancelled { return .cancelled }
        if now >= arrival { return .landed }
        if now >= departure { return .departed }
        if departure.timeIntervalSince(now) < 45 * 60 { return .boarding }
        return status == .delayed ? .delayed : .scheduled
    }
}
