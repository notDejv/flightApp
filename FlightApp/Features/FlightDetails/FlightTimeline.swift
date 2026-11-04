import Foundation

/// Where a flight is right now, derived from its times so a favorite saved days ago
/// still reads correctly. Only "cancelled" comes from the stored status.
enum FlightTimeline: Equatable {
    case cancelled
    case upcoming(departsIn: TimeInterval)
    case inAir(landsIn: TimeInterval, progress: Double)
    case landed(ago: TimeInterval)

    init(flight: Flight, now: Date) {
        if flight.status == .cancelled {
            self = .cancelled
        } else if now < flight.departure {
            self = .upcoming(departsIn: flight.departure.timeIntervalSince(now))
        } else if now < flight.arrival {
            let elapsed = now.timeIntervalSince(flight.departure) / flight.duration
            self = .inAir(landsIn: flight.arrival.timeIntervalSince(now), progress: elapsed)
        } else {
            self = .landed(ago: now.timeIntervalSince(flight.arrival))
        }
    }

    /// 0 at the gate, 1 at arrival. Kept slightly off the ends while flying so the
    /// plane never looks parked.
    var progress: Double {
        switch self {
        case .cancelled, .upcoming: 0
        case .inAir(_, let progress): min(max(progress, 0.05), 0.95)
        case .landed: 1
        }
    }

    var summary: String {
        switch self {
        case .cancelled: "This flight was cancelled"
        case .upcoming(let interval): "Departs in \(Self.compact(interval))"
        case .inAir(let interval, _): "In the air · lands in \(Self.compact(interval))"
        case .landed(let interval): "Landed \(Self.compact(interval)) ago"
        }
    }

    var symbol: String {
        switch self {
        case .cancelled: "xmark.circle"
        case .upcoming: "clock"
        case .inAir: "airplane"
        case .landed: "checkmark.circle"
        }
    }

    /// Two largest units, e.g. "3d 4h", "2h 15m", "9m". Under a minute reads "1m".
    static func compact(_ interval: TimeInterval) -> String {
        let minutes = max(Int(interval / 60), 1)
        let days = minutes / 1440
        let hours = (minutes % 1440) / 60
        let mins = minutes % 60
        if days > 0 { return hours > 0 ? "\(days)d \(hours)h" : "\(days)d" }
        if hours > 0 { return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h" }
        return "\(mins)m"
    }
}
