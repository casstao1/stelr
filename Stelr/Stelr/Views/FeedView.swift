import SwiftUI

struct FeedView: View {
    var animateEntrance: Bool = true
    var animationToken: Int = 0
    var onFriendTap: ((Friend) -> Void)? = nil

    @EnvironmentObject var appState: AppState
    @State private var detailShow: Show?
    @State private var showFriendSearch = false
    @State private var appeared = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.stelrBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // ── Header ────────────────────────────────────────────────
                    HStack {
                        Text("friends")
                            .font(.custom("Georgia", size: 29.1).weight(.semibold))
                            .foregroundColor(.stelrText)
                        Spacer()
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showFriendSearch = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 22.4))
                                .foregroundColor(.stelrMuted)
                                .frame(width: 38, height: 38)
                                .background(Color.white.opacity(0.06))
                                .overlay(Circle().stroke(Color.stelrBorder, lineWidth: 0.5))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.stelrGlossyPress)
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
        .sheet(isPresented: $showFriendSearch) {
            FriendSearchPage { friend in
                showFriendSearch = false
                onFriendTap?(friend)
            }
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

    private var vibeHexColor: String { VibeOption.hexColor(forScore: friend.score) }

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
                                    .foregroundColor(Color(hex: vibeHexColor))
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color(hex: vibeHexColor).opacity(0.11))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        Spacer()
                        VibeWaveView(hexColor: vibeHexColor, score: friend.score, animate: false)
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

// ── Friend search page ────────────────────────────────────────────────────────
private struct FriendSearchPage: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var onSelect: (Friend) -> Void

    private var filteredFriends: [Friend] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !term.isEmpty else { return appState.friends }

        return appState.friends.filter { friend in
            let showTitles = friend.watchedShowIds
                .compactMap { appState.show(for: $0)?.title.lowercased() }
            return friend.name.lowercased().contains(term)
                || friend.username.lowercased().contains(term)
                || "@\(friend.username)".lowercased().contains(term)
                || friend.initials.lowercased().contains(term)
                || friend.vibe.label.lowercased().contains(term)
                || showTitles.contains(where: { $0.contains(term) })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(width: 36, height: 4)
                .padding(.top, 8).padding(.bottom, 14)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("find friends")
                        .font(.custom("Georgia", size: 22.4).weight(.semibold))
                        .foregroundColor(.stelrText)
                    Text("search names or usernames")
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
                .buttonStyle(.stelrPress)
            }
            .padding(.horizontal, 18).padding(.bottom, 14)

            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15.7))
                    .foregroundColor(query.isEmpty ? .stelrMuted : .stelrAccent)
                TextField("search names or @usernames", text: $query)
                    .font(.system(size: 16.8))
                    .foregroundColor(.stelrText)
                    .tint(.stelrAccent)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16.8))
                            .foregroundColor(.stelrMuted)
                    }
                    .buttonStyle(.stelrPress)
                }
            }
            .padding(.horizontal, 13).padding(.vertical, 11)
            .background(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(query.isEmpty ? Color.stelrBorder : Color.stelrAccent.opacity(0.45), lineWidth: 0.7)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 18).padding(.bottom, 10)
            .animation(.easeInOut(duration: 0.2), value: query.isEmpty)

            Divider().background(Color.stelrBorder)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    ForEach(filteredFriends) { friend in
                        FriendSearchRow(
                            friend: friend,
                            shows: friend.watchedShowIds.compactMap { appState.show(for: $0) }
                        ) {
                            onSelect(friend)
                            dismiss()
                        }
                    }

                    if filteredFriends.isEmpty {
                        Text("No people found")
                            .font(.system(size: 14.6))
                            .foregroundColor(.stelrMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 34)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 48)
            }
        }
        .background(Color(hex: "1c1814"))
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }
}

private struct FriendSearchRow: View {
    let friend: Friend
    let shows: [Show]
    var onSelect: () -> Void

    private var showLabel: String {
        guard let first = shows.first else { return "Not watching" }
        return shows.count == 1 ? first.title : "\(first.title) + \(shows.count - 1)"
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                AvatarView(initials: friend.initials, hexColor: friend.hexColor, size: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(friend.name)
                        .font(.system(size: 16.8, weight: .semibold))
                        .foregroundColor(.stelrText)
                    Text("@\(friend.username)")
                        .font(.system(size: 12.8, weight: .medium))
                        .foregroundColor(.stelrMuted)
                    HStack(spacing: 6) {
                        Text(showLabel)
                            .lineLimit(1)
                        Text("·")
                            .foregroundColor(.stelrMuted.opacity(0.45))
                        Text("\(friend.vibe.emoji) \(friend.vibe.label)")
                            .foregroundColor(friend.vibe.isDark ? .stelrMuted : Color(hex: friend.vibe.hexColor))
                    }
                    .font(.system(size: 13.4))
                    .foregroundColor(.stelrMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13.4, weight: .semibold))
                    .foregroundColor(.stelrMuted.opacity(0.6))
            }
            .padding(13)
            .background(Color.white.opacity(0.045))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.stelrBorder, lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(.stelrPress)
    }
}
