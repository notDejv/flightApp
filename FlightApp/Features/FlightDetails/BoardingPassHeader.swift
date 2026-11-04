import SwiftUI

/// Ticket-style summary at the top of Flight Details: route arc with the plane placed
/// by flight progress, a live countdown, and gate / terminal / aircraft chips.
struct BoardingPassHeader: View {
    let flight: Flight

    @State private var shownProgress = 0.0

    var body: some View {
        // Re-evaluated every 30s so the countdown stays fresh.
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let timeline = FlightTimeline(flight: flight, now: context.date)
            VStack(spacing: 0) {
                top
                    .padding(20)
                    .background(Palette.card, in: TicketShape(notches: .bottom))
                stub(timeline)
                    .padding(20)
                    .background(Palette.card, in: TicketShape(notches: .top))
                    .overlay(alignment: .top) { tearLine }
            }
            .compositingGroup()
            .shadow(color: Palette.accent.opacity(0.18), radius: 16, y: 8)
            .task(id: timeline.progress) {
                withAnimation(.spring(duration: 1.2, bounce: 0.25).delay(0.2)) {
                    shownProgress = timeline.progress
                }
            }
        }
    }

    private var top: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(flight.airline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(flight.flightNumber)
                        .font(.title2.bold().monospaced())
                }
                Spacer()
                StatusBadge(status: flight.status)
            }

            RouteArc(progress: shownProgress, isCancelled: flight.status == .cancelled)
                .frame(height: 64)

            HStack(alignment: .top) {
                endpoint(flight.origin, time: flight.departure, alignment: .leading)
                Spacer()
                Text(Duration.seconds(flight.duration), format: .units(allowed: [.hours, .minutes], width: .narrow))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 10)
                Spacer()
                endpoint(flight.destination, time: flight.arrival, alignment: .trailing)
            }
        }
    }

    private func endpoint(_ airport: Airport, time: Date, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(airport.code)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
            Text(airport.city)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(time, format: .dateTime.hour().minute())
                .font(.headline.monospacedDigit())
        }
    }

    private func stub(_ timeline: FlightTimeline) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(timeline.summary, systemImage: timeline.symbol)
                .font(.headline)
                .foregroundStyle(flight.status == .cancelled ? .red : Palette.accent)
                .contentTransition(.numericText())

            HStack(spacing: 10) {
                InfoChip(title: "Terminal", value: flight.terminal)
                InfoChip(title: "Gate", value: flight.gate)
                InfoChip(title: "Aircraft", value: flight.aircraft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tearLine: some View {
        Line()
            .stroke(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [5, 6]))
            .frame(height: 1)
            .padding(.horizontal, TicketShape.notchRadius + 6)
    }
}

private struct InfoChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.accent.opacity(0.1), in: .rect(cornerRadius: 10))
    }
}

/// Dashed flight arc between two airports with the plane at `progress` (0…1).
struct RouteArc: View, Animatable {
    var progress: Double
    var isCancelled = false

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        GeometryReader { proxy in
            let arc = Arc(size: proxy.size)
            let tint = isCancelled ? Color.secondary : Palette.accent
            ZStack {
                arc.path()
                    .stroke(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 7]))
                arc.path()
                    .trimmedPath(from: 0, to: progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                ForEach([arc.start, arc.end], id: \.x) { point in
                    Circle()
                        .fill(Palette.card)
                        .stroke(tint, lineWidth: 3)
                        .frame(width: 12, height: 12)
                        .position(point)
                }
                Image(systemName: "airplane")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
                    .rotationEffect(.radians(arc.heading(at: progress)))
                    .position(arc.point(at: progress))
            }
        }
        .accessibilityHidden(true)
    }

    /// Quadratic Bézier from bottom-left to bottom-right, bowing upward.
    private struct Arc {
        let start: CGPoint
        let end: CGPoint
        let control: CGPoint

        init(size: CGSize) {
            start = CGPoint(x: 8, y: size.height - 8)
            end = CGPoint(x: size.width - 8, y: size.height - 8)
            control = CGPoint(x: size.width / 2, y: -size.height * 0.55)
        }

        func path() -> Path {
            Path { p in
                p.move(to: start)
                p.addQuadCurve(to: end, control: control)
            }
        }

        func point(at t: Double) -> CGPoint {
            let u = 1 - t
            return CGPoint(
                x: u * u * start.x + 2 * u * t * control.x + t * t * end.x,
                y: u * u * start.y + 2 * u * t * control.y + t * t * end.y
            )
        }

        func heading(at t: Double) -> Double {
            let dx = 2 * (1 - t) * (control.x - start.x) + 2 * t * (end.x - control.x)
            let dy = 2 * (1 - t) * (control.y - start.y) + 2 * t * (end.y - control.y)
            return atan2(dy, dx)
        }
    }
}

/// Rounded card with semicircular bites cut from the top or bottom corners,
/// so two halves stacked together read as a tear-off ticket.
struct TicketShape: Shape {
    enum Notches { case top, bottom }

    static let notchRadius: CGFloat = 14
    var notches: Notches
    var cornerRadius: CGFloat = 22

    func path(in rect: CGRect) -> Path {
        let card = Path(roundedRect: rect, cornerRadius: cornerRadius)
        let y = notches == .top ? rect.minY : rect.maxY
        let r = Self.notchRadius
        let bites = Path { p in
            p.addEllipse(in: CGRect(x: rect.minX - r, y: y - r, width: r * 2, height: r * 2))
            p.addEllipse(in: CGRect(x: rect.maxX - r, y: y - r, width: r * 2, height: r * 2))
        }
        // The halves meet along the notch edge, so square off those corners.
        let squared = Path(CGRect(
            x: rect.minX, y: notches == .top ? rect.minY : rect.midY,
            width: rect.width, height: rect.height / 2
        ))
        return card.union(squared).subtracting(bites)
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}
