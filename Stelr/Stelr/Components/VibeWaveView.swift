import SwiftUI

struct VibeWaveView: View {
    let hexColor: String
    let score: Double
    var animate: Bool = true

    @State private var bumped = false
    // Initialized to -1 so first render never triggers a spurious bump
    @State private var prevScore: Double = -1

    private var normalizedScore: Double {
        min(max(score / 10, 0), 1)
    }

    private var orbSize: CGFloat {
        let base = 4 + CGFloat(pow(normalizedScore, 1.25)) * 24
        switch score {
        case 7..<9:
            return base * 0.88
        case 5..<7:
            return base * 0.84
        default:
            return base
        }
    }

    private var orbColor: Color {
        switch score {
        case 9...: return .white
        case 7..<9: return Color.stelrAccent
        case 5..<7: return Color(hex: "D6B84A")
        case 3..<5: return Color(hex: "D86262")
        default: return .black
        }
    }

    private var scoreColor: Color {
        score < 3 ? .white.opacity(0.5) : orbColor
    }

    private var glowOpacity: Double {
        score < 3 ? 0.18 : 0.35 + normalizedScore * 0.35
    }

    var body: some View {
        HStack(spacing: 7) {
            Text(String(format: "%.1f", score))
                .font(.custom("Georgia", size: 23.5).weight(.semibold))
                .foregroundColor(scoreColor)
                .scaleEffect(bumped ? 1.18 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.5), value: bumped)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                orbColor.opacity(glowOpacity),
                                orbColor.opacity(glowOpacity * 0.28),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 23
                        )
                    )
                    .frame(width: 46, height: 46)
                    .scaleEffect(bumped ? 1.16 : 1.0)

                Circle()
                    .fill(orbColor)
                    .frame(width: orbSize, height: orbSize)
                    .overlay(
                        Circle()
                            .stroke(score >= 9 ? Color.white.opacity(0.7) : Color.white.opacity(0.12), lineWidth: 0.8)
                    )
                    .shadow(color: orbColor.opacity(glowOpacity), radius: score < 3 ? 2.5 : 8)
                    .scaleEffect(bumped ? 1.18 : 1.0)

                if animate && score >= 6 {
                    Circle()
                        .stroke(orbColor.opacity(0.22), lineWidth: 1)
                        .frame(width: orbSize + 10, height: orbSize + 10)
                        .scaleEffect(bumped ? 1.28 : 1.0)
                }
            }
            .frame(width: 34, height: 34)
            .animation(.spring(response: 0.3, dampingFraction: 0.62), value: score)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: bumped)
        }
        .onAppear { prevScore = score }
        .onChange(of: score) { _, newVal in
            guard newVal != prevScore, prevScore >= 0 else { prevScore = newVal; return }
            prevScore = newVal
            bumped = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { bumped = false }
        }
    }
}
