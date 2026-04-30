import SwiftUI

// Full-screen Search tab with "shows" and "friends" sub-tabs.

struct SearchTabView: View {
    @EnvironmentObject var appState: AppState

    @State private var selectedTab: SearchSubTab = .shows

    // Shows sub-tab state
    @State private var showQuery        = ""
    @State private var showResults: [Show] = []
    @State private var isSearching      = false
    @State private var searchTask: Task<Void, Never>?
    @State private var addedIds: Set<Int> = []
    @State private var detailShow: Show?

    // Friends sub-tab state
    @State private var friendQuery = ""

    enum SearchSubTab { case shows, friends }

    var body: some View {
        ZStack {
            Color.stelrBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ────────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 2) {
                    Text("search")
                        .font(.custom("Georgia", size: 31.4).weight(.semibold))
                        .foregroundColor(.stelrText)
                    Text(selectedTab == .shows ? "find shows · add to your list" : "find friends · see what they're watching")
                        .font(.system(size: 12.8)).foregroundColor(.stelrMuted)
                        .animation(.easeInOut(duration: 0.18), value: selectedTab)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.top, 66).padding(.bottom, 14)

                // ── Sub-tab switcher ──────────────────────────────────────────
                HStack(spacing: 6) {
                    ForEach([SearchSubTab.shows, SearchSubTab.friends], id: \.self) { tab in
                        let isSelected = selectedTab == tab
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
                                selectedTab = tab
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: tab == .shows ? "tv" : "person.2.fill")
                                    .font(.system(size: 12.6, weight: isSelected ? .semibold : .medium))
                                Text(tab == .shows ? "shows" : "friends")
                                    .font(.system(size: 13.6, weight: isSelected ? .semibold : .medium))
                            }
                            .foregroundColor(isSelected ? .white : .stelrMuted.opacity(0.6))
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(
                                Group {
                                    if isSelected {
                                        Capsule().fill(Color.stelrAccent)
                                    } else {
                                        Capsule().fill(Color.white.opacity(0.06))
                                            .overlay(Capsule().stroke(Color.stelrBorder, lineWidth: 0.5))
                                    }
                                }
                            )
                        }
                        .buttonStyle(.stelrPress)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.bottom, 14)

                // ── Search bar ────────────────────────────────────────────────
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15.7))
                        .foregroundColor(activeQuery.isEmpty ? .stelrMuted : .stelrAccent)
                    TextField(searchPlaceholder, text: activeQueryBinding)
                        .font(.system(size: 16.8))
                        .foregroundColor(.stelrText)
                        .tint(.stelrAccent)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .id(selectedTab) // resets field on tab switch
                    if !activeQuery.isEmpty {
                        Button { clearActiveQuery() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.stelrMuted)
                                .font(.system(size: 16.8))
                        }
                        .buttonStyle(.stelrPress)
                    }
                }
                .padding(.horizontal, 13).padding(.vertical, 11)
                .background(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(activeQuery.isEmpty ? Color.stelrBorder : Color.stelrAccent.opacity(0.45), lineWidth: 0.7)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16).padding(.bottom, 12)
                .animation(.easeInOut(duration: 0.2), value: activeQuery.isEmpty)

                Divider().background(Color.stelrBorder)

                // ── Body ──────────────────────────────────────────────────────
                Group {
                    if selectedTab == .shows {
                        showsBody
                    } else {
                        friendsBody
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.18), value: selectedTab)
            }
        }
        .sheet(item: $detailShow) { show in
            ShowDetailView(show: show, watchingFriends: appState.friendsWatching(showId: show.id))
        }
        .onChange(of: showQuery) { _, newVal in
            scheduleSearch(query: newVal)
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private var activeQuery: String {
        selectedTab == .shows ? showQuery : friendQuery
    }

    private var activeQueryBinding: Binding<String> {
        selectedTab == .shows ? $showQuery : $friendQuery
    }

    private var searchPlaceholder: String {
        selectedTab == .shows ? "search any show…" : "search names or @usernames…"
    }

    private func clearActiveQuery() {
        if selectedTab == .shows { showQuery = "" } else { friendQuery = "" }
    }

    // ── Shows body ────────────────────────────────────────────────────────────

    @ViewBuilder
    private var showsBody: some View {
        if isSearching {
            showsLoadingView
        } else if !showQuery.isEmpty && showResults.isEmpty {
            showsEmptyView
        } else if showResults.isEmpty {
            showsPromptView
        } else {
            showsResultsList
        }
    }

    private var showsResultsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(showResults) { show in
                    let alreadyAdded = appState.myShows.contains(where: { $0.showId == show.id })
                    let justAdded    = addedIds.contains(show.id)
                    ShowSearchResultRow(show: show, isAdded: alreadyAdded || justAdded) {
                        withAnimation(.spring(response: 0.3)) {
                            appState.addShowToRotation(show)
                            addedIds.insert(show.id)
                        }
                    }
                    Divider().background(Color.stelrBorder).padding(.horizontal, 18)
                }
            }
            .padding(.bottom, 96)
        }
    }

    private var showsLoadingView: some View {
        VStack(spacing: 14) {
            ProgressView().tint(Color.stelrAccent).scaleEffect(1.1)
            Text("searching…").font(.system(size: 13.4)).foregroundColor(.stelrMuted)
        }
        .frame(maxHeight: .infinity)
    }

    private var showsEmptyView: some View {
        VStack(spacing: 12) {
            Text("📺").font(.system(size: 50.2))
            Text("no results for "\(showQuery)"")
                .font(.custom("Georgia", size: 16.8)).italic().foregroundColor(.stelrMuted)
            Text("try another title or check spelling")
                .font(.system(size: 12.3)).foregroundColor(.stelrMuted.opacity(0.7))
        }
        .frame(maxHeight: .infinity)
    }

    private var showsPromptView: some View {
        VStack(spacing: 24) {
            Image(systemName: "tv")
                .font(.system(size: 44, weight: .ultraLight))
                .foregroundColor(.stelrMuted)
            VStack(spacing: 6) {
                Text("find your next watch")
                    .font(.custom("Georgia", size: 18.4)).italic().foregroundColor(.stelrText)
                Text("search any show to add it to your list")
                    .font(.system(size: 13.4)).foregroundColor(.stelrMuted)
            }
            if !appState.shows.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("POPULAR WITH FRIENDS")
                        .font(.system(size: 11.2, weight: .semibold)).foregroundColor(.stelrMuted).kerning(0.8)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(appState.shows.prefix(5)) { show in
                                Button { showQuery = show.title } label: {
                                    HStack(spacing: 7) {
                                        ShowPosterView(show: show, width: 32, height: 44, radius: 6)
                                        Text(show.title)
                                            .font(.system(size: 13.4, weight: .medium))
                                            .foregroundColor(.stelrText)
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 7)
                                    .background(Color.white.opacity(0.05))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.stelrBorder, lineWidth: 0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.stelrPress)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 8)
            }
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 20)
    }

    // ── Friends body ──────────────────────────────────────────────────────────

    @ViewBuilder
    private var friendsBody: some View {
        let filtered = filteredFriends
        if !friendQuery.isEmpty && filtered.isEmpty {
            friendsEmptyView
        } else {
            friendsList(filtered)
        }
    }

    private var filteredFriends: [Friend] {
        let term = friendQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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

    private func friendsList(_ friends: [Friend]) -> some View {
        ScrollView(showsIndicators: false) {
            if friends.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "person.2")
                        .font(.system(size: 44, weight: .ultraLight))
                        .foregroundColor(.stelrMuted)
                    VStack(spacing: 6) {
                        Text("find your people")
                            .font(.custom("Georgia", size: 18.4)).italic().foregroundColor(.stelrText)
                        Text("search by name, username, or a show they watch")
                            .font(.system(size: 13.4)).foregroundColor(.stelrMuted)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 60)
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(friends) { friend in
                        FriendSearchResultRow(
                            friend: friend,
                            shows: friend.watchedShowIds.compactMap { appState.show(for: $0) }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 96)
            }
        }
    }

    private var friendsEmptyView: some View {
        VStack(spacing: 12) {
            Text("🔭").font(.system(size: 50.2))
            Text("nobody found for "\(friendQuery)"")
                .font(.custom("Georgia", size: 16.8)).italic().foregroundColor(.stelrMuted)
            Text("try a name, @username, or a show they watch")
                .font(.system(size: 12.3)).foregroundColor(.stelrMuted.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxHeight: .infinity)
    }

    // ── Show search logic ─────────────────────────────────────────────────────

    private func scheduleSearch(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { showResults = []; isSearching = false; return }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { isSearching = true }
            let found = await appState.searchTVMaze(query: trimmed)
            guard !Task.isCancelled else { return }
            await MainActor.run { showResults = found; isSearching = false }
        }
    }
}

// MARK: - Show search result row

private struct ShowSearchResultRow: View {
    let show: Show
    let isAdded: Bool
    var onAdd: () -> Void

    @State private var tapped = false

    var body: some View {
        HStack(spacing: 13) {
            ShowPosterView(show: show, width: 50, height: 70, radius: 9) {
                VStack {
                    Spacer()
                    if let genre = show.genre?.components(separatedBy: " · ").first {
                        Text(genre)
                            .font(.system(size: 8.4, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))
                            .padding(.horizontal, 4).padding(.vertical, 2)
                            .background(Color.black.opacity(0.45))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(5)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(show.title)
                    .font(.custom("Georgia", size: 17.4)).foregroundColor(.stelrText).lineLimit(1)
                HStack(spacing: 6) {
                    Text(show.platform).font(.system(size: 12.3)).foregroundColor(.stelrMuted)
                    if let yr = show.year {
                        Text("·").foregroundColor(.stelrBorder)
                        Text(String(yr)).font(.system(size: 12.3)).foregroundColor(.stelrMuted)
                    }
                }
                if let genre = show.genre {
                    Text(genre).font(.system(size: 11.8)).foregroundColor(.stelrMuted.opacity(0.7)).lineLimit(1)
                }
            }

            Spacer()

            Button {
                guard !isAdded else { return }
                tapped = true
                onAdd()
            } label: {
                ZStack {
                    Circle()
                        .fill(isAdded ? Color(hex: "72c97e").opacity(0.12) : Color.stelrAccent.opacity(0.10))
                        .overlay(Circle().stroke(
                            isAdded ? Color(hex: "72c97e").opacity(0.35) : Color.stelrAccent.opacity(0.30),
                            lineWidth: 0.6
                        ))
                    Image(systemName: isAdded ? "checkmark" : "plus")
                        .font(.system(size: isAdded ? 13.4 : 16.8, weight: .semibold))
                        .foregroundColor(isAdded ? Color(hex: "72c97e") : .stelrAccent)
                }
                .frame(width: 34, height: 34)
                .scaleEffect(tapped ? 0.88 : 1.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.55), value: tapped)
            }
            .buttonStyle(.stelrPress)
            .disabled(isAdded)
        }
        .padding(.horizontal, 18).padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

// MARK: - Friend search result row

private struct FriendSearchResultRow: View {
    let friend: Friend
    let shows: [Show]

    private var showLabel: String {
        guard let first = shows.first else { return "Not watching anything" }
        return shows.count == 1 ? first.title : "\(first.title) + \(shows.count - 1) more"
    }

    var body: some View {
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
                    Text(showLabel).lineLimit(1)
                    Text("·").foregroundColor(.stelrMuted.opacity(0.45))
                    Text("\(friend.vibe.emoji) \(friend.vibe.label)")
                        .foregroundColor(Color(hex: friend.vibe.hexColor))
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
}
