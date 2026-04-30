import SwiftUI

struct FeedView: View {
    var animateEntrance: Bool = true
    var animationToken: Int = 0
    var onFriendTap: ((Friend) -> Void)? = nil

    @EnvironmentObject var appState: AppState
    @State private var detailShow: Show?
    @State private var appeared = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.stelrBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // ── Header ────────────────────────────────────────────────
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("activity")
                                .font(.custom("Georgia", size: 29.1).weight(.semibold))
                                .foregroundColor(.stelrText)
                            Text("what your friends are watching")
                                .font(.system(size: 12.8)).foregroundColor(.stelrMuted)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20).padding(.top, 66).padding(.bottom, 16)

                    // ── Activity feed ─────────────────────────────────────────
                    VStack(spacing: 0) {
                        ForEach(Array(appState.activities.enumerated()), id: \.element.id) { idx, act in
                            if let friend = appState.friend(for: act.friendId),
                               let show = appState.show(for: act.showId) {
                                ActivityRow(
                                    activity: act,
                                    friend: friend,
                                    show: show,
                                    onTapFriend: { onFriendTap?(friend) },
                                    onTapShow: { detailShow = show }
                                )
                                .padding(.horizontal, 20)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 24)
                                .animation(
                                    .spring(response: 0.48, dampingFraction: 0.72)
                                        .delay(Double(idx) * 0.09),
                                    value: appeared
                                )
                                Divider().background(Color.stelrBorder).padding(.horizontal, 20)
                                    .opacity(appeared ? 1 : 0)
                                    .animation(.easeInOut(duration: 0.3).delay(Double(idx) * 0.09 + 0.1), value: appeared)
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
        .sheet(item: $detailShow) { show in
            ShowDetailView(show: show, watchingFriends: appState.friendsWatching(showId: show.id))
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

// ── Activity row ──────────────────────────────────────────────────────────────
private struct ActivityRow: View {
    let activity: Activity
    let friend: Friend
    let show: Show
    var onTapFriend: () -> Void
    var onTapShow: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Button(action: onTapFriend) {
                AvatarView(initials: friend.initials, hexColor: friend.hexColor, size: 42)
            }
            .buttonStyle(.stelrPress)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Button(action: onTapFriend) {
                        Text(friend.name)
                            .font(.system(size: 16.2, weight: .medium))
                            .foregroundColor(.stelrText)
                    }
                    .buttonStyle(.stelrPress)
                    Spacer()
                    Text(activity.timeAgo).font(.system(size: 11.5)).foregroundColor(.stelrMuted)
                }

                Text("\(activity.action) ")
                    .font(.system(size: 15.1)).foregroundColor(.stelrMuted)
                + Text(show.title)
                    .font(.custom("Georgia", size: 15.1)).italic().foregroundColor(.stelrText)

                // Show card
                Button(action: onTapShow) {
                    HStack(spacing: 12) {
                        ShowPosterView(show: show, width: 46, height: 62, radius: 9)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(show.title)
                                .font(.custom("Georgia", size: 16.8))
                                .foregroundColor(.stelrText)
                            HStack(spacing: 7) {
                                Text(show.currentEpisode)
                                    .font(.system(size: 12.9)).foregroundColor(.stelrMuted)
                                Text("\(activity.vibe.emoji) \(activity.vibe.label)")
                                    .font(.system(size: 12.9))
                                    .foregroundColor(Color(hex: activity.vibe.hexColor))
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color(hex: activity.vibe.hexColor).opacity(0.11))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        Spacer()
                        VibeWaveView(vibe: activity.vibe, size: 18, animate: false)
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.stelrBorder, lineWidth: 0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.stelrPress)
            }
        }
        .padding(.vertical, 20)
    }
}

