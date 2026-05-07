import SwiftUI

struct RotationView: View {
    var animateEntrance: Bool = true
    var animationToken: Int = 0

    @EnvironmentObject var appState: AppState
    @State private var activeVibeSheet: MyShow?
    @State private var detailShow: Show?
    @State private var showSearch = false
    @State private var mustWatchShow: Show?
    @State private var appeared = false

    private var nudge: MyShow? { appState.myShows.first(where: { $0.needsVibeCheck }) }

    var body: some View {
        ZStack(alignment: .bottom) {
            StelrStarFieldBackground().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // ── Header ────────────────────────────────────────────────
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("my rotation")
                                .font(StelrTypography.pageTitle)
                                .foregroundColor(.stelrText)
                            Group {
                                Text("\(appState.myShows.count) shows · ") + Text("stelr").foregroundColor(.stelrAccent)
                            }
                            .font(.system(size: 12.8)).foregroundColor(.stelrMuted)
                        }
                        Spacer()
                        Button { showSearch = true } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 18.5, weight: .light))
                                .foregroundColor(.stelrAccent)
                                .frame(width: 36, height: 36)
                                .background(Color.stelrAccent.opacity(0.1))
                                .overlay(Circle().stroke(Color.stelrAccent.opacity(0.27), lineWidth: 0.5))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 66).padding(.bottom, 14)

                    // ── Mascot nudge ──────────────────────────────────────────
                    if let n = nudge, let show = appState.show(for: n.showId) {
                        HStack(spacing: 15) {
                            MascotView(mood: .idle, size: 50)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(show.title) is due for a vibe check")
                                    .font(StelrTypography.sectionTitle).italic().foregroundColor(.stelrText)
                                Text("last rated \(n.lastChecked)")
                                    .font(.system(size: 11.8)).foregroundColor(.stelrMuted)
                            }
                            Spacer()
                            Button { StelrHaptics.mediumTap(); activeVibeSheet = n } label: {
                                Text("Rate")
                                    .font(.system(size: 14.2, weight: .semibold)).foregroundColor(.white)
                                    .padding(.horizontal, 15).padding(.vertical, 8)
                                    .background(Color.stelrAccent).clipShape(Capsule())
                            }
                        }
                        .padding(16)
                        .background(LinearGradient(colors: [Color.stelrAccent.opacity(0.09), Color(hex: "c8903a").opacity(0.06)], startPoint: .leading, endPoint: .trailing))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.stelrAccent.opacity(0.19), lineWidth: 0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16).padding(.bottom, 16)
                    }

                    // ── Show list ─────────────────────────────────────────────
                    VStack(spacing: 0) {
                        ForEach(Array(appState.myShows.enumerated()), id: \.element.id) { idx, ms in
                            if let show = appState.show(for: ms.showId) {
                                MyShowRow(myShow: ms, show: show,
                                          watchingFriends: appState.friendsWatching(showId: show.id),
                                          onVibeCheck: { activeVibeSheet = ms },
                                          onTellEveryone: { mustWatchShow = show },
                                          onDetail: { detailShow = show },
                                          onLogEp: { appState.logEpisode(myShowId: ms.id) },
                                          onDecEp: { appState.decrementEpisode(myShowId: ms.id) },
                                          onIncSeason: { appState.incrementSeason(myShowId: ms.id) },
                                          onDecSeason: { appState.decrementSeason(myShowId: ms.id) })
                                    .padding(.horizontal, 12)
                                    .opacity(appeared ? 1 : 0)
                                    .offset(y: appeared ? 0 : 24)
                                    .animation(
                                        .spring(response: 0.48, dampingFraction: 0.72)
                                            .delay(Double(idx) * 0.09),
                                        value: appeared
                                    )
                                if idx < appState.myShows.count - 1 {
                                    Divider().background(Color.stelrBorder).padding(.horizontal, 12)
                                        .opacity(appeared ? 1 : 0)
                                        .animation(.easeInOut(duration: 0.3).delay(Double(idx) * 0.09 + 0.1), value: appeared)
                                }
                            }
                        }
                    }
                    .onAppear {
                        runEntranceAnimation()
                    }
                    .onChange(of: animationToken) { _, _ in
                        runEntranceAnimation()
                    }

                    Spacer(minLength: 80)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .sheet(item: $activeVibeSheet) { ms in
            if let show = appState.show(for: ms.showId) {
                VibeCheckSheet(show: show, currentMyShow: ms) { season, episode, score in
                    appState.submitCheckIn(show: show, season: season, episode: episode, score: score)
                } onSeasonRating: { season, rating in
                    appState.submitSeasonRating(showId: show.id, season: season, score: rating)
                }
            }
        }
        .sheet(item: $detailShow) { show in
            ShowDetailView(show: show, watchingFriends: appState.friendsWatching(showId: show.id))
        }
        .sheet(item: $mustWatchShow) { show in
            MustWatchAlertSheet(show: show)
        }
        .sheet(isPresented: $showSearch) {
            ShowSearchSheet()
        }
    }

    private func runEntranceAnimation() {
        if animateEntrance {
            appeared = false
            withAnimation { appeared = true }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                appeared = true
            }
        }
    }
}

private struct MyShowRow: View {
    let myShow: MyShow
    let show: Show
    let watchingFriends: [Friend]
    var onVibeCheck: () -> Void
    var onTellEveryone: () -> Void
    var onDetail: () -> Void
    var onLogEp: () -> Void
    var onDecEp: () -> Void
    var onIncSeason: () -> Void
    var onDecSeason: () -> Void

    @State private var epBumped = false
    @State private var seasonFirework = false

    private var vOpt: VibeOption { myShow.vibe }
    private var ratingColor: Color { H7bStarVisualStyle.ratingColor(appScore: myShow.score) }
    private var progress: Double { Double(myShow.currentEpisode) / Double(max(1, myShow.totalEpisodes)) }

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            // Poster
            Button(action: onDetail) {
                ShowPosterView(show: show, width: 92, height: 128, radius: 14) {
                    VStack {
                        Spacer()
                        LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
                            .frame(height: 44)
                            .overlay(
                                Text(show.platform).font(.system(size: 11.8)).foregroundColor(.white.opacity(0.6))
                                    .padding(.bottom, 8),
                                alignment: .bottom
                            )
                    }
                }
            }
            .buttonStyle(.stelrPress)

            VStack(alignment: .leading, spacing: 0) {
                Text(show.title)
                    .font(StelrTypography.sectionTitle).foregroundColor(.stelrText)
                    .padding(.bottom, 8)

                // Season stepper (fully wired)
                HStack(spacing: 8) {
                    Text("SEASON").font(.system(size: 10.8)).foregroundColor(.stelrMuted).kerning(0.55)
                    stepButton("‹") { onDecSeason() }
                    Text("S\(myShow.currentSeason)").font(StelrTypography.sectionTitle).foregroundColor(.stelrText)
                    stepButton("›") { onIncSeason() }
                }
                .padding(.bottom, 7)

                HStack {
                    HStack(spacing: 6) {
                        Text("ep").font(.system(size: 10.9)).foregroundColor(.stelrMuted)
                        // Episode number bounces when incremented (scoreUpdate style)
                        Text("\(myShow.currentEpisode)")
                            .font(StelrTypography.sectionTitle).foregroundColor(.stelrText)
                            .scaleEffect(epBumped ? 1.18 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: epBumped)
                        Text("/ \(myShow.totalEpisodes)").font(.system(size: 10.9)).foregroundColor(.stelrMuted)
                    }
                    Spacer()
                    if myShow.currentEpisode >= myShow.totalEpisodes {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13.2, weight: .medium))
                        .foregroundColor(Color(hex: "72c97e"))
                        .padding(.trailing, 2)
                    }
                    HStack(spacing: 8) {
                        stepButton("−", size: 34, isDisabled: myShow.currentEpisode <= 1, action: onDecEp)
                        ZStack {
                            SeasonFinishFireworkView(
                                active: seasonFirework,
                                primaryColor: Color.vibrantHex(show.gradient1, lift: 0.36, saturation: 1.45),
                                secondaryColor: Color.vibrantHex(show.gradient2, lift: 0.4, saturation: 1.5)
                            )
                            .zIndex(0)
                            .allowsHitTesting(false)

                            Circle()
                                .fill(Color.stelrBg)
                                .frame(width: 34, height: 34)
                                .zIndex(1)
                                .allowsHitTesting(false)

                            stepButton("+", size: 34, isDisabled: myShow.currentEpisode >= myShow.totalEpisodes) {
                                let finishesSeason = myShow.currentEpisode + 1 >= myShow.totalEpisodes
                                onLogEp()
                                // bump animation
                                epBumped = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { epBumped = false }
                                if finishesSeason {
                                    triggerSeasonFirework()
                                }
                            }
                            .zIndex(2)
                        }
                    }
                }
                .padding(.bottom, 6)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2.5).fill(Color.white.opacity(0.08)).frame(height: 5)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(LinearGradient(
                                colors: [
                                    Color.vibrantHex(show.gradient1, lift: 0.36, saturation: 1.45),
                                    Color.vibrantHex(show.gradient2, lift: 0.4, saturation: 1.5)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * progress, height: 5)
                            // spring with slight overshoot matches mockup cubic-bezier(0.34,1.56,0.64,1)
                            .animation(.spring(response: 0.45, dampingFraction: 0.62), value: progress)
                    }
                }
                .frame(height: 5).padding(.bottom, 10)

                HStack(alignment: .center, spacing: 8) {
                    Text("\(vOpt.emoji) \(vOpt.label)")
                        .font(.system(size: 13.2, weight: .medium))
                        .foregroundColor(ratingColor)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(ratingColor.opacity(0.12))
                        .clipShape(Capsule())
                    VibeWaveView(vibe: vOpt, score: myShow.score, size: 14, animate: true)
                }
                .padding(.bottom, 9)

                // Friends watching
                if !watchingFriends.isEmpty {
                    FriendStackView(friends: watchingFriends, avatarSize: 25)
                    .padding(.bottom, 9)
                }

                HStack(spacing: 8) {
                    Button {
                        StelrHaptics.mediumTap()
                        onVibeCheck()
                    } label: {
                        HStack(spacing: 5) {
                            StelrFourPointStar(variant: .twinkle)
                                .fill(Color.stelrMuted)
                                .frame(width: 12, height: 12)
                            Text("vibe check").font(.system(size: 13.2, weight: .medium))
                        }
                        .foregroundColor(.stelrMuted)
                        .padding(.horizontal, 11).padding(.vertical, 7)
                        .background(Color.white.opacity(0.05))
                        .overlay(Capsule().stroke(Color.stelrBorder, lineWidth: 0.5))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.stelrPress)

                    Button {
                        StelrHaptics.lightTap()
                        onTellEveryone()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "megaphone").font(.system(size: 12.0))
                            Text("tell everyone").font(.system(size: 13.2, weight: .medium))
                        }
                        .foregroundColor(.stelrMuted)
                        .padding(.horizontal, 11).padding(.vertical, 7)
                        .background(Color.white.opacity(0.05))
                        .overlay(Capsule().stroke(Color.stelrBorder, lineWidth: 0.5))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.stelrPress)
                }
            }
        }
        .padding(.vertical, 26)
    }

    private func stepButton(_ label: String, size: CGFloat = 26, isDisabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            guard !isDisabled else { return }
            // Episode buttons (34pt) get a crisp rigid tap; season buttons (26pt) get a lighter click
            if size >= 34 {
                StelrHaptics.firmTap()
            } else {
                StelrHaptics.lightTap()
            }
            action()
        } label: {
            Text(label)
                .font(.system(size: size == 26 ? 14.8 : 18.2))
                .foregroundColor(.stelrMuted)
                .frame(width: size, height: size)
                .background(Color.white.opacity(0.06))
                .overlay(Circle().stroke(Color.stelrBorder, lineWidth: 0.5))
                .clipShape(Circle())
                .opacity(isDisabled ? 0.35 : 1)
        }
        .disabled(isDisabled)
        .buttonStyle(.stelrPress)
    }

    private func triggerSeasonFirework() {
        StelrHaptics.success()
        seasonFirework = false
        DispatchQueue.main.async {
            seasonFirework = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.98) {
                seasonFirework = false
            }
        }
    }
}

struct SeasonFinishFireworkView: View {
    let active: Bool
    let primaryColor: Color
    let secondaryColor: Color

    @State private var launchDate: Date?
    @State private var isRunning = false

    private let launchDuration: TimeInterval = 0.24
    private let bloomDuration: TimeInterval = 0.68
    private let canvasSize: CGFloat = 168
    private let centerX: CGFloat = 84
    private let launchStartY: CGFloat = 84
    private let bloomY: CGFloat = 36

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: !isRunning)) { timeline in
            Canvas { context, _ in
                guard let launchDate else { return }
                let elapsed = timeline.date.timeIntervalSince(launchDate)
                guard elapsed <= launchDuration + bloomDuration else { return }

                drawLaunchTrail(in: context, elapsed: elapsed)
                if elapsed > launchDuration {
                    drawLottieBloom(in: context, elapsed: elapsed - launchDuration)
                }
            }
            .frame(width: canvasSize, height: canvasSize)
        }
        .frame(width: 34, height: 34)
        .allowsHitTesting(false)
        .onAppear {
            if active {
                launch()
            }
        }
        .onChange(of: active) { _, newValue in
            if newValue {
                launch()
            } else {
                reset()
            }
        }
    }

    private func launch() {
        launchDate = Date()
        isRunning = true
        DispatchQueue.main.asyncAfter(deadline: .now() + launchDuration + bloomDuration + 0.06) {
            reset()
        }
    }

    private func reset() {
        isRunning = false
        launchDate = nil
    }

    private func drawLaunchTrail(in context: GraphicsContext, elapsed: TimeInterval) {
        let progress = min(max(CGFloat(elapsed / launchDuration), 0), 1)
        let currentY = launchStartY - (launchStartY - bloomY) * progress
        let fade = 1 - max(0, progress - 0.86) / 0.14

        for index in 0..<6 {
            let y = currentY + CGFloat(index) * 9
            guard y <= launchStartY + 2, y >= bloomY - 2 else { continue }
            let opacity = max(0, 0.9 - Double(index) * 0.14) * Double(fade)
            context.fill(
                Path(ellipseIn: CGRect(x: centerX - 1.1, y: y - 1.1, width: 2.2, height: 2.2)),
                with: .color(primaryColor.opacity(opacity))
            )
        }
    }

    private func drawLottieBloom(in context: GraphicsContext, elapsed: TimeInterval) {
        let frame = min(max(CGFloat(elapsed / bloomDuration) * AppleBloomLottieAsset.endFrame, 0), AppleBloomLottieAsset.endFrame)
        let center = CGPoint(x: centerX, y: bloomY)

        let flashScale = interpolated(frame: frame, points: [(0, 20), (8, 170), (14, 60)])
        let flashOpacity = interpolated(frame: frame, points: [(0, 0), (3, 0.34), (14, 0)])
        if flashOpacity > 0 {
            let diameter = 8 * flashScale / 100
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)),
                with: .color(secondaryColor.opacity(Double(flashOpacity)))
            )
        }

        for (index, rotation) in AppleBloomLottieAsset.particleRotations.enumerated() {
            let delay = CGFloat(AppleBloomLottieAsset.particleDelays[index % AppleBloomLottieAsset.particleDelays.count])
            let localFrame = max(0, frame - delay)
            let distance = interpolated(frame: localFrame, points: [(0, 0), (18, 50.6), (54, 92)]) * 0.28
            let scale = interpolated(frame: localFrame, points: [(0, 15), (16, 100), (44, 88), (54, 72)])
            let opacity = interpolated(frame: localFrame, points: [(0, 0), (4, 0.78), (34, 0.78), (54, 0)])
            guard opacity > 0 else { continue }

            let angle = rotation * .pi / 180
            let point = CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance)
            let diameter = 4.2 * scale / 100
            let particleColor = index.isMultiple(of: 2) ? primaryColor : secondaryColor

            context.fill(
                Path(ellipseIn: CGRect(x: point.x - diameter * 1.2, y: point.y - diameter * 1.2, width: diameter * 2.4, height: diameter * 2.4)),
                with: .color(particleColor.opacity(Double(opacity) * 0.1))
            )
            context.fill(
                Path(ellipseIn: CGRect(x: point.x - diameter / 2, y: point.y - diameter / 2, width: diameter, height: diameter)),
                with: .color(particleColor.opacity(Double(opacity)))
            )
        }
    }

    private func interpolated(frame: CGFloat, points: [(CGFloat, CGFloat)]) -> CGFloat {
        guard let first = points.first else { return 0 }
        guard frame > first.0 else { return first.1 }
        for index in 0..<(points.count - 1) {
            let start = points[index]
            let end = points[index + 1]
            if frame <= end.0 {
                let raw = (frame - start.0) / max(end.0 - start.0, 0.001)
                let eased = raw * raw * (3 - 2 * raw)
                return start.1 + (end.1 - start.1) * eased
            }
        }
        return points.last?.1 ?? first.1
    }
}

private enum AppleBloomLottieAsset {
    static let endFrame: CGFloat = 60
    static let particleDelays: [Int] = [0, 1, 0, 2, 1, 0, 2, 1, 0, 2, 1, 0]
    static let particleRotations: [CGFloat] = loadParticleRotations()

    private static func loadParticleRotations() -> [CGFloat] {
        guard
            let url = Bundle.main.url(forResource: "apple_fuller_bloom_firework", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let layers = object["layers"] as? [[String: Any]]
        else {
            return stride(from: 0, to: 360, by: 30).map(CGFloat.init)
        }

        let rotations = layers.compactMap { layer -> CGFloat? in
            guard (layer["nm"] as? String)?.hasPrefix("Particle") == true,
                  let ks = layer["ks"] as? [String: Any],
                  let rotation = ks["r"] as? [String: Any] else {
                return nil
            }
            if let value = rotation["k"] as? Double {
                return CGFloat(value)
            }
            if let value = rotation["k"] as? Int {
                return CGFloat(value)
            }
            return nil
        }

        return rotations.isEmpty ? stride(from: 0, to: 360, by: 30).map(CGFloat.init) : rotations
    }
}

private struct MustWatchAlertSheet: View {
    let show: Show
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var sending = false
    @State private var sent = false

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 18)

            ZStack {
                Circle()
                    .fill(Color(hex: show.accentColor).opacity(0.14))
                    .overlay(Circle().stroke(Color(hex: show.accentColor).opacity(0.35), lineWidth: 1))
                    .frame(width: 48, height: 48)
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(Color(hex: show.accentColor))
            }
            .padding(.bottom, 14)

            Text("Tell everyone?")
                .font(StelrTypography.bodyStrong)
                .foregroundColor(.stelrText)
                .padding(.bottom, 8)

            Text("This will send an alert to all your friends that \(show.title) is a must watch.")
                .font(StelrTypography.callout)
                .foregroundColor(.stelrMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 28)
                .padding(.bottom, 18)

            Button {
                sendAlert()
            } label: {
                HStack(spacing: 8) {
                    if sent {
                        Text("✓ sent!")
                    } else if sending {
                        ProgressView().tint(.white)
                        Text("sending...")
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(StelrTypography.buttonSmall)
                        Text("send it!")
                    }
                }
                .font(StelrTypography.button)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(sent ? Color(hex: "72c97e") : Color.stelrAccent)
                .clipShape(RoundedRectangle(cornerRadius: 15))
            }
            .disabled(sending || sent)
            .padding(.horizontal, 18)

            Button { dismiss() } label: {
                Text("not now")
                    .font(.system(size: 14.6, weight: .medium))
                    .foregroundColor(.stelrMuted)
                    .padding(.top, 13)
                    .padding(.bottom, 10)
            }
            .buttonStyle(.stelrPress)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(hex: "1c1814").ignoresSafeArea())
        .presentationDetents([.height(306)])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }

    private func sendAlert() {
        sending = true
        if appState.isAuthenticated {
            let friendIds = appState.friends.map { $0.hexColor }
            Task {
                try? await appState.supabase.sendRecommendation(
                    showId: show.id,
                    toUserIds: friendIds,
                    message: "\(show.title) is a must watch."
                )
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation {
                sending = false
                sent = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                dismiss()
            }
        }
    }
}
