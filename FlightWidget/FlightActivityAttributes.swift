import ActivityKit
import Foundation

/// Shared between the app (which starts and updates the activity) and the widget
/// extension (which renders it). Compiled into both targets.
struct FlightActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: String
        var gate: String
        var departure: Date
        var arrival: Date
    }

    var flightID: String
    var flightNumber: String
    var airline: String
    var origin: String
    var destination: String
}
