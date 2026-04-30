import SwiftUI

// "You" tab — your profile identity + active shows (My Shows) in one place.
// My Shows is not a separate tab; it lives here per the product handoff spec.

struct YouTabView: View {
    @EnvironmentObject var appState: AppState

    @State private var showAuthSheet   = false
    @State private var activeVibeSheet: MyShow?
    @State private var detailShow: Show?
    @State private var mustWatchShow: Show?
    @State private var showSearch      = false

    private var nudge: MyShow? { appState.myShows.first(where: { $0.needsVibeCheck }) }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.stelrBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── Header ────────────────────────────────────────────────
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("you")
                                .font(.custom("Georgia", size: 31.4).weight(.semibold))
                                .foregroundColor(.stelrText)
                            if appState.isAuthenticated,
                               let email = appState.supabase.currentUser?.email {
                                Text(email)
                                    .font(.system(size: 12.8)).foregroundColor(.stelrMuted)
                            } else {
                                Text("\(appState.myShows.count) shows watching")
                                    .font(.system(size: 12.8)).foregroundColor(.stelrMuted)
                            }
                        }
                        Spacer()
                        HStack(spacing: 10) {
                            // Add show button
                            Button { showSearch = true } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 22, weight: .light))
                                    .foregroundColor(.stelrAccent)
                                    .frame(width: 40, height: 40)
                                    .background(Color.stelrAccent.opacity(0.1))
                                    .overlay(Circle().stroke(Color.stelrAccent.opacity(0.27), lineWidth: 0.5))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.stelrPress)
                            // Settings / auth
                            Button { showAuthSheet = true } label: {
                                Image(systemName: appState.isAuthenticated ? "person.crop.circle" : "gearshape")
                                    .font(.system(size: 20))
                                    .foregroundColor(.stelrMuted)
                                    .frame(width: 40, height: 40)
                                    .background(Color.white.opacity(0.06))
                                    .overlay(Circle().stroke(Color.stelrBorder, lineWidth: 0.5))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.stelrPress)
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 66).padding(.bottom, 16)

                    // ── Stats strip ───────────────────────────────────────────
                    HStack(spacing: 0) {
                        statCell(value: "\(appState.myShows.count)", label: "Watching")
                        Divider().background(Color.stelrBorder).frame(height: 36)
                        statCell(value: "\(appState.friends.count)", label: "Friends")
                        Divider().background(Color.stelrBorder).frame(height: 36)
                        statCell(value: "\(appState.activities.count)", label: "Vibes logged")
                    }
                    .background(Color.stelrSurface)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.stelrBorder, lineWidth: 0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16).padding(.bottom, 20)

                    // ── Vibe check nudge ──────────────────────────────────────
                    if let n = nudge, let show = appState.show(for: n.showId) {
                        HStack(spacing: 15) {
                            MascotView(mood: .idle, size: 48)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(show.title) is due for a vibe check")
                                    .font(.custom("Georgia", size: 15.7)).italic().foregroundColor(.stelrText)
                                Text("last rated \(n.lastChecked)")
                                    .font(.system(size: 11.8)).foregroundColor(.stelrMuted)
                            }
                            Spacer()
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                activeVibeSheet = n
                            } label: {
                                Text("Rate")
                                    .font(.system(size: 13.8, weight: .semibold)).foregroundColor(.white)
                                    .padding(.horizontal, 13).padding(.vertical, 7)
                                    .background(Color.stelrAccent).clipShape(Capsule())
                            }
                        }
                        .padding(14)
                        .background(LinearGradient(
                            colors: [Color.stelrAccent.opacity(0.09), Color(hex: "c8903a").opacity(0.06)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.stelrAccent.opacity(0.19), lineWidth: 0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 16).padding(.bottom, 16)
                    }

                    // ── Section label ─────────────────────────────────────────
                    if !appState.myShows.isEmpty {
                        HStack {
                            Text("WATCHING NOW")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(.stelrMuted).kerning(0.8)
                            Spacer()
                        }
                        .padding(.horizontal, 20).padding(.bottom, 8)
                    }

                    // ── Show list ─────────────────────────────────────────────
                    VStack(spacing: 0) {
                        ForEach(appState.myShows) { ms in
                            if let show = appState.show(for: ms.showId) {
                                YouShowRow(
                                    myShow: ms,
                                    show: show,
                                    watchingFriends: appState.friendsWatching(showId: show.id),
                                    onVibeCheck: { activeVibeSheet = ms },
                                    onTellEveryone: { mustWatchShow = show },
                                    onDetail: { detailShow = show },
                                    onLogEp: { appState.logEpisode(myShowId: ms.id) },
                                    onDecEp: { appState.decrementEpisode(myShowId: ms.id) },
                                    onIncSeason: { appState.incrementSeason(myShowId: ms.id) },
                                    onDecSeason: { appState.decrementSeason(myShowId: ms.id) }
                                )
                                .padding(.horizontal, 12)
                                if ms.id != appState.myShows.last?.id {
                                    Divider().background(Color.stelrBorder).padding(.horizontal, 12)
                                }
                            }
                        }
                    }

                    if appState.myShows.isEmpty {
                        VStack(spacing: 14) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 38, weight: .ultraLight))
                                .foregroundColor(.stelrMuted)
                            Text("your constellation is empty")
                                .font(.custom("Georgia", size: 18.4)).italic().foregroundColor(.stelrText)
                            Text("search for a show and add it to start watching")
                                .font(.system(size: 13.4)).foregroundColor(.stelrMuted).multilineTextAlignment(.center)
                            Button { showSearch = true } label: {
                                Text("Find a show")
                                    .font(.system(size: 15.7, weight: .semibold)).foregroundColor(.white)
                                    .padding(.horizontal, 24).padding(.vertical, 12)
                                    .background(Color.stelrAccent).clipShape(Capsule())
                            }
                            .buttonStyle(.stelrPress)
                        }
                        .padding(.top, 48).padding(.horizontal, 32)
                    }

                    Spacer(minLength: 96)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .sheet(item: $activeVibeSheet) { ms in
            if let show = appState.show(for: ms.showId) {
                VibeCheckSheet(show: show, currentVibe: ms.vibe) { opt in
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
        .sheet(isPresented: $showAuthSheet) {
            if appState.isAuthenticated {
                ProfileSettingsSheet()
            } else {
                AuthSheet()
            }
        }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.custom("Georgia", size: 24.6).weight(.semibold)).foregroundColor(.stelrText)
            Text(label)
                .font(.system(size: 11.5)).foregroundColor(.stelrMuted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
    }
}

// ── Inline profile settings (accessed when authenticated) ─────────────────────

private struct ProfileSettingsSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color.white.opacity(0.18)).frame(width: 36, height: 4).padding(.top, 8).padding(.bottom, 18)
            HStack {
                Text("account")
                    .font(.custom("Georgia", size: 22.4).weight(.semibold)).foregroundColor(.stelrText)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.stelrMuted).frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.07)).clipShape(Circle())
                }
                .buttonStyle(.stelrPress)
            }
            .padding(.horizontal, 18).padding(.bottom, 20)

            if let email = appState.supabase.currentUser?.email {
                Text(email).font(.system(size: 15.7)).foregroundColor(.stelrMuted).padding(.bottom, 24)
            }

            Button {
                Task {
                    try? await appState.supabase.signOut()
                    appState.isAuthenticated = false
                    dismiss()
                }
            } label: {
                Text("Sign out")
                    .font(.system(size: 16.8, weight: .medium)).foregroundColor(.stelrMuted)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(Color.white.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.stelrBorder, lineWidth: 0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 18)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(hex: "1c1814").ignoresSafeArea())
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }
}

// ── MustWatchAlertSheet forwarded from RotationView ───────────────────────────
// (defined in RotationView.swift — accessed here via type reference)

private struct MustWatchAlertSheet: View {
    let show: Show
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var sending = false
    @State private var sent = false

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color.white.opacity(0.18)).frame(width: 36, height: 4).padding(.top, 8).padding(.bottom, 18)
            ZStack {
                Circle().fill(Color(hex: show.accentColor).opacity(0.14))
                    .overlay(Circle().stroke(Color(hex: show.accentColor).opacity(0.35), lineWidth: 1))
                    .frame(width: 56, height: 56)
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundColor(Color(hex: show.accentColor))
            }
            .padding(.bottom, 12)
            Text("Tell everyone?")
                .font(.custom("Georgia", size: 24.6).italic()).foregroundColor(.stelrText).padding(.bottom, 8)
            Text("This will send an alert to all your friends that \(show.title) is a must watch.")
                .font(.system(size: 15.7)).foregroundColor(.stelrMuted).multilineTextAlignment(.center)
                .lineSpacing(3).padding(.horizontal, 28).padding(.bottom, 18)
            Button {
                sending = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation { sending = false; sent = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { dismiss() }
                }
            } label: {
                HStack(spacing: 8) {
                    if sent { Text("✓ sent!") }
                    else if sending { ProgressView().tint(.white); Text("sending…") }
                    else { Image(systemName: "paperplane.fill"); Text("send it!") }
                }
                .font(.system(size: 17.9, weight: .semibold)).foregroundColor(.white)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(sent ? Color(hex: "72c97e") : Color.stelrAccent)
                .clipShape(RoundedRectangle(cornerRadius: 15))
            }
            .disabled(sending || sent).padding(.horizontal, 18)
            Button { dismiss() } label: {
                Text("not now").font(.system(size: 14.6, weight: .medium)).foregroundColor(.stelrMuted)
                    .padding(.top, 13).padding(.bottom, 18)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(hex: "1c1814").ignoresSafeArea())
        .safeAreaPadding(.bottom)
        .presentationDetents([.height(330)])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }
}

// ── YouShowRow — compact show row for You tab ─────────────────────────────────
// Mirrors MyShowRow from RotationView but with slightly tighter spacing.

private struct YouShowRow: View {
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
        HStack(alignment: .top, spacing: 14) {
            // Poster
            Button(action: onDetail) {
                ShowPosterView(show: show, width: 86, height: 120, radius: 13) {
                    VStack {
                        Spacer()
                        LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
                            .frame(height: 40)
                            .overlay(
                                Text(show.platform).font(.system(size: 11)).foregroundColor(.white.opacity(0.6))
                                    .padding(.bottom, 7), alignment: .bottom
                            )
                    }
                }
            }
            .buttonStyle(.stelrPress)

            VStack(alignment: .leading, spacing: 0) {
                Text(show.title)
                    .font(.custom("Georgia", size: 17.4)).foregroundColor(.stelrText)
                    .padding(.bottom, 7)

                // Season stepper
                HStack(spacing: 7) {
                    Text("S").font(.system(size: 10.5)).foregroundColor(.stelrMuted).kerning(0.4)
                    stepBtn("‹") { onDecSeason() }
                    Text("\(myShow.currentSeason)").font(.custom("Georgia", size: 15.7)).foregroundColor(.stelrText)
                    stepBtn("›") { onIncSeason() }
                }
                .padding(.bottom, 6)

                // Episode row
                HStack {
                    HStack(spacing: 5) {
                        Text("ep").font(.system(size: 10.5)).foregroundColor(.stelrMuted)
                        Text("\(myShow.currentEpisode)")
                            .font(.custom("Georgia", size: 16.2)).foregroundColor(.stelrText)
                            .scaleEffect(epBumped ? 1.18 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: epBumped)
                        Text("/ \(myShow.totalEpisodes)").font(.system(size: 10.5)).foregroundColor(.stelrMuted)
                    }
                    Spacer()
                    if myShow.currentEpisode >= myShow.totalEpisodes {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("done")
                        }
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(Color(hex: "72c97e"))
                    }
                    HStack(spacing: 7) {
                        stepBtn("−", sz: 32, disabled: myShow.currentEpisode <= 1, action: onDecEp)
                        ZStack {
                            SeasonFinishFireworkView(
                                active: seasonFirework,
                                primaryColor: Color.vibrantHex(show.gradient1, lift: 0.36, saturation: 1.45),
                                secondaryColor: Color.vibrantHex(show.gradient2, lift: 0.4, saturation: 1.5)
                            )
                            .zIndex(0)
                            .allowsHitTesting(false)
                            Circle().fill(Color.stelrBg).frame(width: 32, height: 32).zIndex(1).allowsHitTesting(false)
                            stepBtn("+", sz: 32, disabled: myShow.currentEpisode >= myShow.totalEpisodes) {
                                let finishes = myShow.currentEpisode + 1 >= myShow.totalEpisodes
                                onLogEp()
                                epBumped = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { epBumped = false }
                                if finishes { triggerFirework() }
                            }
                            .zIndex(2)
                        }
                    }
                }
                .padding(.bottom, 5)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.08)).frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: vOpt.hexColor))
                            .frame(width: geo.size.width * progress, height: 4)
                            .animation(.spring(response: 0.45, dampingFraction: 0.62), value: progress)
                    }
                }
                .frame(height: 4).padding(.bottom, 8)

                // Vibe badge + orb
                HStack(alignment: .center, spacing: 8) {
                    Text("\(vOpt.emoji) \(vOpt.label)")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(Color(hex: vOpt.hexColor))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color(hex: vOpt.hexColor).opacity(0.12))
                        .clipShape(Capsule())
                    VibeWaveView(vibe: vOpt, size: 12, animate: true)
                }
                .padding(.bottom, 7)

                // Action buttons
                HStack(spacing: 7) {
                    actionBtn(icon: "star", label: "vibe check", action: onVibeCheck)
                    actionBtn(icon: "megaphone", label: "tell everyone", action: onTellEveryone)
                }
            }
        }
        .padding(.vertical, 22)
    }

    private func stepBtn(_ label: String, sz: CGFloat = 24, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: sz >= 32 ? .rigid : .light).impactOccurred()
            action()
        } label: {
            Text(label)
                .font(.system(size: sz == 24 ? 13.8 : 17.4))
                .foregroundColor(.stelrMuted)
                .frame(width: sz, height: sz)
                .background(Color.white.opacity(0.06))
                .overlay(Circle().stroke(Color.stelrBorder, lineWidth: 0.5))
                .clipShape(Circle())
                .opacity(disabled ? 0.35 : 1)
        }
        .disabled(disabled)
        .buttonStyle(.stelrPress)
    }

    private func actionBtn(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11.5))
                Text(label).font(.system(size: 12.5, weight: .medium))
            }
            .foregroundColor(.stelrMuted)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.white.opacity(0.05))
            .overlay(Capsule().stroke(Color.stelrBorder, lineWidth: 0.5))
            .clipShape(Capsule())
        }
        .buttonStyle(.stelrPress)
    }

    private func triggerFirework() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        seasonFirework = false
        DispatchQueue.main.async {
            seasonFirework = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) { seasonFirework = false }
        }
    }
}
