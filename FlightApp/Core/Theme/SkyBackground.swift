import SwiftUI

/// Soft sky gradient used behind every screen, optionally with slowly drifting clouds.
struct SkyBackground: View {
    var drifting = false

    var body: some View {
        LinearGradient(colors: [Palette.skyTop, Palette.skyBottom], startPoint: .top, endPoint: .bottom)
            .overlay {
                if drifting { DriftingClouds() }
            }
            .ignoresSafeArea()
    }
}

extension View {
    /// Replaces a List / ScrollView's system background with the sky.
    func skyBackground(drifting: Bool = false) -> some View {
        scrollContentBackground(.hidden)
            .background { SkyBackground(drifting: drifting) }
    }

    /// Card-colored List rows, so dark mode rows match the sky instead of system grey.
    /// Applies to every row inside a Section or ForEach.
    func cardRows() -> some View {
        listRowBackground(Palette.card)
    }
}

private struct DriftingClouds: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Relative vertical position, size and speed (pt/s) of each cloud.
    private let clouds: [(y: CGFloat, scale: CGFloat, speed: Double, offset: Double)] = [
        (0.08, 1.0, 9, 0), (0.22, 0.6, 14, 180), (0.55, 0.8, 7, 90), (0.82, 0.5, 12, 260),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let color = Color.white.opacity(colorScheme == .dark ? 0.05 : 0.55)
                let span = size.width + 200
                for cloud in clouds {
                    let x = (time * cloud.speed + cloud.offset).truncatingRemainder(dividingBy: span) - 100
                    drawPuff(in: context, at: CGPoint(x: x, y: size.height * cloud.y), scale: cloud.scale, color: color)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func drawPuff(in context: GraphicsContext, at origin: CGPoint, scale: CGFloat, color: Color) {
        let circles: [(dx: CGFloat, dy: CGFloat, r: CGFloat)] = [(-34, 6, 26), (0, -6, 36), (36, 6, 24)]
        for circle in circles {
            let r = circle.r * scale
            let rect = CGRect(x: origin.x + circle.dx * scale - r, y: origin.y + circle.dy * scale - r, width: r * 2, height: r * 2)
            context.fill(Path(ellipseIn: rect), with: .color(color))
        }
    }
}
