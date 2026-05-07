import SwiftUI

// MARK: - Tuning

struct SpaceGlideTuning {
    // Phase durations
    var lockDuration: Double   = 0.15
    var glideDuration: Double  = 0.58
    var arriveDuration: Double = 0.22

    // Camera push scale (used in ConstellationView.sceneScale)
    var sceneScaleLockOn: CGFloat = 1.013
    var sceneScaleTravel: CGFloat = 1.055
    var sceneScaleArrive: CGFloat = 1.026

    // Parallax starfield
    var starCount: Int              = 52
    var parallaxStrength: CGFloat   = 0.062   // max drift as fraction of screen width
    var nearStarOpacity: Double     = 0.34
    var farStarOpacity: Double      = 0.13
    var maxStreakLen: CGFloat        = 8.0
    var streakFraction: Double      = 0.12    // fraction of near stars that get streaks

    // Planet morph
    var planetStartSize: CGFloat = 30
    var planetEndSize: CGFloat   = 180
    var planetEndFrX: CGFloat    = 0.76
    var planetEndFrY: CGFloat    = 0.78

    // Ships
    var shipWidth: CGFloat      = 26
    var shipHeight: CGFloat     = 9
    var thrusterRadius: CGFloat = 14
    var shipSpeedFactor: Double = 1.28   // divides glideDuration for spring response
    var maxShips: Int           = 3

    // UI reveal offset (used in ShowDetailView enter animation)
    var uiRevealOffset: CGFloat = 52

    var totalDuration: Double { lockDuration + glideDuration + arriveDuration }

    static let `default` = SpaceGlideTuning()
}

// MARK: - Main transition view

/// Drop-in replacement for CinematicShowTravelOverlay.
/// Shows a calm parallax starfield, a star-morphing-into-planet that glides on a
/// bezier arc toward the bottom-right quadrant, and friend ships racing toward it.
struct SpaceGlideTransitionView: View {
    let show: Show
    let phase: ElegantSpaceZoomPhase
    let origin: CGPoint?
    let detailVisible: Bool
    var watchers: [Friend] = []
    var tuning: SpaceGlideTuning = .default

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let start = origin ?? CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.42)
            let landing = CGPoint(
                x: geo.size.width  * tuning.planetEndFrX,
                y: geo.size.height * tuning.planetEndFrY
            )

            ZStack {
                if !reduceMotion {
                    GlideParallaxStarfield(phase: phase, origin: start, tuning: tuning)
                }

                GlidePlanetView(
                    show: show,
                    phase: phase,
                    origin: start,
                    landing: landing,
                    detailVisible: detailVisible,
                    tuning: tuning
                )

                if !watchers.isEmpty && !reduceMotion {
                    RocketRaceCard(
                        watchers: Array(watchers.prefix(min(tuning.maxShips, 2))),
                        phase: phase
                    )
                    // Upper-left quadrant, leaving right side for the planet
                    .position(
                        x: RocketRaceCard.cardW / 2 + 20,
                        y: geo.size.height * 0.36
                    )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Parallax Starfield

/// A calm, slow-drift starfield. Stars flow outward from the origin as the
/// camera pushes forward — no hyperspace explosion, just gentle depth parallax.
private struct GlideParallaxStarfield: View {
    let phase: ElegantSpaceZoomPhase
    let origin: CGPoint
    var tuning: SpaceGlideTuning

    @State private var glideStart: Date = .distantPast

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                drawStars(in: &ctx, size: size, date: tl.date)
            }
        }
        .onChange(of: phase) { _, newPhase in
            if newPhase == .travel { glideStart = Date() }
        }
    }

    private func drawStars(in ctx: inout GraphicsContext, size: CGSize, date: Date) {
        guard phase != .idle else { return }

        // Smooth glide progress driven by elapsed time (0 → 1 over glideDuration)
        let rawT: CGFloat
        switch phase {
        case .idle:   rawT = 0
        case .lockOn: rawT = 0.04
        case .travel:
            let elapsed = max(0, date.timeIntervalSince(glideStart))
            rawT = min(0.68, 0.04 + CGFloat(elapsed / tuning.glideDuration) * 0.64)
        case .arrive: rawT = 1.0
        }

        let t        = smoothstep(rawT)
        let driftMax = size.width * tuning.parallaxStrength
        let fadeIn   = min(1.0, Double(rawT) * 10.0)

        for i in 0..<tuning.starCount {
            let fx    = unit(i, 1)
            let fy    = unit(i, 2)
            let depth = 0.22 + unit(i, 3) * 0.78   // 0.22 (far) … 1.0 (near)

            // Base screen position
            let bx = size.width  * fx
            let by = size.height * fy

            // Outward direction from origin
            let dx   = bx - origin.x
            let dy   = by - origin.y
            let dist = max(1, sqrt(dx * dx + dy * dy))
            let nx   = dx / dist
            let ny   = dy / dist

            // Parallax drift (near stars move more)
            let drift = t * driftMax * depth
            let px    = bx + nx * drift
            let py    = by + ny * drift

            // Opacity
            let baseOp    = tuning.farStarOpacity + (tuning.nearStarOpacity - tuning.farStarOpacity) * Double(depth)
            let finalOp   = baseOp * fadeIn

            // Short streaks for a fraction of near stars
            let isNear     = depth > 0.70
            let wantsStreak = isNear && unit(i, 5) < CGFloat(tuning.streakFraction) && rawT > 0.08

            if wantsStreak {
                let streakLen = min(tuning.maxStreakLen, rawT * tuning.maxStreakLen * depth)
                var path = Path()
                path.move(to: CGPoint(x: px - nx * streakLen, y: py - ny * streakLen))
                path.addLine(to: CGPoint(x: px, y: py))
                ctx.stroke(
                    path,
                    with: .color(Color.white.opacity(finalOp * 0.68)),
                    style: StrokeStyle(lineWidth: 0.45 + Double(depth) * 0.55, lineCap: .round)
                )
            } else {
                let r    = 0.55 + depth * 0.85
                let rect = CGRect(x: px - r / 2, y: py - r / 2, width: r, height: r)
                ctx.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(finalOp)))
            }
        }
    }

    // Smooth-step hermite: maps [0,1] → [0,1] with zero derivative at endpoints
    private func smoothstep(_ x: CGFloat) -> CGFloat { x * x * (3 - 2 * x) }

    // Deterministic pseudo-random [0, 1) via integer LCG → sin hash
    private func unit(_ i: Int, _ salt: Int) -> CGFloat {
        let v   = Double(i &* 1_103_515_245 &+ salt &* 12_345)
        let raw = sin(v) * 43_758.5453123
        return CGFloat(raw - floor(raw))
    }
}

// MARK: - Planet morph view

/// Renders the selected show's planet.
/// Begins as a ✦ star sparkle at the origin, morphs into a lit planet orb and
/// glides along a gentle bezier arc toward the bottom-right landing zone.
private struct GlidePlanetView: View {
    let show: Show
    let phase: ElegantSpaceZoomPhase
    let origin: CGPoint
    let landing: CGPoint
    let detailVisible: Bool
    var tuning: SpaceGlideTuning

    @State private var glideStart: Date = .distantPast

    var body: some View {
        TimelineView(.animation) { tl in
            let rawT = glideProgress(at: tl.date)
            let t    = smoothstep(rawT)
            let pos  = bezierPos(t: t)
            let size = lerp(tuning.planetStartSize, tuning.planetEndSize, t)

            ZStack {
                // Ambient glow halo — scales up as planet grows
                Circle()
                    .fill(Color(hex: show.accentColor).opacity(0.22))
                    .blur(radius: max(8, size * 0.22))
                    .frame(width: size * 1.6, height: size * 1.6)

                // Planet orb with directional lighting from upper-right
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.lighterHex(show.accentColor, amount: 0.38),
                                Color(hex: show.accentColor).opacity(0.82),
                                Color(hex: "1C0A04"),
                                Color.black.opacity(0.93)
                            ],
                            center: UnitPoint(x: 0.30, y: 0.26),
                            startRadius: 1,
                            endRadius: max(1, size * 0.56)
                        )
                    )
                    .overlay(
                        Circle().fill(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.12), .black.opacity(0.64)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
                    .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 0.7))
                    .shadow(color: Color(hex: show.accentColor).opacity(0.30), radius: size * 0.22)
                    .frame(width: size, height: size)

                // Star sparkle that morphs into the planet (fades out by rawT ≈ 0.28)
                let starAlpha = Double(max(0, 1 - rawT * 3.6))
                if starAlpha > 0.01 {
                    StelrFourPointStar(variant: .twinkle)
                        .fill(Color.stelrAccent)
                        .frame(width: 14, height: 14)
                        .opacity(starAlpha)
                }
            }
            .position(pos)
            .opacity(phase == .idle ? 0 : (detailVisible && phase == .arrive ? 0.20 : 1))
        }
        .onChange(of: phase) { _, newPhase in
            if newPhase == .travel { glideStart = Date() }
        }
    }

    // Elapsed-time progress: 0 at lockOn, rises 0→1 over glideDuration, stays 1 at arrive
    private func glideProgress(at date: Date) -> CGFloat {
        switch phase {
        case .idle:   return 0
        case .lockOn: return 0
        case .travel:
            let elapsed = max(0, date.timeIntervalSince(glideStart))
            return min(1, CGFloat(elapsed / tuning.glideDuration))
        case .arrive: return 1
        }
    }

    /// Quadratic bezier with control point arcing gently upward from the midpoint.
    private func bezierPos(t: CGFloat) -> CGPoint {
        let ctrl = CGPoint(
            x: (origin.x + landing.x) * 0.5 + 28,
            y: (origin.y + landing.y) * 0.5 - 68
        )
        let bx = (1-t)*(1-t)*origin.x + 2*(1-t)*t*ctrl.x + t*t*landing.x
        let by = (1-t)*(1-t)*origin.y + 2*(1-t)*t*ctrl.y + t*t*landing.y
        return CGPoint(x: bx, y: by)
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
    private func smoothstep(_ x: CGFloat) -> CGFloat { x * x * (3 - 2 * x) }
}

// MARK: - Rocket Race Card

/// A self-contained frosted glass card showing friend rockets racing through space.
/// Each rocket is drawn procedurally in Canvas: nose cone, body, cockpit dome,
/// tail fins, and a three-layer flame trail. Profile bubbles float above each cockpit.
/// Horizontal speed-streak lines animate across the dark interior.
private struct RocketRaceCard: View {

    static let cardW: CGFloat = 308

    let watchers: [Friend]
    let phase: ElegantSpaceZoomPhase

    @State private var appeared = false

    // Each lane reserves vertical space for bubble + rocket + padding
    private static let laneH: CGFloat  = 74
    private static let padV: CGFloat   = 18
    private var cardH: CGFloat { RocketRaceCard.laneH * CGFloat(watchers.count) + RocketRaceCard.padV * 2 }

    var body: some View {
        ZStack {
            // ── Frosted glass base ──────────────────────────────────────────
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)

            // Dark space overlay (keeps the space mood under the frost)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(hex: "040810").opacity(0.58))

            // ── Speed streaks (Canvas, animated) ───────────────────────────
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    drawStreaks(in: &ctx, size: size, t: tl.date.timeIntervalSinceReferenceDate)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            // ── Rockets + bubbles (Canvas) ──────────────────────────────────
            Canvas { ctx, size in
                for (i, friend) in watchers.enumerated() {
                    let laneTop = RocketRaceCard.padV + CGFloat(i) * RocketRaceCard.laneH
                    let cy = laneTop + RocketRaceCard.laneH * 0.72   // rocket center in lane
                    drawShip(in: &ctx, size: size, cy: cy, friend: friend)
                }
            }

            // ── Border ─────────────────────────────────────────────────────
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.24), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        }
        .frame(width: RocketRaceCard.cardW, height: cardH)
        .shadow(color: Color.black.opacity(0.36), radius: 26, x: 0, y: 12)
        // Entrance animation
        .opacity(appeared ? (phase == .arrive ? 0.15 : 1) : 0)
        .scaleEffect(appeared ? 1 : 0.93)
        .offset(y: appeared ? 0 : 22)
        .animation(.spring(response: 0.46, dampingFraction: 0.80), value: appeared)
        .animation(.easeOut(duration: 0.28), value: phase == .arrive)
        .onChange(of: phase) { _, newPhase in
            if newPhase == .travel {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) { appeared = true }
            } else if newPhase == .idle || newPhase == .lockOn {
                appeared = false
            }
        }
    }

    // MARK: Speed streaks

    private func drawStreaks(in ctx: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        for i in 0..<32 {
            let baseY  = size.height * unit(i, 1)
            let baseX  = size.width  * unit(i, 2) * 0.55
            let len    = 16 + unit(i, 3) * 110
            let speed  = 14 + unit(i, 4) * 38
            let opacity = 0.035 + Double(unit(i, 5)) * 0.075
            let period = 3.5 + Double(unit(i, 6)) * 5.0
            let dx     = CGFloat(t.truncatingRemainder(dividingBy: period)) * speed
            let x0     = (baseX + dx).truncatingRemainder(dividingBy: size.width * 0.9)

            var path = Path()
            path.move(to: CGPoint(x: x0,       y: baseY))
            path.addLine(to: CGPoint(x: x0 + len, y: baseY))
            ctx.stroke(path,
                       with: .color(Color.white.opacity(opacity)),
                       style: StrokeStyle(lineWidth: 0.55, lineCap: .round))
        }
    }

    // MARK: Full ship (rocket + profile bubble)

    private func drawShip(in ctx: inout GraphicsContext, size: CGSize, cy: CGFloat, friend: Friend) {
        let cx: CGFloat = size.width * 0.56   // rocket center x (right of center → facing right)

        drawRocket(in: &ctx, cx: cx, cy: cy)
        drawBubble(in: &ctx, cx: cx, cy: cy, friend: friend)
    }

    // MARK: Rocket

    private func drawRocket(in ctx: inout GraphicsContext, cx: CGFloat, cy: CGFloat) {
        let w: CGFloat = 72    // total rocket slot width (tail edge to nose tip)
        let h: CGFloat = 20    // rocket body height

        // Key x-coordinates (rocket points RIGHT →)
        let tailX  = cx - w * 0.44    // where fins attach / exhaust begins
        let bodyX1 = tailX + w * 0.09 // body start (right of fins)
        let bodyX2 = cx   + w * 0.22  // body end
        let noseX  = cx   + w * 0.50  // nose tip
        let bodyH  = h

        // ── Flame trails (drawn first, behind everything) ─────────────────

        // Long fading outer trail
        let longEnd = max(2, tailX - w * 1.60)
        let longRect = CGRect(x: longEnd, y: cy - h * 0.13, width: tailX - longEnd, height: h * 0.26)
        ctx.fill(Path(ellipseIn: longRect),
                 with: .linearGradient(
                    Gradient(stops: [
                        .init(color: .clear,                                  location: 0.00),
                        .init(color: Color(hex: "FF5500").opacity(0.12),      location: 0.55),
                        .init(color: Color(hex: "FF4400").opacity(0.28),      location: 1.00)
                    ]),
                    startPoint: CGPoint(x: longEnd, y: cy),
                    endPoint:   CGPoint(x: tailX,   y: cy)
                 ))

        // Medium orange flame
        let medEnd  = tailX - w * 0.82
        let medRect = CGRect(x: medEnd, y: cy - h * 0.26, width: tailX - medEnd, height: h * 0.52)
        ctx.fill(Path(ellipseIn: medRect),
                 with: .linearGradient(
                    Gradient(stops: [
                        .init(color: .clear,                                  location: 0.00),
                        .init(color: Color(hex: "FF6600").opacity(0.62),      location: 0.50),
                        .init(color: Color(hex: "FF4400").opacity(0.84),      location: 1.00)
                    ]),
                    startPoint: CGPoint(x: medEnd, y: cy),
                    endPoint:   CGPoint(x: tailX,  y: cy)
                 ))

        // Bright yellow-white core
        let coreEnd  = tailX - w * 0.38
        let coreRect = CGRect(x: coreEnd, y: cy - h * 0.11, width: tailX - coreEnd, height: h * 0.22)
        ctx.fill(Path(ellipseIn: coreRect),
                 with: .linearGradient(
                    Gradient(stops: [
                        .init(color: .clear,                                  location: 0.00),
                        .init(color: Color(hex: "FFEE44").opacity(0.88),      location: 0.45),
                        .init(color: Color(hex: "FFCC22").opacity(0.96),      location: 1.00)
                    ]),
                    startPoint: CGPoint(x: coreEnd, y: cy),
                    endPoint:   CGPoint(x: tailX,   y: cy)
                 ))

        // ── Top fin ───────────────────────────────────────────────────────
        var topFin = Path()
        topFin.move(to: CGPoint(x: tailX + w * 0.07, y: cy - bodyH * 0.46))
        topFin.addLine(to: CGPoint(x: tailX - w * 0.06, y: cy - bodyH * 1.02))
        topFin.addLine(to: CGPoint(x: tailX + w * 0.22, y: cy - bodyH * 0.46))
        topFin.closeSubpath()
        ctx.fill(topFin, with: .color(Color(white: 0.72, opacity: 0.92)))

        // ── Bottom fin ────────────────────────────────────────────────────
        var botFin = Path()
        botFin.move(to: CGPoint(x: tailX + w * 0.07, y: cy + bodyH * 0.46))
        botFin.addLine(to: CGPoint(x: tailX - w * 0.06, y: cy + bodyH * 1.02))
        botFin.addLine(to: CGPoint(x: tailX + w * 0.22, y: cy + bodyH * 0.46))
        botFin.closeSubpath()
        ctx.fill(botFin, with: .color(Color(white: 0.72, opacity: 0.92)))

        // ── Body (rounded rect) ───────────────────────────────────────────
        let bodyRect = CGRect(x: bodyX1, y: cy - bodyH * 0.50,
                              width: bodyX2 - bodyX1, height: bodyH)
        ctx.fill(Path(roundedRect: bodyRect, cornerRadius: bodyH * 0.38),
                 with: .color(Color(white: 0.91, opacity: 1)))

        // Body shading (subtle gradient from lighter top to slightly darker base)
        ctx.fill(Path(roundedRect: bodyRect, cornerRadius: bodyH * 0.38),
                 with: .linearGradient(
                    Gradient(colors: [Color.white.opacity(0.22), Color.black.opacity(0.08)]),
                    startPoint: CGPoint(x: bodyX1, y: cy - bodyH * 0.50),
                    endPoint:   CGPoint(x: bodyX1, y: cy + bodyH * 0.50)
                 ))

        // ── Nose cone (quad bezier, pointing right) ───────────────────────
        var nose = Path()
        nose.move(to: CGPoint(x: bodyX2, y: cy - bodyH * 0.46))
        nose.addQuadCurve(
            to:      CGPoint(x: noseX, y: cy),
            control: CGPoint(x: noseX - w * 0.06, y: cy - bodyH * 0.56)
        )
        nose.addQuadCurve(
            to:      CGPoint(x: bodyX2, y: cy + bodyH * 0.46),
            control: CGPoint(x: noseX - w * 0.06, y: cy + bodyH * 0.56)
        )
        nose.closeSubpath()
        ctx.fill(nose, with: .color(Color(white: 0.85, opacity: 1)))

        // ── Cockpit dome (dark ellipse in front portion of body) ──────────
        let cockCX = bodyX2 - (bodyX2 - bodyX1) * 0.34
        let cockRx: CGFloat = bodyH * 0.22
        let cockRy: CGFloat = bodyH * 0.34
        let cockRect = CGRect(x: cockCX - cockRx, y: cy - cockRy, width: cockRx * 2, height: cockRy * 2)
        ctx.fill(Path(ellipseIn: cockRect), with: .color(Color(hex: "111820").opacity(0.90)))
        // Tiny specular glint
        let glintRect = CGRect(x: cockCX - cockRx * 0.28, y: cy - cockRy * 0.68,
                               width: cockRx * 0.40, height: cockRy * 0.28)
        ctx.fill(Path(ellipseIn: glintRect), with: .color(Color.white.opacity(0.28)))
        ctx.stroke(Path(ellipseIn: cockRect), with: .color(Color.white.opacity(0.18)), lineWidth: 0.7)
    }

    // MARK: Profile bubble

    private func drawBubble(in ctx: inout GraphicsContext, cx: CGFloat, cy: CGFloat, friend: Friend) {
        // Bubble is offset slightly right (above the cockpit area)
        let bCX: CGFloat = cx + 10
        let bubbleR: CGFloat = 13
        let bubbleY = cy - 32           // center of bubble

        // Stem line
        var stem = Path()
        stem.move(to:  CGPoint(x: bCX, y: bubbleY + bubbleR + 1))
        stem.addLine(to: CGPoint(x: bCX, y: cy - 11))
        ctx.stroke(stem, with: .color(Color.white.opacity(0.32)), lineWidth: 0.8)

        // Connector dot (bottom of stem, where it meets the rocket)
        let dotR: CGFloat = 2.2
        ctx.fill(
            Path(ellipseIn: CGRect(x: bCX - dotR, y: cy - 11 - dotR, width: dotR*2, height: dotR*2)),
            with: .color(Color.white.opacity(0.56))
        )

        // Bubble circle (colored by friend's accent)
        let bubbleRect = CGRect(x: bCX - bubbleR, y: bubbleY - bubbleR, width: bubbleR*2, height: bubbleR*2)
        ctx.fill(Path(ellipseIn: bubbleRect), with: .color(Color(hex: friend.hexColor)))

        // Subtle inner glow
        let innerRect = CGRect(x: bCX - bubbleR * 0.65, y: bubbleY - bubbleR * 0.72,
                               width: bubbleR * 1.30, height: bubbleR * 1.44)
        ctx.fill(Path(ellipseIn: innerRect),
                 with: .linearGradient(
                    Gradient(colors: [Color.white.opacity(0.20), .clear]),
                    startPoint: CGPoint(x: bCX, y: bubbleY - bubbleR),
                    endPoint:   CGPoint(x: bCX, y: bubbleY)
                 ))

        // Border ring
        ctx.stroke(Path(ellipseIn: bubbleRect),
                   with: .color(Color.white.opacity(0.52)),
                   lineWidth: 1.0)

        // Initials text
        ctx.draw(
            Text(friend.initials)
                .font(.system(size: 7.5, weight: .bold, design: .rounded))
                .foregroundColor(.white),
            at: CGPoint(x: bCX, y: bubbleY),
            anchor: .center
        )
    }

    // MARK: Helpers

    private func unit(_ i: Int, _ salt: Int) -> CGFloat {
        let v   = Double(i &* 1_103_515_245 &+ salt &* 12_345)
        let raw = sin(v) * 43_758.5453123
        return CGFloat(raw - floor(raw))
    }
}
