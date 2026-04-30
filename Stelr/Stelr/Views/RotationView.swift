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
            Color.stelrBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // ── Header ────────────────────────────────────────────────
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("my rotation")
                                .font(.custom("Georgia", size: 31.4).weight(.semibold))
                                .foregroundColor(.stelrText)
                            Group {
                                Text("\(appState.myShows.count) shows · ") + Text("stelr").foregroundColor(.stelrAccent)
                            }
                            .font(.system(size: 12.8)).foregroundColor(.stelrMuted)
                        }
                        Spacer()
                        Button { showSearch = true } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 24.6, weight: .light))
                                .foregroundColor(.stelrAccent)
                                .frame(width: 42, height: 42)
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
                                    .font(.custom("Georgia", size: 16.2)).italic().foregroundColor(.stelrText)
                                Text("last rated \(n.lastChecked)")
                                    .font(.system(size: 11.8)).foregroundColor(.stelrMuted)
                            }
                            Spacer()
                            Button { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); activeVibeSheet = n } label: {
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
                VibeCheckSheet(show: show, currentScore: ms.score) { opt in
                    appState.updateVibeForMyShow(myShowId: ms.id, vibe: opt)
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
                    .font(.custom("Georgia", size: 18.4)).foregroundColor(.stelrText)
                    .padding(.bottom, 8)

                // Season stepper (fully wired)
                HStack(spacing: 8) {
                    Text("SEASON").font(.system(size: 10.8)).foregroundColor(.stelrMuted).kerning(0.55)
                    stepButton("‹") { onDecSeason() }
                    Text("S\(myShow.currentSeason)").font(.custom("Georgia", size: 16.8)).foregroundColor(.stelrText)
                    stepButton("›") { onIncSeason() }
                }
                .padding(.bottom, 7)

                HStack {
                    HStack(spacing: 6) {
                        Text("ep").font(.system(size: 10.9)).foregroundColor(.stelrMuted)
                        // Episode number bounces when incremented (scoreUpdate style)
                        Text("\(myShow.currentEpisode)")
                            .font(.custom("Georgia", size: 17.2)).foregroundColor(.stelrText)
                            .scaleEffect(epBumped ? 1.18 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: epBumped)
                        Text("/ \(myShow.totalEpisodes)").font(.system(size: 10.9)).foregroundColor(.stelrMuted)
                    }
                    Spacer()
                    if myShow.currentEpisode >= myShow.totalEpisodes {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("season finished")
                        }
                        .font(.system(size: 10.8, weight: .medium))
                        .foregroundColor(Color(hex: "72c97e"))
                        .padding(.trailing, 2)
                    }
                    HStack(spacing: 8) {
                        stepButton("−", size: 34, isDisabled: myShow.currentEpisode <= 1, action: onDecEp)
                        ZStack {
                            SeasonFinishFireworkView(active: seasonFirework)
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
                                    Color.vibrantHex(show.gradient1, lift: 0.34, saturation: 2.35),
                                    Color.vibrantHex(show.gradient2, lift: 0.38, saturation: 2.45)
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

                VibeWaveView(hexColor: VibeOption.hexColor(forScore: myShow.score), score: myShow.score, animate: false)
                .padding(.bottom, 9)

                // Friends watching
                if !watchingFriends.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(watchingFriends.prefix(3)) { f in
                            AvatarView(initials: f.initials, hexColor: f.hexColor, size: 25, showBorder: true)
                        }
                        Text(watchingFriends.count == 1 ? "\(watchingFriends[0].name) also watching" : "\(watchingFriends.count) friends watching")
                            .font(.system(size: 11.1)).foregroundColor(.stelrMuted)
                    }
                    .padding(.bottom, 9)
                }

                HStack(spacing: 8) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onVibeCheck()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "star").font(.system(size: 12.0))
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
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            } else {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        seasonFirework = false
        DispatchQueue.main.async {
            seasonFirework = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.92) {
                seasonFirework = false
            }
        }
    }
}

private struct SeasonFinishFireworkView: View {
    let active: Bool

    @State private var trailUp = false
    @State private var burst = false

    private let burstPieces: [(x: CGFloat, y: CGFloat, rotation: Double, length: CGFloat)] = [
        (-24, -66, -42, 9), (-12, -77, -18, 10), (0, -82, 0, 11),
        (13, -77, 18, 10), (25, -66, 42, 9), (-18, -55, -72, 8),
        (18, -55, 72, 8), (0, -61, 90, 7)
    ]

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 2.2, height: 2.2)
                    .offset(y: trailUp ? -8 - CGFloat(index) * 7 : 12)
                    .scaleEffect(trailUp ? 1 : 0.35)
                    .opacity(trailUp && !burst ? 1 : 0)
                    .animation(
                        .easeOut(duration: 0.24).delay(Double(index) * 0.014),
                        value: trailUp
                    )
                    .animation(.easeOut(duration: 0.12), value: burst)
            }

            ForEach(burstPieces.indices, id: \.self) { index in
                let piece = burstPieces[index]
                Capsule()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 2.3, height: piece.length)
                    .rotationEffect(.degrees(burst ? piece.rotation : 0))
                    .offset(
                        x: burst ? piece.x : 0,
                        y: burst ? piece.y : -46
                    )
                    .scaleEffect(burst ? 1 : 0.15)
                    .opacity(burst ? 1 : 0)
                    .animation(
                        .easeOut(duration: 0.38).delay(Double(index) * 0.012),
                        value: burst
                    )
            }

            Circle()
                .stroke(Color.white.opacity(burst ? 0.42 : 0), lineWidth: 1)
                .frame(width: burst ? 34 : 4, height: burst ? 34 : 4)
                .offset(y: -66)
                .opacity(burst ? 0.5 : 0)
                .animation(.easeOut(duration: 0.42), value: burst)
        }
        .frame(width: 34, height: 34)
        .onAppear {
            if active {
                launchFirework()
            }
        }
        .onChange(of: active) { _, newValue in
            if newValue {
                launchFirework()
            } else {
                resetFirework()
            }
        }
    }

    private func launchFirework() {
        resetFirework()
        DispatchQueue.main.async {
            trailUp = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                burst = true
            }
        }
    }

    private func resetFirework() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            trailUp = false
            burst = false
        }
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
                    .frame(width: 58, height: 58)
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 26.9, weight: .semibold))
                    .foregroundColor(Color(hex: show.accentColor))
            }
            .padding(.bottom, 14)

            Text("Tell everyone?")
                .font(.custom("Georgia", size: 24.6).italic())
                .foregroundColor(.stelrText)
                .padding(.bottom, 8)

            Text("This will send an alert to all your friends that \(show.title) is a must watch.")
                .font(.system(size: 15.7))
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
                            .font(.system(size: 15.7, weight: .semibold))
                        Text("send it!")
                    }
                }
                .font(.system(size: 17.9, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
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
