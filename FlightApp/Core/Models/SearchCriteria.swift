import Foundation

struct SearchCriteria: Codable, Hashable, Sendable {
    let origin: Airport
    let destination: Airport
    let departureDate: Date
    let arrivalDate: Date

    /// Identity used to de-duplicate recent searches: same route on the same days.
    var key: String {
        "\(origin.code)-\(destination.code)-\(Self.dayKey(departureDate))-\(Self.dayKey(arrivalDate))"
    }

    var route: String { "\(origin.code) → \(destination.code)" }

    var dateRange: String {
        let style = Date.FormatStyle.dateTime.day().month(.abbreviated)
        return "\(departureDate.formatted(style)) – \(arrivalDate.formatted(style))"
    }

    /// e.g. "TIA → FCO · 12 Oct – 15 Oct"
    var summary: String { "\(route) · \(dateRange)" }

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
