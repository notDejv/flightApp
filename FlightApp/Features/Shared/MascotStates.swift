import SwiftUI

/// Empty / error state featuring the mascot, replacing `ContentUnavailableView`.
struct MascotEmptyState<Actions: View>: View {
    let mood: CloudMascot.Mood
    let title: String
    let message: String
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .topTrailing) {
                LivelyMascot(mood: mood, bobAmount: 6)
                    .frame(width: 170)
                switch mood {
                case .sleepy:
                    SleepyZs().offset(x: 18, y: -26)
                case .confused:
                    Text("?")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(Palette.accent)
                        .rotationEffect(.degrees(14))
                        .offset(x: 10, y: -24)
                case .happy:
                    EmptyView()
                }
            }
            .padding(.bottom, 8)

            Text(title)
                .font(.title3.bold())
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            actions
                .padding(.top, 6)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

extension MascotEmptyState where Actions == EmptyView {
    init(mood: CloudMascot.Mood, title: String, message: String) {
        self.init(mood: mood, title: title, message: message) { EmptyView() }
    }
}

/// The mascot flapping hard while something loads.
struct MascotLoader: View {
    let message: String

    var body: some View {
        VStack(spacing: 18) {
            LivelyMascot(flapSpeed: 14, bobAmount: 8)
                .frame(width: 150)
            Text(message)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// "z z z" drifting up from a sleeping mascot.
private struct SleepyZs: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    // Each "z" runs a 2.4s rise-and-fade cycle, staggered.
                    let phase = ((time / 2.4) + Double(index) / 3).truncatingRemainder(dividingBy: 1)
                    Text("z")
                        .font(.system(size: 16 + CGFloat(index) * 5, weight: .heavy, design: .rounded))
                        .foregroundStyle(Palette.accent)
                        .offset(x: phase * 18, y: -phase * 34)
                        .opacity(phase < 0.15 ? phase / 0.15 : 1 - phase)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Small hearts bursting outward. Plays each time `trigger` changes.
struct HeartBurst: View {
    let trigger: Int

    private struct Frame {
        var distance: CGFloat = 0
        var scale: CGFloat = 0.3
        var opacity: Double = 0
    }

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                let angle = Double(index) / 6 * 2 * .pi - .pi / 2
                Image(systemName: "heart.fill")
                    .font(.system(size: index.isMultiple(of: 2) ? 10 : 7))
                    .foregroundStyle(index.isMultiple(of: 3) ? Palette.accent : .pink)
                    .keyframeAnimator(initialValue: Frame(), trigger: trigger) { heart, frame in
                        heart
                            .scaleEffect(frame.scale)
                            .opacity(frame.opacity)
                            .offset(x: cos(angle) * frame.distance, y: sin(angle) * frame.distance)
                    } keyframes: { _ in
                        KeyframeTrack(\.distance) {
                            CubicKeyframe(26, duration: 0.55)
                        }
                        KeyframeTrack(\.scale) {
                            SpringKeyframe(1, duration: 0.3)
                            LinearKeyframe(0.5, duration: 0.25)
                        }
                        KeyframeTrack(\.opacity) {
                            LinearKeyframe(1, duration: 0.05)
                            LinearKeyframe(1, duration: 0.25)
                            LinearKeyframe(0, duration: 0.25)
                        }
                    }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
