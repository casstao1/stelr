import SwiftUI

struct FriendProfileSheet: View {
    let friend: Friend
    var showsCloseButton = true
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var detailShow: Show?

    private var currentShow: Show? { appState.show(for: friend.currentShowId) }
    private var watchingShows: [Show] {
        friend.watchedShowIds.compactMap { appState.show(for: $0) }
    }
    private var friendActivity: [Activity] {
        appState.activities.filter { $0.friendId == friend.id }
    }
    private var vibe: VibeOption { friend.vibe }

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "1c1814").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Color.clear.frame(height: showsCloseButton ? 0 : 82)

                    // ── Hero banner ──────────────────────────────────────────
                    ZStack(alignment: .bottom) {
                        if let show = currentShow {
                            ShowPosterView(show: show, width: UIScreen.main.bounds.width, height: 220, radius: 0)
                        } else {
                            Rectangle()
                                .fill(Color(hex: friend.hexColor).opacity(0.15))
                                .frame(height: 220)
                        }

                        // Gradient fade at top (smooth into background)
                        LinearGradient(
                            colors: [Color(hex: "1c1814"), .clear],
                            startPoint: .top,
                            endPoint: .init(x: 0.5, y: 0.38)
                        )
                        .frame(height: 220)

                        // Gradient fade at bottom
                        LinearGradient(
                            colors: [.clear, Color(hex: "1c1814")],
                            startPoint: .init(x: 0.5, y: 0.3),
                            endPoint: .bottom
                        )
                        .frame(height: 220)

                        // Friend info over banner
                        HStack(alignment: .bottom, spacing: 14) {
                            ZStack {
                                AvatarView(initials: friend.initials, hexColor: friend.hexColor, size: 60)
                                if friend.isActive {
                                    Circle()
                                        .fill(Color(hex: "72c97e"))
                                        .frame(width: 14, height: 14)
                                        .overlay(Circle().stroke(Color(hex: "1c1814"), lineWidth: 2.5))
                                        .offset(x: 20, y: 20)
                                }
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(friend.name)
                                    .font(.custom("Georgia", size: 24.6).weight(.semibold))
                                    .foregroundColor(.stelrText)
                                HStack(spacing: 6) {
                                    Text("\(vibe.emoji) \(vibe.label)")
                                        .font(.system(size: 12.3))
                                        .foregroundColor(vibe.isDark ? .stelrMuted : Color(hex: vibe.hexColor))
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                        .background(vibe.isDark ? Color.white.opacity(0.07) : Color(hex: vibe.hexColor).opacity(0.13))
                                        .clipShape(Capsule())
                                    if let show = watchingShows.first {
                                        Text(watchingShows.count == 1 ? "watching \(show.title)" : "watching \(show.title) + \(watchingShows.count - 1)")
                                            .font(.system(size: 12.3))
                                            .foregroundColor(.stelrMuted)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20).padding(.bottom, 18)
                    }

                    // ── Watching ─────────────────────────────────────────────
                    if !watchingShows.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("WATCHING")
                                .font(.system(size: 11.8)).foregroundColor(.stelrMuted).kerning(0.8)

                            ForEach(watchingShows) { show in
                                Button { detailShow = show } label: {
                                    HStack(spacing: 14) {
                                        ShowPosterView(show: show, width: 58, height: 80, radius: 10)
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(show.title)
                                                .font(.custom("Georgia", size: 19.0)).foregroundColor(.stelrText)
                                            Text(show.platform)
                                                .font(.system(size: 12.3)).foregroundColor(.stelrMuted)
                                            VibeWaveView(hexColor: VibeOption.hexColor(forScore: friend.score), score: friend.score, animate: false)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13.4, weight: .medium))
                                            .foregroundColor(.stelrMuted)
                                    }
                                    .padding(14)
                                    .background(Color.white.opacity(0.04))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.stelrBorder, lineWidth: 0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.stelrPress)
                            }
                        }
                        .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 20)
                    }

                    Divider().background(Color.stelrBorder).padding(.horizontal, 20)

                    // ── Rating activity feed ─────────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        Text("RECENT RATINGS")
                            .font(.system(size: 11.8)).foregroundColor(.stelrMuted).kerning(0.8)
                            .padding(.horizontal, 20)

                        if friendActivity.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "star.slash")
                                    .font(.system(size: 31.4, weight: .ultraLight))
                                    .foregroundColor(.stelrMuted)
                                Text("no ratings yet")
                                    .font(.custom("Georgia", size: 15.7)).italic()
                                    .foregroundColor(.stelrMuted)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(friendActivity) { act in
                                    if let show = appState.show(for: act.showId) {
                                        RatingActivityRow(activity: act, friend: friend, show: show) {
                                            detailShow = show
                                        }
                                        .padding(.horizontal, 20)
                                        Divider().background(Color.stelrBorder).padding(.horizontal, 20)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 20)

                    Spacer(minLength: 60)
                }
            }
        }
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [
                    Color(hex: "1c1814"),
                    Color(hex: "1c1814").opacity(0.86),
                    Color(hex: "1c1814").opacity(0.35),
                    Color(hex: "1c1814").opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: showsCloseButton ? 92 : 142)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
        }
        .overlay(alignment: .topTrailing) {
            if showsCloseButton {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14.6, weight: .semibold))
                        .foregroundColor(.stelrMuted)
                        .frame(width: 30, height: 30)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .padding(.top, 16).padding(.trailing, 18)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
        .sheet(item: $detailShow) { show in
            ShowDetailView(show: show, watchingFriends: appState.friendsWatching(showId: show.id))
        }
    }
}

// ── Compact rating row ────────────────────────────────────────────────────────
private struct RatingActivityRow: View {
    let activity: Activity
    let friend: Friend
    let show: Show
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ShowPosterView(show: show, width: 44, height: 44, radius: 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(show.title)
                        .font(.custom("Georgia", size: 15.7)).foregroundColor(.stelrText)
                        .lineLimit(1)
                    Text(activity.action)
                        .font(.system(size: 12.3)).foregroundColor(.stelrMuted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(activity.vibe.emoji) \(activity.vibe.label)")
                        .font(.system(size: 12.3))
                        .foregroundColor(activity.vibe.isDark ? .stelrMuted : Color(hex: activity.vibe.hexColor))
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(activity.vibe.isDark ? Color.white.opacity(0.06) : Color(hex: activity.vibe.hexColor).opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Text(activity.timeAgo)
                        .font(.system(size: 9.5)).foregroundColor(.stelrMuted)
                }
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(.stelrPress)
    }
}
