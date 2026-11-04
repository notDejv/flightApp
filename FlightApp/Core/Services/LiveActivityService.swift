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
        // Updates are simulated in-process, so activities left over from a previous
        // launch would stay frozen. End them instead of showing stale status.
        Task { await Self.endAllActivities() }
    }

    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func isTracking(_ flight: Flight) -> Bool {
        trackedFlightIDs.contains(flight.id)
    }

    func start(_ flight: Flight) throws {
        guard !isTracking(flight) else { return }

        let status = flight.status(at: .now)
        let attributes = FlightActivityAttributes(
            flightID: flight.id,
            flightNumber: flight.flightNumber,
            airline: flight.airline,
            origin: flight.origin.code,
            destination: flight.destination.code
        )
        let state = Self.state(for: flight, status: status)
        _ = try Activity.request(attributes: attributes, content: ActivityContent(state: state, staleDate: nil))
        trackedFlightIDs.insert(flight.id)
        simulateProgress(for: flight, from: status)
        watchForDismissal(of: flight.id)
    }

    func stop(_ flight: Flight) async {
        await stop(flightID: flight.id)
    }

    func stop(flightID: String) async {
        guard trackedFlightIDs.contains(flightID) else { return }
        forget(flightID)
        await Self.endActivities(for: flightID)
    }

    /// Ends every activity, e.g. on logout so the next user doesn't see them.
    func stopAll() async {
        simulations.values.forEach { $0.cancel() }
        simulations = [:]
        trackedFlightIDs = []
        await Self.endAllActivities()
    }

    private func forget(_ flightID: String) {
        simulations.removeValue(forKey: flightID)?.cancel()
        trackedFlightIDs.remove(flightID)
    }

    private func simulateProgress(for flight: Flight, from status: FlightStatus) {
        let steps = Self.simulatedSteps(after: status)
        guard !steps.isEmpty else { return }

        simulations[flight.id] = Task { [updateInterval] in
            for status in steps {
                try? await Task.sleep(for: updateInterval)
                guard !Task.isCancelled else { return }
                await Self.updateActivities(for: flight.id, state: Self.state(for: flight, status: status))
            }
        }
    }

    /// The user can swipe an activity away on the Lock Screen, and the system ends
    /// long-running ones. Either way the button should go back to "Track".
    private func watchForDismissal(of flightID: String) {
        Task { [weak self] in
            await Self.waitUntilEnded(flightID: flightID)
            self?.forget(flightID)
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

    private nonisolated static func endAllActivities() async {
        for activity in Activity<FlightActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private nonisolated static func waitUntilEnded(flightID: String) async {
        guard let activity = activities(for: flightID).first else { return }
        for await state in activity.activityStateUpdates where state == .ended || state == .dismissed {
            return
        }
    }
}
