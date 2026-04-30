import SwiftUI

struct LiveFeedSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var detailShow: Show?
    @State private var profileFriend: Friend?

    var body: some View {
        VStack(spacing: 0) {
            // ── Handle ───────────────────────────────────────────────────────
            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(width: 36, height: 4)
                .padding(.top, 8).padding(.bottom, 14)

            // ── Header ───────────────────────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("live ratings")
                            .font(.custom("Georgia", size: 22.4).weight(.semibold))
                            .foregroundColor(.stelrText)
                        // Pulsing live dot
                        LiveDot()
                    }
                    Text("what your circle is watching right now")
                        .font(.system(size: 12.3)).foregroundColor(.stelrMuted)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14.6, weight: .semibold))
                        .foregroundColor(.stelrMuted)
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.07))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 18).padding(.bottom, 14)

            Divider().background(Color.stelrBorder)

            // ── Content ──────────────────────────────────────────────────────
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(appState.activities) { act in
                        if let friend = appState.friend(for: act.friendId),
                           let show = appState.show(for: act.showId) {
                            LiveActivityRow(
                                activity: act,
                                friend: friend,
                                show: show,
                                onTapFriend: { profileFriend = friend },
                                onTapShow:   { detailShow = show }
                            )
                            .padding(.horizontal, 18)
                            Divider().background(Color.stelrBorder).padding(.horizontal, 18)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "1c1814"))
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
        .sheet(item: $detailShow) { show in
            ShowDetailView(show: show, watchingFriends: appState.friendsWatching(showId: show.id))
        }
        .sheet(item: $profileFriend) { friend in
            FriendProfileSheet(friend: friend)
        }
    }
}

// ── Live activity row ─────────────────────────────────────────────────────────
private struct LiveActivityRow: View {
    let activity: Activity
    let friend: Friend
    let show: Show
    var onTapFriend: () -> Void
    var onTapShow:   () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar — tap opens friend profile
            Button(action: onTapFriend) {
                AvatarView(initials: friend.initials, hexColor: friend.hexColor, size: 40)
            }
            .buttonStyle(.stelrPress)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Button(action: onTapFriend) {
                        Text(friend.name)
                            .font(.system(size: 14.6, weight: .semibold))
                            .foregroundColor(.stelrText)
                    }
                    .buttonStyle(.stelrPress)
                    Spacer()
                    Text(activity.timeAgo)
                        .font(.system(size: 10.5)).foregroundColor(.stelrMuted)
                }

                Text(activity.action)
                    .font(.system(size: 13.4)).foregroundColor(.stelrMuted)
                + Text(" ")
                + Text(show.title)
                    .font(.custom("Georgia", size: 13.4)).italic()
                    .foregroundColor(.stelrText)

                // Show card with vibe
                Button(action: onTapShow) {
                    HStack(spacing: 10) {
                        ShowPosterView(show: show, width: 38, height: 38, radius: 7)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(show.title)
                                .font(.custom("Georgia", size: 14.6)).foregroundColor(.stelrText)
                                .lineLimit(1)
                            HStack(spacing: 6) {
                                Text(show.currentEpisode)
                                    .font(.system(size: 11.8)).foregroundColor(.stelrMuted)
                                Text("\(activity.vibe.emoji) \(activity.vibe.label)")
                                    .font(.system(size: 11.8))
                                    .foregroundColor(Color(hex: activity.vibe.hexColor))
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color(hex: activity.vibe.hexColor).opacity(0.09))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                        Spacer()
                        VibeWaveView(vibe: activity.vibe, size: 14, animate: false)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.stelrBorder, lineWidth: 0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.stelrPress)
            }
        }
        .padding(.vertical, 16)
    }
}

// ── Reusable pulsing live dot ─────────────────────────────────────────────────
private struct LiveDot: View {
    @State private var pulsing = false
    var body: some View {
        Circle()
            .fill(Color(hex: "72c97e"))
            .frame(width: 8, height: 8)
            .opacity(pulsing ? 0.4 : 1.0)
            .scaleEffect(pulsing ? 0.8 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
    }
}
