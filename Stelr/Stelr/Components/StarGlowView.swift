import SwiftUI

enum H7bStarTier {
    case cool, warm, hot, blazing, iconic
}

struct H7bStarVisualStyle {
    let score10: Double
    let color: Color
    let opacity: Double
    let tier: H7bStarTier
    let haloRadius: CGFloat
    let innerGlowRadius: CGFloat
    let ringCount: Int
    let ringDuration: Double
    let breathDuration: Double
    let labelOpacity: Double

    init(appScore: Double, audienceCount: Int = 1) {
        let isDead = Self.isDeadStar(appScore)
        let visualAppScore = Self.visualAppScore(for: appScore)
        let score10 = Self.score10(appScore: visualAppScore, audienceCount: audienceCount)
        let normalized = score10 / 10.0
        let tier = Self.tier(for: score10)

        self.score10 = score10
        self.color = isDead ? Color(red: 0.42, green: 0.43, blue: 0.46) : Self.color(for: score10)
        self.opacity = isDead ? 0.72 : 0.4 + pow(normalized, 1.4) * 0.6
        self.tier = tier
        self.haloRadius = isDead ? 11 : 14 + CGFloat(normalized) * 18
        self.innerGlowRadius = isDead ? 6 : (14 + CGFloat(normalized) * 18) * 0.55
        self.ringCount = isDead ? 0 : Self.ringCount(for: tier, appScore: visualAppScore, actualAppScore: appScore)
        self.ringDuration = Self.ringDuration(for: tier, appScore: visualAppScore, actualAppScore: appScore)
        self.breathDuration = Self.breathDuration(for: tier, appScore: visualAppScore, actualAppScore: appScore)
        self.labelOpacity = isDead ? 0.50 : 0.55 + (0.4 + pow(normalized, 1.4) * 0.6) * 0.25
    }

    static func isDeadStar(_ appScore: Double) -> Bool {
        appScore >= 1.0 && appScore <= 2.5
    }

    static func visualAppScore(for appScore: Double) -> Double {
        if appScore >= 4.5 {
            return 5.0
        }
        if appScore >= 4.0 {
            return 4.5
        }
        return appScore
    }

    static func score10(appScore: Double, audienceCount: Int = 1) -> Double {
        guard appScore > 0 else { return 0 }
        let base = min(10, max(0, appScore * 2))
        let audienceBoost = min(Double(max(0, audienceCount - 1)), 5) * 0.28
        return min(10, base + audienceBoost)
    }

    static func color(for score10: Double) -> Color {
        let score = min(10, max(0, score10))
        let stops: [(score: Double, rgb: (Double, Double, Double))] = [
            (0.0,  (170, 172, 178)),
            (4.0,  (200, 200, 198)),
            (6.0,  (228, 224, 212)),
            (8.0,  (245, 235, 205)),
            (9.3,  (252, 240, 195)),
            (10.0, (255, 240, 185))
        ]

        for index in 0..<(stops.count - 1) {
            let low = stops[index]
            let high = stops[index + 1]
            if score <= high.score {
                let t = (score - low.score) / max(high.score - low.score, 0.001)
                let r = low.rgb.0 + (high.rgb.0 - low.rgb.0) * t
                let g = low.rgb.1 + (high.rgb.1 - low.rgb.1) * t
                let b = low.rgb.2 + (high.rgb.2 - low.rgb.2) * t
                return Color(red: r / 255, green: g / 255, blue: b / 255)
            }
        }

        let last = stops[stops.count - 1].rgb
        return Color(red: last.0 / 255, green: last.1 / 255, blue: last.2 / 255)
    }

    static func tier(for score10: Double) -> H7bStarTier {
        switch score10 {
        case 9.5...:
            return .iconic
        case 9.0..<9.5:
            return .blazing
        case 8.0..<9.0:
            return .hot
        case 6.0..<8.0:
            return .warm
        default:
            return .cool
        }
    }

    private static func ringCount(for tier: H7bStarTier, appScore: Double, actualAppScore: Double) -> Int {
        if actualAppScore >= 4.0 && actualAppScore < 4.5 {
            return 1
        }
        if appScore >= 5.0 {
            return 2
        }

        switch tier {
        case .iconic:
            return 3
        case .blazing:
            return 2
        case .hot:
            return 1
        case .warm, .cool:
            return 0
        }
    }

    private static func ringDuration(for tier: H7bStarTier, appScore: Double, actualAppScore: Double) -> Double {
        if actualAppScore >= 4.0 && actualAppScore < 4.5 {
            return 3.05
        }
        if appScore >= 5.0 {
            return 2.05
        }
        if appScore >= 4.5 {
            return 2.25
        }
        return tier == .iconic ? 2.6 : 3.2
    }

    private static func breathDuration(for tier: H7bStarTier, appScore: Double, actualAppScore: Double) -> Double {
        if actualAppScore >= 4.0 && actualAppScore < 4.5 {
            return 3.1
        }
        if appScore >= 5.0 {
            return 2.1
        }
        if appScore >= 4.5 {
            return 2.35
        }

        switch tier {
        case .iconic:
            return 2.6
        case .blazing:
            return 3.0
        case .hot:
            return 3.4
        case .warm, .cool:
            return 3.8
        }
    }

    static func ratingColor(appScore: Double, audienceCount: Int = 1) -> Color {
        H7bStarVisualStyle(appScore: appScore, audienceCount: audienceCount).color
    }

    static func ratingColor(score: Double?, fallback vibe: VibeOption) -> Color {
        H7bStarVisualStyle(appScore: score ?? vibe.representativeScore).color
    }

    static func visualScale(maxCoreSize: CGFloat, appScore: Double, audienceCount: Int = 1) -> CGFloat {
        let style = H7bStarVisualStyle(appScore: appScore, audienceCount: audienceCount)
        let visualAppScore = Self.visualAppScore(for: appScore)
        let baseScale = min(1.45, max(0.42, maxCoreSize / 64.0))
        if Self.isDeadStar(appScore) {
            return baseScale * 0.72
        }

        let topShowScale: CGFloat = visualAppScore >= 4.0 ? 1.5 : 1.0
        if appScore >= 4.0 && appScore < 4.5 {
            return baseScale * topShowScale
        }

        let oneRingScale: CGFloat = style.ringCount == 1 ? 0.5 : 1.0
        let midHighBoost: CGFloat
        midHighBoost = visualAppScore >= 3.5 && visualAppScore < 4.0 ? 1.42 : 1.0
        return baseScale * topShowScale * oneRingScale * midHighBoost
    }
}

// Kept for older call sites that still ask for a rating colour/opacity tuple.
struct RatingStarVisualStyle {
    let score: Double
    let step: CheckInStep
    let progress: CGFloat
    let tint: Color
    let brightness: Double
    let sizeScale: CGFloat
    let tintOpacity: Double
    let glowOpacity: Double
    let shadowOpacity: Double
    let pulseAmount: CGFloat
    let pulseDuration: Double

    init(score: Double, isActive: Bool = false) {
        let snapped = CheckInStep.from(score)
        let h7b = H7bStarVisualStyle(appScore: snapped.score)
        let rawProgress = CGFloat((snapped.score - 1.0) / 4.0)

        self.score = snapped.score
        self.step = snapped
        self.progress = rawProgress
        self.tint = h7b.color
        self.brightness = 0.08 + Double(rawProgress) * 0.28 + (isActive ? 0.04 : 0)
        self.sizeScale = 0.78 + rawProgress * 0.26 + (isActive ? 0.04 : 0)
        self.tintOpacity = h7b.opacity
        self.glowOpacity = 0.04 + Double(rawProgress) * 0.22 + (isActive ? 0.05 : 0)
        self.shadowOpacity = 0.08 + Double(rawProgress) * 0.38 + (isActive ? 0.08 : 0)
        self.pulseAmount = rawProgress < 0.25 ? 0 : rawProgress * 0.095 + (isActive ? 0.018 : 0)
        self.pulseDuration = h7b.breathDuration
    }
}

/// H7b "Ringed" star visual.
///
/// `score` uses the app's 1.0-5.0 check-in scale. Internally it maps to the
/// handoff's 0-10 scale, with optional `audienceCount` boost for constellation
/// aggregate stars. The core is intentionally uniform; rating reads through
/// glow radius, brightness, breathing rate, and pulse ring count.
struct StarGlowView: View {
    let score: Double
    var maxCoreSize: CGFloat = 64
    var animate: Bool = true
    var audienceCount: Int = 1
    var title: String? = nil
    var phaseOffset: Double = 0
    var timingJitter: Double = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var style: H7bStarVisualStyle {
        H7bStarVisualStyle(appScore: score, audienceCount: audienceCount)
    }

    private var visualScale: CGFloat {
        H7bStarVisualStyle.visualScale(
            maxCoreSize: maxCoreSize,
            appScore: score,
            audienceCount: audienceCount
        )
    }

    private var canvasSize: CGFloat {
        max(26, style.haloRadius * 2.32 * visualScale)
    }

    private var coreRadius: CGFloat {
        max(1.35, 3 * visualScale)
    }

    private var coreDiameter: CGFloat {
        max(9, 14 * visualScale)
    }

    private var isUnstableFiveStar: Bool {
        H7bStarVisualStyle.visualAppScore(for: score) >= 5.0
    }

    private var isDeadStar: Bool {
        H7bStarVisualStyle.isDeadStar(score)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !animate || reduceMotion)) { timeline in
            let time = animate && !reduceMotion ? timeline.date.timeIntervalSinceReferenceDate : 0
            starBody(time: time)
        }
        .frame(width: canvasSize, height: canvasSize)
        .overlay(alignment: .center) {
            if let title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 12, weight: style.tier == .iconic ? .medium : .regular))
                    .tracking(0.1)
                    .foregroundColor(style.color.opacity(style.labelOpacity))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .offset(y: style.haloRadius * visualScale + 11 * visualScale)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityHidden(title == nil)
        .accessibilityLabel(title ?? "")
    }

    @ViewBuilder
    private func starBody(time: TimeInterval) -> some View {
        let breath = animate && !reduceMotion ? breathValue(at: time) : 0.5
        let breathScale = 0.85 + CGFloat(breath) * 0.30
        let breathOpacity = 0.55 + breath * 0.45
        let glowDiameter = style.innerGlowRadius * 2 * visualScale
        let shake = unstableShakeOffset(at: time)

        ZStack {
            if isDeadStar {
                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: Color(red: 0.20, green: 0.21, blue: 0.23).opacity(0.98), location: 0.0),
                                .init(color: style.color.opacity(0.62), location: 0.68),
                                .init(color: Color.white.opacity(0.16), location: 0.86),
                                .init(color: Color.clear, location: 1.0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: max(1, style.haloRadius * visualScale)
                        )
                    )
                    .frame(width: style.haloRadius * 2 * visualScale, height: style.haloRadius * 2 * visualScale)
            } else {
                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: style.color.opacity(style.opacity * breathOpacity), location: 0.0),
                                .init(color: style.color.opacity(style.opacity * 0.55 * breathOpacity), location: 0.40),
                                .init(color: style.color.opacity(0), location: 1.0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: style.innerGlowRadius * visualScale
                        )
                    )
                    .frame(width: glowDiameter, height: glowDiameter)
                    .scaleEffect(breathScale)
            }

            ForEach(0..<style.ringCount, id: \.self) { index in
                ring(index: index, time: time)
            }

            StelrFourPointStar(variant: .twinkle)
                .fill(style.color.opacity(isDeadStar ? max(0.58, style.opacity) : style.opacity))
                .frame(width: coreDiameter, height: coreDiameter)
                .shadow(color: style.color.opacity(isDeadStar ? 0.16 : style.opacity * 0.55), radius: coreDiameter * 0.44)
        }
        .offset(shake)
        .frame(width: canvasSize, height: canvasSize)
    }

    private func ring(index: Int, time: TimeInterval) -> some View {
        let phase = animate && !reduceMotion ? ringPhase(at: time, index: index) : 0.45
        let eased = easeOut(phase)
        let ringScale = 0.8 + CGFloat(eased) * 0.8
        let animatedOpacity = style.opacity * (0.8 - Double(index) * 0.1) * (1 - phase) * 0.55
        let staticOpacity = style.opacity * (0.28 - Double(index) * 0.04)
        let opacity = animate && !reduceMotion ? animatedOpacity : staticOpacity
        let ringDiameter = style.haloRadius * 0.70 * visualScale

        return Circle()
            .stroke(style.color.opacity(max(0, opacity)), lineWidth: max(0.55, visualScale))
            .frame(width: ringDiameter, height: ringDiameter)
            .scaleEffect(ringScale)
    }

    private func breathValue(at time: TimeInterval) -> Double {
        let duration = max(0.6, style.breathDuration * timingJitter)
        var shifted = (time + phaseOffset).truncatingRemainder(dividingBy: duration)
        if shifted < 0 { shifted += duration }
        let phase = shifted / duration
        return 0.5 - 0.5 * cos(phase * 2 * .pi)
    }

    private func ringPhase(at time: TimeInterval, index: Int) -> Double {
        guard style.ringCount > 0 else { return 0 }
        let duration = max(0.6, style.ringDuration * timingJitter)
        let delay = Double(index) * duration / Double(style.ringCount)
        var shifted = (time + phaseOffset - delay).truncatingRemainder(dividingBy: duration)
        if shifted < 0 { shifted += duration }
        return shifted / duration
    }

    private func unstableShakeOffset(at time: TimeInterval) -> CGSize {
        guard animate && !reduceMotion && isUnstableFiveStar else { return .zero }
        let amplitude = min(1.4, max(0.55, visualScale * 0.75))
        let shifted = time + phaseOffset
        let x = (sin(shifted * 19.0) * 0.62 + sin(shifted * 43.0) * 0.22) * amplitude
        let y = (cos(shifted * 23.0) * 0.44 + sin(shifted * 37.0) * 0.18) * amplitude
        return CGSize(width: x, height: y)
    }

    private func easeOut(_ value: Double) -> Double {
        1 - pow(1 - value, 3)
    }
}

struct StarGlowAmbientBackground: View {
    let score: Double

    var body: some View {
        let style = H7bStarVisualStyle(appScore: score)
        RadialGradient(
            colors: [style.color.opacity(style.opacity * 0.12), .clear],
            center: .init(x: 0.5, y: 0),
            startRadius: 0,
            endRadius: 320
        )
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 2), value: score)
    }
}
