import SwiftUI

struct FlightDetailsView: View {
    let flight: Flight

    @Environment(FavoritesStore.self) private var favorites
    @Environment(LiveActivityService.self) private var liveActivities
    @State private var liveActivityError: String?

    private var isFavorite: Bool { favorites.isFavorite(flight) }

    var body: some View {
        List {
            Section {
                BoardingPassHeader(flight: flight)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }

            Section("Departure · \(flight.origin.city)") {
                LabeledContent("Airport", value: flight.origin.name)
                LabeledContent("Date", value: flight.departure.formatted(date: .complete, time: .omitted))
                LabeledContent("Time", value: flight.departure.formatted(date: .omitted, time: .shortened))
                LabeledContent("Terminal", value: flight.terminal)
                LabeledContent("Gate", value: flight.gate)
            }
            .cardRows()

            Section("Arrival · \(flight.destination.city)") {
                LabeledContent("Airport", value: flight.destination.name)
                LabeledContent("Date", value: flight.arrival.formatted(date: .complete, time: .omitted))
                LabeledContent("Time", value: flight.arrival.formatted(date: .omitted, time: .shortened))
            }
            .cardRows()

            liveActivitySection
        }
        .listStyle(.insetGrouped)
        .skyBackground()
        .navigationTitle(flight.flightNumber)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                FavoriteButton(isFavorite: isFavorite) { favorites.toggle(flight) }
            }
        }
        .animation(.default, value: isFavorite)
    }

    @ViewBuilder
    private var liveActivitySection: some View {
        if isFavorite {
            Section {
                if liveActivities.isTracking(flight) {
                    Button("Stop Live Activity", systemImage: "stop.circle", role: .destructive) {
                        Task { await liveActivities.stop(flight) }
                    }
                } else {
                    Button("Track on Lock Screen", systemImage: "dot.radiowaves.left.and.right") {
                        startLiveActivity()
                    }
                    .disabled(!liveActivities.areActivitiesEnabled)
                }
                if let liveActivityError {
                    Text(liveActivityError).font(.footnote).foregroundStyle(.red)
                }
            } footer: {
                Text(liveActivities.areActivitiesEnabled
                    ? "Shows this flight's status on the Lock Screen and in the Dynamic Island."
                    : "Live Activities are turned off for this app in Settings.")
            }
            .cardRows()
        } else {
            Section {
            } footer: {
                Text("Add this flight to favorites to track it on the Lock Screen.")
            }
        }
    }

    private func startLiveActivity() {
        do {
            try liveActivities.start(flight)
            liveActivityError = nil
        } catch {
            liveActivityError = error.localizedDescription
        }
    }
}
