import ActivityKit
import SwiftUI
import WidgetKit

struct FlightLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FlightActivityAttributes.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state)
                .padding()
                .activityBackgroundTint(Color.indigo.opacity(0.25))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Endpoint(code: context.attributes.origin, time: context.state.departure, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Endpoint(code: context.attributes.destination, time: context.state.arrival, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.flightNumber)
                        .font(.headline.monospaced())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.status).bold()
                        Spacer()
                        Text("Gate \(context.state.gate)")
                    }
                    .font(.subheadline)
                }
            } compactLeading: {
                Image(systemName: "airplane")
            } compactTrailing: {
                Text(context.state.status)
                    .font(.caption2.bold())
            } minimal: {
                Image(systemName: "airplane")
            }
        }
    }
}

private struct LockScreenView: View {
    let attributes: FlightActivityAttributes
    let state: FlightActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("\(attributes.flightNumber) · \(attributes.airline)", systemImage: "airplane")
                    .font(.subheadline.bold())
                Spacer()
                Text(state.status)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.2), in: .capsule)
            }
            HStack {
                Endpoint(code: attributes.origin, time: state.departure, alignment: .leading)
                Spacer()
                Image(systemName: "arrow.right")
                Spacer()
                Endpoint(code: attributes.destination, time: state.arrival, alignment: .trailing)
            }
            Text("Gate \(state.gate)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct Endpoint: View {
    let code: String
    let time: Date
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(code).font(.title2.bold().monospaced())
            Text(time, format: .dateTime.hour().minute())
                .font(.caption.monospacedDigit())
        }
    }
}
