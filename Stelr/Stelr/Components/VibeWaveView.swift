import SwiftUI

// Heat orb — the single visual language for a show's vibe state.
// Three sizes used across the app (12 / 24 / large) via the `size` parameter.
// No numeric score is ever displayed — the glow, size, and pulse ARE the score.

struct VibeWaveView: View {
    let vibe: VibeOption
    /// Diameter of the orb itself (not the glow halo). Defaults to 20.
    var size: CGFloat = 20
    /// When true the orb breathes (scale pulse). Hot vibes pulse, cold rocks don't.
    var animate: Bool = true

    @State private var pulsing = false

    private var orbColor: Color {
        vibe.isCold ? Color(hex: vibe.hexColor).opacity(0.7) : Color(hex: vibe.hexColor)
    }

    private var glowRadius: CGFloat {
        switch vibe {
        case .mustWatch:   return size * 1.4
        case .goingGood:   return size * 1.0
        case .justOk:      return size * 0.5
        case .superBoring: return 0
        case .notWatching: return 0
        }
    }

    private var glowOpacity: Double {
        switch vibe {
        case .mustWatch:   return 0.62
        case .goingGood:   return 0.42
        case .justOk:      return 0.22
        case .superBoring: return 0
        case .notWatching: return 0
        }
    }

    var body: some View {
        ZStack {
            // Glow halo — absent for cold rocks
            if !vibe.isCold {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                orbColor.opacity(glowOpacity),
                                orbColor.opacity(glowOpacity * 0.25),
                                .clear,
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 1.6
                        )
                    )
                    .frame(width: size * 3.2, height: size * 3.2)
                    .scaleEffect(pulsing ? 1.18 : 1.0)
            }

            // Core orb
            Circle()
                .fill(vibe.isCold ? Color(hex: vibe.hexColor).opacity(0.55) : orbColor)
                .frame(width: size, height: size)
                .overlay(
                    Circle().stroke(
                        vibe == .mustWatch ? Color.white.opacity(0.55) : Color.white.opacity(0.08),
                        lineWidth: 0.7
                    )
                )
                .shadow(
                    color: orbColor.opacity(vibe.isCold ? 0 : (vibe == .mustWatch ? 0.9 : 0.5)),
                    radius: vibe.isCold ? 0 : size * 0.6
                )
                .scaleEffect(pulsing ? 1.12 : 1.0)
        }
        .onAppear { startPulse() }
        .onChange(of: vibe) { _, _ in startPulse() }
    }

    private func startPulse() {
        guard animate && vibe.pulseEnabled else {
            pulsing = false
            return
        }
        let speed: Double = vibe == .mustWatch ? 0.7 : 1.1
        withAnimation(.easeInOut(duration: speed).repeatForever(autoreverses: true)) {
            pulsing = true
        }
    }
}
