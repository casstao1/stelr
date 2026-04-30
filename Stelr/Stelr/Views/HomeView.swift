import SwiftUI

struct HomeView: View {
    var initialFriendIndex: Int = 0

    @EnvironmentObject var appState: AppState
    @State private var heroIdx = 0
    @State private var showVibeSheet = false
    @State private var showRally = false
    @State private var detailShow: Show?
    @State private var showLiveFeed = false
    @State private var profileFriend: Friend?

    private var hero: Friend { appState.friends[heroIdx] }
    private var heroShow: Show { appState.show(for: hero.currentShowId) ?? Show.samples[0] }
    private var vibeOpt: VibeOption { hero.vibe }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.stelrBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // ── Header ───────────────────────────────────────────────
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("stelr")
                                .font(.custom("Georgia", size: 26.9).weight(.semibold))
                                .foregroundColor(.stelrText)
                            Text("what your people are watching")
                                .font(.system(size: 12.3)).foregroundColor(.stelrMuted)
                        }
                        Spacer()
                        Button { UIImpactFeedbackGenerator(style: .light).impactOccurred(); showLiveFeed = true } label: {
                            ZStack(alignment: .topTrailing) {
                                Circle().fill(Color.white.opacity(0.06))
                                    .overlay(Circle().stroke(Color.stelrBorder, lineWidth: 0.5))
                                    .frame(width: 34, height: 34)
                                Image(systemName: "mappin").font(.system(size: 15.7)).foregroundColor(.stelrMuted)
                                    .frame(width: 34, height: 34)
                                Circle().fill(Color.stelrAccent).frame(width: 7, height: 7)
                                    .overlay(Circle().stroke(Color.stelrBg, lineWidth: 1.5))
                                    .offset(x: 2, y: -2)
                            }
                        }
                        .buttonStyle(.stelrPress)
                    }
                    .padding(.horizontal, 20).padding(.top, 66).padding(.bottom, 10)

                    // ── Friend strip ─────────────────────────────────────────
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(Array(appState.friends.enumerated()), id: \.element.id) { idx, friend in
                                Button {
                                    UISelectionFeedbackGenerator().selectionChanged()
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                                        heroIdx = idx
                                    }
                                } label: {
                                    VStack(spacing: 5) {
                                        AvatarView(initials: friend.initials, hexColor: friend.hexColor, size: 38,
                                                   showBorder: idx == heroIdx)
                                            .padding(2)
                                            .overlay(Circle().stroke(idx == heroIdx ? Color(hex: friend.hexColor) : .clear, lineWidth: 2))
                                        Text(friend.name)
                                            .font(.system(size: 11.2))
                                            .foregroundColor(idx == heroIdx ? .stelrText : .stelrMuted)
                                    }
                                }
                                .buttonStyle(.stelrPress)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 14)

                    // ── Hero card (cardIn animation on change) ────────────────
                    GeometryReader { geo in
                        ShowPosterView(show: heroShow, width: geo.size.width, height: 264, radius: 18) {
                            LinearGradient(colors: [.black.opacity(0.08), .black.opacity(0.55)],
                                           startPoint: .top, endPoint: .bottom)
                            VStack(spacing: 0) {
                                // Top row
                                HStack(alignment: .center, spacing: 9) {
                                    Button { profileFriend = hero } label: {
                                        HStack(spacing: 9) {
                                            AvatarView(initials: hero.initials, hexColor: hero.hexColor, size: 30)
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(hero.name)
                                                    .font(.system(size: 14.0, weight: .medium))
                                                    .foregroundColor(.white.opacity(0.92))
                                                Text(heroShow.currentEpisode)
                                                    .font(.system(size: 11.8))
                                                    .foregroundColor(.white.opacity(0.5))
                                            }
                                        }
                                    }
                                    .buttonStyle(.stelrPress)
                                    Spacer()
                                    Text("\(vibeOpt.emoji) \(vibeOpt.label)")
                                        .font(.system(size: 12.3))
                                        .foregroundColor(Color(hex: vibeOpt.hexColor))
                                        .padding(.horizontal, 10).padding(.vertical, 4)
                                        .background(Color(hex: vibeOpt.hexColor).opacity(0.13))
                                        .overlay(Capsule().stroke(Color(hex: vibeOpt.hexColor).opacity(0.34), lineWidth: 1))
                                        .clipShape(Capsule())
                                }
                                Spacer()
                                // Bottom row
                                VStack(alignment: .leading, spacing: 10) {
                                    Rectangle()
                                        .fill(Color(hex: heroShow.accentColor))
                                        .frame(width: 24, height: 2).cornerRadius(1)
                                    Text(heroShow.title)
                                        .font(.custom("Georgia", size: 24.6)).foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.6), radius: 7, y: 2)
                                    HStack(alignment: .center, spacing: 0) {
                                        VibeWaveView(hexColor: VibeOption.hexColor(forScore: hero.score), score: hero.score)
                                        Spacer(minLength: 8)
                                        HStack(spacing: 7) {
                                            pillButton("dot.radiowaves.left.and.right", label: "rally") { showRally = true }
                                            pillButton("star", label: "vibe check") { showVibeSheet = true }
                                            pillButton("info.circle", label: "info") { detailShow = heroShow }
                                        }
                                        .fixedSize()
                                    }
                                }
                            }
                            .frame(width: geo.size.width, height: 264)
                            .padding(16)
                        }
                    }
                    .frame(height: 264)
                    .padding(.horizontal, 16)
                    // cardIn: fade + slide up from 12pt when hero changes
                    .id(heroIdx)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 12)),
                            removal: .opacity.combined(with: .offset(y: -6))
                        )
                    )

                    // ── Also watching ─────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ALSO WATCHING")
                            .font(.system(size: 11.8)).foregroundColor(.stelrMuted).kerning(0.9)
                            .padding(.horizontal, 16)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(appState.friends.enumerated().filter { $0.offset != heroIdx }),
                                        id: \.element.id) { _, friend in
                                    if let s = appState.show(for: friend.currentShowId) {
                                        // Tap card → switch hero; tap info button → detail
                                        MiniShowCard(
                                            show: s, friend: friend,
                                            onSelect: {
                                                UISelectionFeedbackGenerator().selectionChanged()
                                                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                                                    heroIdx = appState.friends.firstIndex(where: { $0.id == friend.id }) ?? heroIdx
                                                }
                                            },
                                            onInfo: { detailShow = s }
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 14)

                    Spacer(minLength: 80)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .sheet(isPresented: $showVibeSheet) {
            VibeCheckSheet(show: heroShow, currentScore: hero.score) { opt in
                appState.updateVibeForFriend(friendId: hero.id, vibe: opt)
            }
        }
        .sheet(isPresented: $showRally) {
            RallySheet(show: heroShow)
        }
        .sheet(item: $detailShow) { show in
            ShowDetailView(show: show, watchingFriends: appState.friendsWatching(showId: show.id))
        }
        .sheet(isPresented: $showLiveFeed) {
            LiveFeedSheet()
        }
        .sheet(item: $profileFriend) { friend in
            FriendProfileSheet(friend: friend)
        }
        .onAppear {
            heroIdx = min(initialFriendIndex, max(0, appState.friends.count - 1))
        }
    }

    private func pillButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 12.3))
                Text(label).font(.system(size: 14.4, weight: .medium))
            }
            .foregroundColor(.white)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Color.black.opacity(0.45))
            .clipShape(Capsule())
        }
        .buttonStyle(.stelrPress)
    }
}

// ── Mini "also watching" card with dedicated info button ──────────────────────
private struct MiniShowCard: View {
    let show: Show
    let friend: Friend
    var onSelect: () -> Void
    var onInfo: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ShowPosterView(show: show, width: 96, height: 76, radius: 12) {
                LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                VStack {
                    HStack {
                        AvatarView(initials: friend.initials, hexColor: friend.hexColor, size: 22)
                        Spacer()
                        Text(friend.vibe.emoji).font(.system(size: 16.4))
                    }
                    Spacer()
                    Text(show.title)
                        .font(.system(size: 11.2, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(8)

                // Info button (top-right, matching mockup)
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onInfo) {
                            ZStack {
                                Circle().fill(Color.black.opacity(0.45))
                                Image(systemName: "info")
                                    .font(.system(size: 9.0, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .frame(width: 18, height: 18)
                        }
                        .buttonStyle(.stelrPress)
                    }
                    Spacer()
                }
                .padding(4)
            }
        }
        .buttonStyle(.stelrPress)
    }
}
