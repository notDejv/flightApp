import SwiftUI

/// Flight card used in search results and favorites. `accessory` sits top-right
/// (e.g. a favorite button).
struct FlightRow<Accessory: View>: View {
    let flight: Flight
    @ViewBuilder var accessory: Accessory

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(flight.flightNumber)
                        .font(.headline.monospaced())
                    Text(flight.airline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                accessory
            }

            HStack(alignment: .center) {
                endpoint(time: flight.departure, code: flight.origin.code, alignment: .leading)
                RouteLine(duration: flight.duration)
                endpoint(time: flight.arrival, code: flight.destination.code, alignment: .trailing)
            }

            StatusBadge(status: flight.status)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private func endpoint(time: Date, code: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(time, format: .dateTime.hour().minute())
                .font(.title3.weight(.semibold).monospacedDigit())
            Text(code)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

extension FlightRow where Accessory == EmptyView {
    init(flight: Flight) {
        self.init(flight: flight) { EmptyView() }
    }
}

struct RouteLine: View {
    let duration: TimeInterval

    var body: some View {
        VStack(spacing: 4) {
            Text(Duration.seconds(duration), format: .units(allowed: [.hours, .minutes], width: .narrow))
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Circle().frame(width: 5, height: 5)
                Rectangle().frame(height: 1)
                Image(systemName: "airplane").font(.caption)
                Rectangle().frame(height: 1)
                Circle().frame(width: 5, height: 5)
            }
            .foregroundStyle(.tint.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }
}

struct StatusBadge: View {
    let status: FlightStatus

    var body: some View {
        Label(status.title, systemImage: status.symbol)
            .font(.caption.weight(.bold))
            .labelStyle(BadgeLabelStyle())
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .foregroundStyle(status.color)
            .background(status.color.opacity(0.15), in: .capsule)
    }
}

private struct BadgeLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
    }
}

extension FlightStatus {
    var symbol: String {
        switch self {
        case .scheduled: "checkmark.circle.fill"
        case .boarding: "figure.walk"
        case .delayed: "clock.badge.exclamationmark"
        case .departed: "airplane.departure"
        case .landed: "airplane.arrival"
        case .cancelled: "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .scheduled: .green
        case .boarding: .blue
        case .delayed: .orange
        case .departed, .landed: Palette.accent
        case .cancelled: .red
        }
    }
}

struct FavoriteButton: View {
    let isFavorite: Bool
    let action: () -> Void

    @State private var bursts = 0

    var body: some View {
        Button(action: action) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.title3)
                .foregroundStyle(isFavorite ? .pink : .secondary)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: isFavorite)
                .frame(width: 44, height: 44)
                .overlay { HeartBurst(trigger: bursts) }
                .contentShape(.rect)
        }
        .buttonStyle(.borderless)
        .onChange(of: isFavorite) { _, isNowFavorite in
            if isNowFavorite { bursts += 1 }
        }
        .sensoryFeedback(.selection, trigger: isFavorite)
        .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
    }
}
