import SwiftUI

/// The winged cloud from the app icon, drawn with the same geometry so the two match.
///
/// `flap` (0…1) raises the wings and `blink` (0…1) closes the eyes; both animate.
/// `mood` swaps the face for empty and error states.
struct CloudMascot: View, Animatable {
    enum Mood {
        case happy
        case sleepy
        case confused
    }

    var flap: Double = 0
    var blink: Double = 0
    var mood: Mood = .happy

    nonisolated var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(flap, blink) }
        set {
            flap = newValue.first
            blink = newValue.second
        }
    }

    @Environment(\.colorScheme) private var colorScheme

    /// The icon is drawn on a 1024pt canvas; this is the part the mascot occupies.
    private static let artwork = CGRect(x: 90, y: 320, width: 844, height: 440)
    private static let ink = Color(hex: 0x2B2D5C)

    var body: some View {
        Canvas { context, size in
            draw(in: &context, size: size)
        }
        .aspectRatio(Self.artwork.width / Self.artwork.height, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let scale = size.width / Self.artwork.width
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -Self.artwork.minX, y: -Self.artwork.minY)

        let isDark = colorScheme == .dark
        drawWings(in: context, isDark: isDark)
        drawBody(in: context, isDark: isDark)
        drawCheeks(in: context)
        switch mood {
        case .happy: drawHappyFace(in: context)
        case .sleepy: drawSleepyFace(in: context)
        case .confused: drawConfusedFace(in: context)
        }
    }

    private func drawWings(in context: GraphicsContext, isDark: Bool) {
        let fill = Color(hex: isDark ? 0xE6E1FF : 0xF6F3FF)
        let stroke = Color(hex: isDark ? 0xA79CF0 : 0xBDB4F2)
        let feathers: [(center: CGPoint, size: CGSize, angle: Double)] = [
            (CGPoint(x: 215, y: 455), CGSize(width: 230, height: 74), 32),
            (CGPoint(x: 222, y: 520), CGSize(width: 200, height: 68), 18),
            (CGPoint(x: 238, y: 585), CGSize(width: 160, height: 60), 4),
        ]
        // Wings pivot where they meet the cloud.
        let hinge = CGPoint(x: 300, y: 540)

        for side in [1.0, -1.0] {
            var wing = context
            let hingeX = side == 1 ? hinge.x : 1024 - hinge.x
            wing.translateBy(x: hingeX, y: hinge.y)
            wing.rotate(by: .degrees(side * flap * 18))
            wing.translateBy(x: -hingeX, y: -hinge.y)

            for feather in feathers {
                var c = wing
                c.translateBy(x: side == 1 ? feather.center.x : 1024 - feather.center.x, y: feather.center.y)
                c.rotate(by: .degrees(side * feather.angle))
                let oval = Path(ellipseIn: CGRect(
                    x: -feather.size.width / 2, y: -feather.size.height / 2,
                    width: feather.size.width, height: feather.size.height
                ))
                c.fill(oval, with: .color(fill))
                c.stroke(oval, with: .color(stroke), lineWidth: 7)
            }
        }
    }

    private func drawBody(in context: GraphicsContext, isDark: Bool) {
        let cloud = Path { p in
            p.addEllipse(in: CGRect(x: 345 - 125, y: 610 - 125, width: 250, height: 250))
            p.addEllipse(in: CGRect(x: 679 - 125, y: 610 - 125, width: 250, height: 250))
            p.addEllipse(in: CGRect(x: 512 - 165, y: 500 - 165, width: 330, height: 330))
            p.addRoundedRect(in: CGRect(x: 300, y: 600, width: 424, height: 135), cornerSize: CGSize(width: 60, height: 60))
        }
        var c = context
        c.addFilter(.shadow(color: Color(hex: isDark ? 0x0B0D26 : 0x6B5FB5).opacity(0.35), radius: 15, y: 14))
        c.fill(cloud, with: .color(Color(hex: isDark ? 0xF4F2FF : 0xFFFFFF)))
    }

    private func drawCheeks(in context: GraphicsContext) {
        for x in [405.0, 619.0] {
            context.fill(Path(ellipseIn: CGRect(x: x - 34, y: 632 - 18, width: 68, height: 36)), with: .color(Palette.blush.opacity(0.75)))
        }
    }

    private func drawOpenEyes(in context: GraphicsContext) {
        let eyeHeight = 56 * (1 - 0.85 * blink)
        for x in [455.0, 569.0] {
            context.fill(Path(ellipseIn: CGRect(x: x - 24, y: 575 - eyeHeight / 2, width: 48, height: eyeHeight)), with: .color(Self.ink))
            if blink < 0.5 {
                context.fill(Path(ellipseIn: CGRect(x: x + 8 - 9, y: 560 - 9, width: 18, height: 18)), with: .color(.white))
            }
        }
    }

    private func drawHappyFace(in context: GraphicsContext) {
        drawOpenEyes(in: context)
        let smile = Path { p in
            p.addArc(center: CGPoint(x: 512, y: 615), radius: 34, startAngle: .degrees(27), endAngle: .degrees(153), clockwise: false)
        }
        context.stroke(smile, with: .color(Self.ink), style: StrokeStyle(lineWidth: 13, lineCap: .round))
    }

    private func drawSleepyFace(in context: GraphicsContext) {
        let style = StrokeStyle(lineWidth: 11, lineCap: .round)
        for x in [455.0, 569.0] {
            let closedEye = Path { p in
                p.addArc(center: CGPoint(x: x, y: 568), radius: 22, startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
            }
            context.stroke(closedEye, with: .color(Self.ink), style: style)
        }
        context.fill(Path(ellipseIn: CGRect(x: 512 - 12, y: 625 - 14, width: 24, height: 28)), with: .color(Self.ink))
    }

    private func drawConfusedFace(in context: GraphicsContext) {
        drawOpenEyes(in: context)
        let style = StrokeStyle(lineWidth: 11, lineCap: .round)
        let brow = Path { p in
            p.move(to: CGPoint(x: 545, y: 518))
            p.addLine(to: CGPoint(x: 595, y: 532))
        }
        context.stroke(brow, with: .color(Self.ink), style: style)
        let mouth = Path { p in
            p.move(to: CGPoint(x: 478, y: 628))
            p.addQuadCurve(to: CGPoint(x: 512, y: 626), control: CGPoint(x: 495, y: 610))
            p.addQuadCurve(to: CGPoint(x: 546, y: 624), control: CGPoint(x: 529, y: 642))
        }
        context.stroke(mouth, with: .color(Self.ink), style: style)
    }
}

/// The mascot with a little life: gentle bobbing, a blink now and then and optional
/// wing flapping. Holds still with Reduce Motion on.
struct LivelyMascot: View {
    var mood: CloudMascot.Mood = .happy
    /// Flaps per second × 2π; 0 keeps the wings still.
    var flapSpeed: Double = 0
    var bobAmount: CGFloat = 5

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            CloudMascot(mood: mood)
        } else {
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let flap = flapSpeed > 0 ? (sin(time * flapSpeed) + 1) / 2 : 0
                let blinks = mood != .sleepy && time.truncatingRemainder(dividingBy: 3.7) < 0.14
                CloudMascot(flap: flap, blink: blinks ? 1 : 0, mood: mood)
                    .offset(y: sin(time * 2.2) * bobAmount)
            }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        LivelyMascot(flapSpeed: 10).frame(width: 200)
        HStack {
            CloudMascot(mood: .sleepy)
            CloudMascot(mood: .confused)
        }
        .frame(width: 320)
    }
    .padding()
    .background(SkyBackground())
}
