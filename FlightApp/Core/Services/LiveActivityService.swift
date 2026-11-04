import ActivityKit
import Foundation
import Observation

/// Starts a Live Activity for a favorited flight and simulates status updates locally
/// (a real app would push them via APNs).
@Observable
@MainActor
final class LiveActivityService {
    private(set) var trackedFlightIDs: Set<String> = []
    private var simulations: [String: Task<Void, Never>] = [:]

    /// Pause between simulated status changes.
    var updateInterval: Duration = .seconds(20)

    init() {
        trackedFlightIDs = Set(Activity<FlightActivityAttributes>.activities.map(\.attributes.flightID))
    }

    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func isTracking(_ flight: Flight) -> Bool {
        trackedFlightIDs.contains(flight.id)
    }

    func start(_ flight: Flight) throws {
        guard !isTracking(flight) else { return }

        let attributes = FlightActivityAttributes(
            flightID: flight.id,
            flightNumber: flight.flightNumber,
            airline: flight.airline,
            origin: flight.origin.code,
            destination: flight.destination.code
        )
        let state = Self.state(for: flight, status: flight.status)
        _ = try Activity.request(attributes: attributes, content: ActivityContent(state: state, staleDate: nil))
        trackedFlightIDs.insert(flight.id)
        simulateProgress(for: flight)
    }

    func stop(_ flight: Flight) async {
        simulations.removeValue(forKey: flight.id)?.cancel()
        trackedFlightIDs.remove(flight.id)
        await Self.endActivities(for: flight.id)
    }

    private func simulateProgress(for flight: Flight) {
        let steps = Self.simulatedSteps(after: flight.status)
        guard !steps.isEmpty else { return }

        simulations[flight.id] = Task { [updateInterval] in
            for status in steps {
                try? await Task.sleep(for: updateInterval)
                guard !Task.isCancelled else { return }
                await Self.updateActivities(for: flight.id, state: Self.state(for: flight, status: status))
            }
        }
    }

    /// Remaining lifecycle a flight walks through in the simulation.
    nonisolated static func simulatedSteps(after status: FlightStatus) -> [FlightStatus] {
        switch status {
        case .scheduled, .delayed: [.boarding, .departed, .landed]
        case .boarding: [.departed, .landed]
        case .departed: [.landed]
        case .landed, .cancelled: []
        }
    }

    private static func state(for flight: Flight, status: FlightStatus) -> FlightActivityAttributes.ContentState {
        .init(status: status.title, gate: flight.gate, departure: flight.departure, arrival: flight.arrival)
    }

    // `Activity` isn't Sendable, so it's looked up and used without leaving a nonisolated context.

    private nonisolated static func activities(for flightID: String) -> [Activity<FlightActivityAttributes>] {
        Activity<FlightActivityAttributes>.activities.filter { $0.attributes.flightID == flightID }
    }

    private nonisolated static func updateActivities(
        for flightID: String,
        state: FlightActivityAttributes.ContentState
    ) async {
        for activity in activities(for: flightID) {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    private nonisolated static func endActivities(for flightID: String) async {
        for activity in activities(for: flightID) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
