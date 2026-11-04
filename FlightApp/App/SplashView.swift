import SwiftUI

/// Launch animation: the cloud wiggles, puffs, and a little plane pops out and
/// loops away, leaving a dotted trail before the wordmark springs in.
/// Tap to skip. With Reduce Motion on, it shows a still frame briefly instead.
struct SplashView: View {
    let onFinish: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var cloudVisible = false
    @State private var wiggle = 0.0
    @State private var flap = 0.0
    @State private var blink = 0.0
    @State private var squashed = false
    @State private var puffed = false
    @State private var planeVisible = false
    @State private var planeProgress = 0.0
    @State private var wordmarkVisible = false
    @State private var finished = false

    private let cloudWidth: CGFloat = 240

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height * 0.48)
            let path = Self.flightPath(from: center, screenWidth: proxy.size.width)

            ZStack {
                background

                // Drawn under the cloud so the plane appears to come out of it.
                path.trim(from: 0, to: planeProgress)
                    .stroke(inkColor.opacity(0.55), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [0.1, 10]))

                Image(systemName: "airplane")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(inkColor)
                    .scaleEffect(planeVisible ? 1 : 0.2)
                    .opacity(planeVisible ? 1 : 0)
                    .modifier(FollowPath(path: path, progress: planeProgress))

                puffs.position(center)

                CloudMascot(flap: flap, blink: blink)
                    .frame(width: cloudWidth)
                    .scaleEffect(x: squashed ? 1.12 : 1, y: squashed ? 0.88 : 1, anchor: .bottom)
                    .rotationEffect(.degrees(wiggle), anchor: .bottom)
                    .scaleEffect(cloudVisible ? 1 : 0.4)
                    .opacity(cloudVisible ? 1 : 0)
                    .position(center)

                wordmark
                    .position(x: center.x, y: center.y + cloudWidth * 0.45)
            }
        }
        .ignoresSafeArea()
        .contentShape(.rect)
        .onTapGesture(perform: finish)
        .task { await play() }
        .accessibilityElement()
        .accessibilityLabel("Wingly")
    }

    // MARK: Pieces

    private var background: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(hex: 0x1B1F4B), Color(hex: 0x4A3A8C)]
                : [Color(hex: 0x8EC5FC), Color(hex: 0xE0C3FC)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var inkColor: Color {
        colorScheme == .dark ? .white : Color(hex: 0x2B2D5C)
    }

    /// Little cloud puffs that burst outward when the cloud "pops".
    private var puffs: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                let angle = Double(index) / 8 * 2 * .pi - .pi / 2
                let distance = puffed ? cloudWidth * 0.62 : cloudWidth * 0.2
                Circle()
                    .fill(.white)
                    .frame(width: index.isMultiple(of: 2) ? 26 : 18)
                    .offset(x: cos(angle) * distance, y: sin(angle) * distance * 0.7)
                    .scaleEffect(puffed ? 0.4 : 1)
                    .opacity(puffed ? 0 : (cloudVisible && squashed ? 0.9 : 0))
            }
        }
    }

    private var wordmark: some View {
        HStack(spacing: 1) {
            ForEach(Array("Wingly".enumerated()), id: \.offset) { index, letter in
                Text(String(letter))
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundStyle(inkColor)
                    .offset(y: wordmarkVisible ? 0 : 24)
                    .scaleEffect(wordmarkVisible ? 1 : 0.4)
                    .opacity(wordmarkVisible ? 1 : 0)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.55).delay(Double(index) * 0.06),
                        value: wordmarkVisible
                    )
            }
        }
    }

    // MARK: Timeline

    private func play() async {
        if reduceMotion {
            cloudVisible = true
            wordmarkVisible = true
            await pause(0.9)
            finish()
            return
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { cloudVisible = true }
        await pause(0.45)

        // Wiggle, flapping on each swing.
        for angle in [7.0, -7, 5, -4, 0] {
            withAnimation(.easeInOut(duration: 0.09)) {
                wiggle = angle
                flap = angle == 0 ? 0 : (flap > 0.5 ? 0 : 1)
            }
            await pause(0.09)
        }

        // Puff: squash, blink, burst.
        withAnimation(.easeOut(duration: 0.12)) {
            squashed = true
            blink = 1
        }
        await pause(0.12)
        withAnimation(.easeOut(duration: 0.5)) { puffed = true }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.45)) {
            squashed = false
            blink = 0
            planeVisible = true
        }

        // The plane loops out of the cloud; the wordmark lands while it flies off.
        withAnimation(.easeInOut(duration: 1.3)) { planeProgress = 1 }
        await pause(0.6)
        wordmarkVisible = true
        withAnimation(.easeInOut(duration: 0.15).repeatCount(3, autoreverses: true)) { flap = 1 }
        await pause(1.1)
        flap = 0
        finish()
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onFinish()
    }

    /// A cursive loop rising out of the top of the cloud, then exiting to the right.
    static func flightPath(from center: CGPoint, screenWidth: CGFloat) -> Path {
        let c = center
        return Path { p in
            p.move(to: CGPoint(x: c.x, y: c.y - 30))
            p.addCurve(
                to: CGPoint(x: c.x + 50, y: c.y - 175),
                control1: CGPoint(x: c.x, y: c.y - 120),
                control2: CGPoint(x: c.x + 15, y: c.y - 175)
            )
            p.addCurve(
                to: CGPoint(x: c.x + 5, y: c.y - 230),
                control1: CGPoint(x: c.x + 85, y: c.y - 175),
                control2: CGPoint(x: c.x + 60, y: c.y - 235)
            )
            p.addCurve(
                to: CGPoint(x: c.x - 20, y: c.y - 170),
                control1: CGPoint(x: c.x - 25, y: c.y - 226),
                control2: CGPoint(x: c.x - 35, y: c.y - 190)
            )
            p.addCurve(
                to: CGPoint(x: screenWidth + 60, y: c.y - 170),
                control1: CGPoint(x: c.x + 20, y: c.y - 140),
                control2: CGPoint(x: screenWidth * 0.8, y: c.y - 230)
            )
        }
    }
}

/// Places the view at `progress` along `path`, pointing along the direction of travel.
private struct FollowPath: ViewModifier, Animatable {
    let path: Path
    var progress: Double

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let end = max(progress, 0.001)
        let point = path.trimmedPath(from: 0, to: end).currentPoint ?? .zero
        let behind = path.trimmedPath(from: 0, to: max(end - 0.01, 0)).currentPoint ?? point
        let dx = point.x - behind.x
        let dy = point.y - behind.y
        // Before it has moved, point straight up (out of the cloud).
        let heading = hypot(dx, dy) < 0.5 ? -Double.pi / 2 : atan2(dy, dx)

        return content
            .rotationEffect(.radians(heading))
            .position(point)
    }
}

#Preview {
    SplashView {}
}
