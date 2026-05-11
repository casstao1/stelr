import SwiftUI
import Combine

struct ConstellationPulseEvent: Identifiable, Equatable {
    let id = UUID()
    let friendId: Int
    let showId: Int
}

@MainActor
final class AppState: ObservableObject {
    // MARK: - Data
    @Published var shows: [Show] = Show.samples
    @Published var friends: [Friend] = Friend.samples
    @Published var suggestedFriends: [Friend] = Friend.suggestedSamples
    @Published var activities: [Activity] = Activity.samples
    @Published var myShows: [MyShow] = MyShow.samples
    @Published var watchlistShowIds: [Int] = [5, 6, 7, 4]
    @Published var episodeComments: [EpisodeComment] = EpisodeComment.samples
    @Published var seasonRatings: [UserSeasonRating] = UserSeasonRating.samples
    @Published var probeRequests: [ProbeRequest] = ProbeRequest.samples
    @Published var milestones: [Milestone] = Milestone.samples
    @Published var checkInStreakDays: Int = 4
    @Published var activeAchievementToast: Milestone?
    @Published var myLists: [ShowList] = []
    @Published var friendRankings: [FriendRankEntry] = FriendRankEntry.samples
    @Published var constellationPulseEvent: ConstellationPulseEvent?
    @Published var shootingStarQueue: [ShootingStarEvent] = ShootingStarEvent.samples
    @Published private(set) var showDetailPresentationCount = 0
    private var queuedAchievementToasts: [Milestone] = []

    // MARK: - TVMaze enrichment
    @Published var isEnrichingShows = false

    // MARK: - Auth state (mirrors SupabaseManager)
    @Published var isAuthenticated = false

    let supabase = SupabaseManager.shared

    init() {
        shows = shows.map(ensuringPreviewArtwork)
        refreshDerivedRankingScores()
        Task { await enrichShowsFromTVMaze() }
        // Restore session on cold launch
        if AppConfig.supabaseEnabled {
            Task {
                await supabase.checkSession()
                if supabase.isAuthenticated {
                    isAuthenticated = true
                    await loadUserData()
                }
            }
        }
    }

    // ── Supabase sync ─────────────────────────────────────────────────────────

    /// Pulls the authenticated user's data from Supabase and merges it into local state.
    func loadUserData() async {
        guard isAuthenticated else { return }

        // --- My shows ---
        if let dbShows = try? await supabase.fetchMyShows(), !dbShows.isEmpty {
            let loaded: [MyShow] = dbShows.compactMap { db in
                MyShow(
                    id: db.showId,
                    showId: db.showId,
                    score: db.score,
                    currentEpisode: db.currentEpisode,
                    totalEpisodes: db.totalEpisodesInSeason,
                    currentSeason: db.currentSeason,
                    lastChecked: "synced",
                    vibe: VibeOption(rawValue: db.vibe) ?? .notWatching,
                    needsVibeCheck: false
                )
            }
            myShows = loaded
        }

        // --- Lists ---
        if let dbLists = try? await supabase.fetchMyLists() {
            myLists = dbLists.map { db in
                let entries: [ShowListEntry] = (db.entries ?? []).map { e in
                    ShowListEntry(
                        id: UUID(uuidString: e.id) ?? UUID(),
                        rank: e.rank,
                        showId: e.showId,
                        freeTextTitle: e.freeTextTitle,
                        note: nil
                    )
                }
                return ShowList(
                    id: UUID(uuidString: db.id) ?? UUID(),
                    title: db.title,
                    entries: entries
                )
            }
        }

        // --- Season ratings (own) ---
        if let dbRatings = try? await supabase.fetchSeasonRatings() {
            let ownRatings: [UserSeasonRating] = dbRatings.enumerated().map { idx, db in
                UserSeasonRating(
                    id: -(idx + 1),   // negative IDs to avoid colliding with sample data
                    showId: db.showId,
                    season: db.season,
                    score: db.score,
                    authorName: "You",
                    authorInitials: "ME",
                    authorHexColor: shows.first(where: { $0.id == db.showId })?.accentColor ?? "38b8c4",
                    isOwn: true,
                    timeAgo: "synced"
                )
            }
            seasonRatings.removeAll { $0.isOwn }
            seasonRatings.append(contentsOf: ownRatings)
        }

        // --- Friend rankings (influence, seasons) ---
        // Derived purely from existing tables — no extra storage needed at friends scope.
        // Falls back to sample data if query fails or returns nothing.
        await loadFriendRankings()
    }

    /// Builds friend-scope leaderboard entries from Supabase.
    ///
    /// **Influence** — JOINs `recommendations` → `user_shows` where episode > 3, plus accepted invites.
    /// **Seasons**   — SUMs `current_season` across each user's `user_shows` rows.
    /// **Shows**     — COUNTs distinct `show_id`s each user is watching or has watched.
    ///
    /// All three queries are scoped to the current user + their accepted friends,
    /// so they stay cheap regardless of global user count.
    func loadFriendRankings() async {
        guard isAuthenticated, let me = supabase.currentUser else { return }

        // Friend IDs we care about (you + accepted friends)
        let friendUserIds: [String] = friends.compactMap { _ in nil } // placeholder until friend UUIDs are stored

        // Until we have a real friend-UUID mapping, keep sample data in place.
        // When the friends table stores UUIDs this becomes a real query:
        //
        //   SELECT r.from_user_id, COUNT(DISTINCT r.id)
        //   FROM recommendations r
        //   JOIN user_shows us ON us.user_id = r.to_user_id AND us.show_id = r.show_id
        //   WHERE r.from_user_id IN (\(friendUserIds + [me.id]))
        //     AND us.current_episode > 3
        //   GROUP BY r.from_user_id
        //
        //   SELECT user_id, SUM(current_season)
        //   FROM user_shows
        //   WHERE user_id IN (\(friendUserIds + [me.id]))
        //   GROUP BY user_id
        //
        //   SELECT user_id, COUNT(DISTINCT show_id)
        //   FROM user_show_history
        //   WHERE user_id IN (\(friendUserIds + [me.id]))
        //   GROUP BY user_id
        //
        // Accepted invite counts are added into the Influence dimension.

        refreshDerivedRankingScores()
    }

    private var ownDistinctWatchedShowCount: Int {
        var showIds = Set(myShows.map(\.showId))
        showIds.formUnion(seasonRatings.filter(\.isOwn).map(\.showId))
        showIds.formUnion(episodeComments.filter(\.isOwn).map(\.showId))
        return showIds.count
    }

    private func friendDistinctWatchedShowCount(for friend: Friend) -> Int {
        var showIds = Set(friend.watchedShowIds)
        showIds.formUnion(activities.filter { $0.friendId == friend.id }.map(\.showId))
        showIds.formUnion(seasonRatings.filter { !$0.isOwn && $0.authorName == friend.name }.map(\.showId))
        showIds.formUnion(episodeComments.filter { !$0.isOwn && $0.authorName == friend.name }.map(\.showId))
        return showIds.count
    }

    private func refreshDerivedRankingScores() {
        guard !friendRankings.isEmpty else { return }
        let liveSeasonsScore = myShows.reduce(0) { $0 + $1.currentSeason }
        let friendShowCounts = Dictionary(uniqueKeysWithValues: friends.map { friend in
            (friend.id, friendDistinctWatchedShowCount(for: friend))
        })

        for index in friendRankings.indices {
            if friendRankings[index].isYou {
                friendRankings[index].seasonsScore = liveSeasonsScore
                friendRankings[index].showsScore = ownDistinctWatchedShowCount
            } else if let count = friendShowCounts[friendRankings[index].id] {
                friendRankings[index].showsScore = count
            }
        }
    }

    var isShowDetailPresented: Bool {
        showDetailPresentationCount > 0
    }

    func beginShowDetailPresentation() {
        showDetailPresentationCount += 1
    }

    func endShowDetailPresentation() {
        showDetailPresentationCount = max(0, showDetailPresentationCount - 1)
    }

    // ── TVMaze ────────────────────────────────────────────────────────────────
    func enrichShowsFromTVMaze() async {
        isEnrichingShows = true
        var enriched = shows
        await withTaskGroup(of: (Int, Show).self) { group in
            for (i, show) in enriched.enumerated() where show.tvmazeId != nil {
                group.addTask {
                    var s = show
                    await TVMazeService.shared.enrichShow(&s)
                    return (i, s)
                }
            }
            for await (i, updated) in group {
                enriched[i] = ensuringPreviewArtwork(updated)
            }
        }
        shows = enriched.map(ensuringPreviewArtwork)
        isEnrichingShows = false
    }

    func searchTVMaze(query: String) async -> [Show] {
        do {
            let results = try await TVMazeService.shared.searchShows(query: query)
            return results.prefix(10).map { res in
                makeTVMazeShow(from: res.show)
            }
        } catch {
            return []
        }
    }

    func searchAniList(query: String) async -> [Show] {
        do {
            let results = try await AniListService.shared.searchAnime(query: query)
            return results.map(makeAniListShow)
        } catch {
            return []
        }
    }

    func searchShows(query: String) async -> [Show] {
        async let tvmazeResults = searchTVMaze(query: query)
        async let aniListResults = searchAniList(query: query)

        let (tvmaze, anilist) = await (tvmazeResults, aniListResults)
        let merged = mergeSearchResults(query: query, tvmaze: tvmaze, anilist: anilist)
        return merged.map { canonicalShow(matching: $0) ?? $0 }
    }

    // ── Rotation management ───────────────────────────────────────────────────
    func addShowToRotation(_ show: Show) {
        let show = upsertShow(show)
        // Don't add duplicate rotation entries
        guard !myShows.contains(where: { $0.showId == show.id }) else { return }

        let nextId = (myShows.map(\.id).max() ?? -1) + 1
        let newMyShow = MyShow(
            id: nextId,
            showId: show.id,
            score: 0.0,
            currentEpisode: 1,
            totalEpisodes: seasonEpisodeLimit(for: show, season: 1, fallback: 1),
            currentSeason: 1,
            lastChecked: "never",
            vibe: .notWatching,
            needsVibeCheck: false
        )
        myShows.append(newMyShow)
        refreshDerivedRankingScores()
    }

    func abandonShow(showId: Int) {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            myShows.removeAll { $0.showId == showId }
        }
        refreshDerivedRankingScores()

        guard isAuthenticated, let uid = supabase.currentUser?.id.uuidString else { return }
        Task {
            try? await supabase.removeShowFromRotation(showId: showId, userId: uid)
        }
    }

    func isWatchlisted(showId: Int) -> Bool {
        watchlistShowIds.contains(showId)
    }

    func addShowToWatchlist(_ show: Show) {
        let show = upsertShow(show)
        guard !watchlistShowIds.contains(show.id) else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            watchlistShowIds.insert(show.id, at: 0)
        }
    }

    func removeShowFromWatchlist(showId: Int) {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            watchlistShowIds.removeAll { $0 == showId }
        }
    }

    func toggleWatchlist(for show: Show) {
        if isWatchlisted(showId: show.id) {
            removeShowFromWatchlist(showId: show.id)
        } else {
            addShowToWatchlist(show)
        }
    }

    var watchlistShows: [Show] {
        watchlistShowIds.compactMap { id in
            shows.first(where: { $0.id == id })
        }
    }

    // ── Lists ─────────────────────────────────────────────────────────────────

    func saveList(_ list: ShowList) {
        if let idx = myLists.firstIndex(where: { $0.id == list.id }) {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                myLists[idx] = list
            }
        } else {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                myLists.insert(list, at: 0)
            }
        }
        if isAuthenticated {
            Task { try? await supabase.upsertList(list) }
        }
    }

    @discardableResult
    func rememberListShow(_ show: Show) -> Show {
        let show = upsertShow(show)
        if isAuthenticated {
            Task { try? await supabase.upsertShow(show) }
        }
        return show
    }

    func restoreMissingListShows(for list: ShowList) async {
        let missingIds = Set(
            list.entries.compactMap { entry -> Int? in
                guard let showId = entry.showId, show(for: showId) == nil else { return nil }
                return showId
            }
        )

        for showId in missingIds {
            await restoreListShow(showId: showId)
        }
    }

    func deleteList(id: UUID) {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            myLists.removeAll { $0.id == id }
        }
        if isAuthenticated {
            Task { try? await supabase.deleteList(id: id) }
        }
    }

    func show(forListEntry entry: ShowListEntry) -> Show? {
        guard let showId = entry.showId else { return nil }
        return show(for: showId)
    }

    private func restoreListShow(showId: Int) async {
        if showId > 0 {
            do {
                var show = makeTVMazeShow(from: try await TVMazeService.shared.getShow(id: showId))
                await TVMazeService.shared.enrichShow(&show)
                rememberListShow(show)
            } catch {
                return
            }
        } else {
            do {
                let show = makeAniListShow(from: try await AniListService.shared.getAnime(id: abs(showId)))
                rememberListShow(show)
            } catch {
                return
            }
        }
    }

    // ── Shooting star queue ───────────────────────────────────────────────────

    /// Adds a friend-completion event to the shooting star queue.
    func enqueueShootingStar(friend: Friend, show: Show, season: Int) {
        let event = ShootingStarEvent(friend: friend, show: show, season: season)
        shootingStarQueue.append(event)
    }

    /// Removes and returns the next queued shooting star event, or nil if empty.
    func dequeueNextShootingStar() -> ShootingStarEvent? {
        guard !shootingStarQueue.isEmpty else { return nil }
        return shootingStarQueue.removeFirst()
    }

    var searchableFriends: [Friend] {
        friends + suggestedFriends.filter { suggested in
            !friends.contains(where: { $0.id == suggested.id })
        }
    }

    func isFriend(_ person: Friend) -> Bool {
        friends.contains(where: { $0.id == person.id })
    }

    func addFriend(_ person: Friend) {
        guard !isFriend(person) else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            friends.append(person)
            suggestedFriends.removeAll { $0.id == person.id }
        }
    }

    private func makeTVMazeShow(from tv: TVMazeShow) -> Show {
        let network = tv.network?.name ?? tv.webChannel?.name ?? "Unknown"
        let isAnime = tv.genres?.contains(where: { $0.localizedCaseInsensitiveContains("anime") }) ?? false
        let imageURL = tv.image?.original ?? tv.image?.medium
        return Show(
            id: tvmazeAppID(tv.id),
            tvmazeId: tv.id,
            title: tv.name,
            platform: network,
            currentEpisode: "",
            gradient1: "081e24",
            gradient2: "020b0e",
            accentColor: "38b8c4",
            summary: tv.summary?.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression),
            genre: tv.genres?.prefix(2).joined(separator: " · "),
            year: tv.premiered.flatMap { Int($0.prefix(4)) },
            seasons: nil,
            totalEpisodes: nil,
            globalRating: tv.rating?.average,
            cast: nil,
            platforms: network.isEmpty ? nil : [network],
            imageURL: imageURL,
            previewImageURL: imageURL,
            isAnime: isAnime,
            metadataSource: .tvmaze,
            detailMetadata: ShowDetailMetadata.fromTVMaze(tv)
        )
    }

    private func makeAniListShow(from media: AniListMedia) -> Show {
        let alternateTitles = [media.title.english, media.title.romaji, media.title.native]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let title = alternateTitles.first ?? "Untitled"
        let genres = ["Anime"] + (media.genres ?? []).filter { !$0.localizedCaseInsensitiveContains("anime") }
        let summary = media.description?
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#039;", with: "'")
        let imageURL = media.coverImage?.extraLarge ?? media.coverImage?.large ?? media.coverImage?.medium

        return Show(
            id: anilistAppID(media.id),
            tvmazeId: nil,
            anilistId: media.id,
            malId: media.idMal,
            title: title,
            platform: "Anime",
            currentEpisode: "",
            gradient1: "140d1e",
            gradient2: "07060f",
            accentColor: "ff7a59",
            summary: summary,
            genre: genres.prefix(2).joined(separator: " · "),
            year: media.seasonYear,
            seasons: nil,
            totalEpisodes: media.episodes,
            globalRating: media.averageScore.map { Double($0) / 20.0 },
            cast: nil,
            platforms: ["Anime"],
            imageURL: imageURL,
            previewImageURL: imageURL,
            isAnime: true,
            metadataSource: .anilist,
            alternateTitles: uniqueTitles(alternateTitles),
            detailMetadata: ShowDetailMetadata.fromAniList(media)
        )
    }

    private func mergeSearchResults(query: String, tvmaze: [Show], anilist: [Show]) -> [Show] {
        let animeKeys = Set(anilist.flatMap(searchDedupeKeys))
        let filteredTVMaze = tvmaze.filter { show in
            guard show.isAnime else { return true }
            return searchDedupeKeys(for: show).allSatisfy { !animeKeys.contains($0) }
        }

        var merged: [Show] = []
        var seen = Set<String>()
        let ranked = (anilist + filteredTVMaze).sorted {
            searchRank(for: query, show: $0) > searchRank(for: query, show: $1)
        }

        for show in ranked {
            let keys = searchDedupeKeys(for: show)
            guard keys.allSatisfy({ !seen.contains($0) }) else { continue }
            merged.append(show)
            for key in keys {
                seen.insert(key)
            }
        }

        return Array(merged.prefix(12))
    }

    private func searchRank(for query: String, show: Show) -> Int {
        let normalizedQuery = normalizedSearchKey(query)
        let titles = [show.title] + (show.alternateTitles ?? [])
        let normalizedTitles = titles.map(normalizedSearchKey)

        if normalizedTitles.contains(normalizedQuery) { return 400 }
        if normalizedTitles.contains(where: { $0.hasPrefix(normalizedQuery) }) { return 250 }
        if normalizedTitles.contains(where: { $0.contains(normalizedQuery) }) { return 180 }
        return show.isAnime ? 120 : 100
    }

    private func canonicalShow(matching candidate: Show) -> Show? {
        shows.first { showsLikelyMatch($0, candidate) }
    }

    @discardableResult
    private func upsertShow(_ candidate: Show) -> Show {
        let candidate = ensuringPreviewArtwork(candidate)
        if let idx = shows.firstIndex(where: { showsLikelyMatch($0, candidate) }) {
            let merged = mergeShows(existing: shows[idx], incoming: candidate)
            shows[idx] = merged
            return merged
        }

        shows.append(candidate)
        return candidate
    }

    private func mergeShows(existing: Show, incoming: Show) -> Show {
        var merged = existing
        merged.tvmazeId = merged.tvmazeId ?? incoming.tvmazeId
        merged.anilistId = merged.anilistId ?? incoming.anilistId
        merged.malId = merged.malId ?? incoming.malId
        merged.isAnime = merged.isAnime || incoming.isAnime
        merged.metadataSource = preferredMetadataSource(existing: existing.metadataSource, incoming: incoming.metadataSource, isAnime: merged.isAnime)
        merged.platform = existing.platform == "Unknown" ? incoming.platform : existing.platform
        merged.summary = merged.summary ?? incoming.summary
        merged.genre = merged.genre ?? incoming.genre
        merged.year = merged.year ?? incoming.year
        merged.seasons = merged.seasons ?? incoming.seasons
        merged.totalEpisodes = merged.totalEpisodes ?? incoming.totalEpisodes
        merged.globalRating = merged.globalRating ?? incoming.globalRating
        merged.cast = (merged.cast?.isEmpty == false) ? merged.cast : incoming.cast
        merged.castMembers = (merged.castMembers?.isEmpty == false) ? merged.castMembers : incoming.castMembers
        merged.platforms = (merged.platforms?.isEmpty == false) ? merged.platforms : incoming.platforms
        merged.imageURL = merged.imageURL ?? incoming.imageURL
        merged.previewImageURL = merged.previewImageURL ?? incoming.previewImageURL
        merged.episodeCountsBySeason = merged.episodeCountsBySeason ?? incoming.episodeCountsBySeason
        merged.alternateTitles = mergeAlternateTitles(existing: merged.alternateTitles, incoming: incoming.alternateTitles)
        merged.detailMetadata = incoming.detailMetadata ?? merged.detailMetadata

        if merged.isAnime && incoming.metadataSource == .anilist {
            merged.title = incoming.title
            merged.summary = incoming.summary ?? merged.summary
            merged.genre = incoming.genre ?? merged.genre
            merged.totalEpisodes = incoming.totalEpisodes ?? merged.totalEpisodes
            merged.globalRating = incoming.globalRating ?? merged.globalRating
            merged.imageURL = incoming.imageURL ?? merged.imageURL
            merged.previewImageURL = incoming.previewImageURL ?? merged.previewImageURL
            merged.platform = incoming.platform
            merged.platforms = incoming.platforms ?? merged.platforms
            merged.detailMetadata = incoming.detailMetadata ?? merged.detailMetadata
        }

        return ensuringPreviewArtwork(merged)
    }

    private func ensuringPreviewArtwork(_ show: Show) -> Show {
        var show = show
        let fallbackArtworkURL = show.previewImageURL ?? show.imageURL
        show.previewImageURL = show.previewImageURL ?? fallbackArtworkURL
        show.imageURL = show.imageURL ?? fallbackArtworkURL
        return show
    }

    private func showsLikelyMatch(_ lhs: Show, _ rhs: Show) -> Bool {
        if lhs.id == rhs.id { return true }
        if let lhsTVMazeId = lhs.tvmazeId, let rhsTVMazeId = rhs.tvmazeId, lhsTVMazeId == rhsTVMazeId { return true }
        if let lhsAniListId = lhs.anilistId, let rhsAniListId = rhs.anilistId, lhsAniListId == rhsAniListId { return true }
        if let lhsMalId = lhs.malId, let rhsMalId = rhs.malId, lhsMalId == rhsMalId { return true }

        guard lhs.isAnime || rhs.isAnime else { return false }
        let titlesOverlap = !Set(searchDedupeKeys(for: lhs)).isDisjoint(with: Set(searchDedupeKeys(for: rhs)))
        let yearsCompatible = lhs.year == nil || rhs.year == nil || lhs.year == rhs.year
        return titlesOverlap && yearsCompatible
    }

    private func searchDedupeKeys(for show: Show) -> [String] {
        let titles = [show.title] + (show.alternateTitles ?? [])
        let normalizedTitles = Set(titles.map(normalizedSearchKey).filter { !$0.isEmpty })
        let yearSuffix = show.year.map(String.init) ?? ""
        return normalizedTitles.map { "\($0)|\(yearSuffix)" }
    }

    private func normalizedSearchKey(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "[^a-z0-9]+", with: "", options: .regularExpression)
    }

    private func mergeAlternateTitles(existing: [String]?, incoming: [String]?) -> [String]? {
        let values = (existing ?? []) + (incoming ?? [])
        guard !values.isEmpty else { return nil }
        return uniqueTitles(values)
    }

    private func preferredMetadataSource(existing: ShowMetadataSource, incoming: ShowMetadataSource, isAnime: Bool) -> ShowMetadataSource {
        if isAnime, incoming == .anilist { return .anilist }
        if existing == .sample { return incoming }
        return existing
    }

    private func tvmazeAppID(_ id: Int) -> Int {
        id
    }

    private func anilistAppID(_ id: Int) -> Int {
        -id
    }

    private func uniqueTitles(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []

        for value in values {
            guard !seen.contains(value) else { continue }
            seen.insert(value)
            ordered.append(value)
        }

        return ordered
    }

    // ── Vibes ─────────────────────────────────────────────────────────────────
    func updateVibeForFriend(friendId: Int, vibe: VibeOption) {
        if let idx = friends.firstIndex(where: { $0.id == friendId }) {
            let showId = friends[idx].currentShowId
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                friends[idx].vibe  = vibe
                friends[idx].score = vibe.representativeScore
            }
            constellationPulseEvent = ConstellationPulseEvent(friendId: friendId, showId: showId)
        }
    }

    func updateVibeForMyShow(myShowId: Int, vibe: VibeOption) {
        guard let idx = myShows.firstIndex(where: { $0.id == myShowId }) else { return }
        let score = vibe.representativeScore

        withAnimation(.spring(response: 0.46, dampingFraction: 0.78)) {
            var reordered = myShows
            var ratedShow = reordered.remove(at: idx)
            ratedShow.needsVibeCheck = false
            reordered.insert(ratedShow, at: 0)
            myShows = reordered
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 360_000_000)
            guard let updatedIndex = myShows.firstIndex(where: { $0.id == myShowId }) else { return }

            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                var updated = myShows
                updated[updatedIndex].vibe = vibe
                updated[updatedIndex].score = score
                updated[updatedIndex].lastChecked = "just now"
                updated[updatedIndex].needsVibeCheck = false
                myShows = updated
            }

            // Sync to Supabase if authenticated
            if isAuthenticated, let uid = supabase.currentUser?.id.uuidString {
                let ms = myShows.first(where: { $0.id == myShowId })
                guard let ms = ms else { return }
                Task {
                    try? await supabase.updateVibe(showId: ms.showId, userId: uid, vibe: vibe, score: ms.score)
                    try? await supabase.logActivity(showId: ms.showId, action: "updated vibe", vibe: vibe, score: ms.score)
                }
            }
        }
    }

    // ── Episode tracking ──────────────────────────────────────────────────────
    func logEpisode(myShowId: Int) {
        if let idx = myShows.firstIndex(where: { $0.id == myShowId }) {
            let total = myShows[idx].totalEpisodes
            myShows[idx].currentEpisode = min(total, myShows[idx].currentEpisode + 1)
            // Sync
            if isAuthenticated, let uid = supabase.currentUser?.id.uuidString {
                let ms = myShows[idx]
                Task { try? await supabase.updateEpisode(showId: ms.showId, userId: uid, episode: ms.currentEpisode, season: ms.currentSeason) }
            }
        }
    }

    func decrementEpisode(myShowId: Int) {
        if let idx = myShows.firstIndex(where: { $0.id == myShowId }) {
            myShows[idx].currentEpisode = max(1, myShows[idx].currentEpisode - 1)
        }
    }

    func incrementSeason(myShowId: Int) {
        if let idx = myShows.firstIndex(where: { $0.id == myShowId }) {
            myShows[idx].currentSeason += 1
            myShows[idx].currentEpisode = 1
        }
    }

    func decrementSeason(myShowId: Int) {
        if let idx = myShows.firstIndex(where: { $0.id == myShowId }) {
            myShows[idx].currentSeason = max(1, myShows[idx].currentSeason - 1)
            myShows[idx].currentEpisode = 1
        }
    }

    func submitCheckIn(show: Show, season: Int?, episode: Int?, score: Double) {
        let show = upsertShow(show)

        let snappedScore = CheckInStep.from(score).score
        let vibe = VibeOption.from(score: snappedScore)
        let seasonValue = season.map { max(1, $0) }
        let episodeValue = episode.map { max(1, $0) }
        let isFirstCheckInForShow = !myShows.contains { $0.showId == show.id }

        withAnimation(.spring(response: 0.46, dampingFraction: 0.78)) {
            var reordered = myShows
            if let existingIndex = reordered.firstIndex(where: { $0.showId == show.id }) {
                var checkedIn = reordered.remove(at: existingIndex)
                checkedIn.score = snappedScore
                checkedIn.vibe = vibe
                checkedIn.lastChecked = "just now"
                checkedIn.needsVibeCheck = false
                if let seasonValue {
                    checkedIn.currentSeason = seasonValue
                }
                if let episodeValue {
                    checkedIn.currentEpisode = episodeValue
                    checkedIn.totalEpisodes = max(
                        seasonEpisodeLimit(for: show, season: checkedIn.currentSeason, fallback: checkedIn.totalEpisodes),
                        episodeValue
                    )
                }
                reordered.insert(checkedIn, at: 0)
            } else {
                let nextId = (reordered.map(\.id).max() ?? -1) + 1
                let currentSeason = seasonValue ?? 1
                let checkedIn = MyShow(
                    id: nextId,
                    showId: show.id,
                    score: snappedScore,
                    currentEpisode: episodeValue ?? 1,
                    totalEpisodes: max(seasonEpisodeLimit(for: show, season: currentSeason, fallback: 1), episodeValue ?? 1),
                    currentSeason: currentSeason,
                    lastChecked: "just now",
                    vibe: vibe,
                    needsVibeCheck: false
                )
                reordered.insert(checkedIn, at: 0)
            }
            myShows = reordered
        }

        refreshDerivedRankingScores()
        recordCheckInMilestones(show: show, isFirstCheckInForShow: isFirstCheckInForShow)

        guard isAuthenticated, let uid = supabase.currentUser?.id.uuidString,
              let checkedIn = myShows.first(where: { $0.showId == show.id }) else { return }
        Task {
            if let episodeValue {
                try? await supabase.updateEpisode(showId: show.id, userId: uid, episode: episodeValue, season: seasonValue ?? checkedIn.currentSeason)
            }
            try? await supabase.updateVibe(showId: show.id, userId: uid, vibe: vibe, score: snappedScore)
            try? await supabase.logActivity(showId: show.id, action: "checked in", vibe: vibe, score: snappedScore)
        }
    }

    // ── Probe requests ────────────────────────────────────────────────────────

    var pendingIncomingProbes: [ProbeRequest] {
        probeRequests.filter { $0.isIncoming && $0.status == .pending }
    }

    func sendProbe(showId: Int, toFriendIds: [Int], message: String?) {
        let nextId = (probeRequests.map(\.id).max() ?? -1) + 1
        let probe = ProbeRequest(
            id: nextId,
            fromFriendId: -1,
            showId: showId,
            message: message,
            status: .pending,
            timeAgo: "just now",
            isIncoming: false,
            toFriendIds: toFriendIds
        )
        probeRequests.append(probe)
    }

    func acceptProbe(_ id: Int) {
        guard let idx = probeRequests.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.80)) {
            probeRequests[idx].status = .accepted
        }
        // Add the show to rotation if not already there
        let showId = probeRequests[idx].showId
        if let show = shows.first(where: { $0.id == showId }), myShow(for: showId) == nil {
            addShowToRotation(show)
        }
    }

    func denyProbe(_ id: Int) {
        guard let idx = probeRequests.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.80)) {
            probeRequests[idx].status = .denied
        }
    }

    // ── Episode comments ──────────────────────────────────────────────────────
    func addEpisodeComment(showId: Int, season: Int, episode: Int, text: String) {
        let sanitizedText = Self.normalizedEpisodeComment(text)
        guard !sanitizedText.isEmpty else { return }

        // Replace any existing own comment for this episode
        episodeComments.removeAll { $0.showId == showId && $0.season == season && $0.episode == episode && $0.isOwn }
        let nextId = (episodeComments.map(\.id).max() ?? -1) + 1
        let comment = EpisodeComment(
            id: nextId,
            showId: showId,
            season: season,
            episode: episode,
            text: sanitizedText,
            authorName: "You",
            authorInitials: "ME",
            authorHexColor: shows.first(where: { $0.id == showId })?.accentColor ?? "38b8c4",
            timeAgo: "just now",
            isOwn: true
        )
        episodeComments.append(comment)
        refreshDerivedRankingScores()
    }

    private static let episodeCommentCharacterLimit = 280

    private static func normalizedEpisodeComment(_ text: String) -> String {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return String(normalized.prefix(episodeCommentCharacterLimit))
    }

    /// Own comment for a specific episode, if any.
    func myComment(showId: Int, season: Int, episode: Int) -> EpisodeComment? {
        episodeComments.first { $0.showId == showId && $0.season == season && $0.episode == episode && $0.isOwn }
    }

    /// Friend comments visible to the user — only revealed once the user has surpassed (watched past) that episode.
    func visibleFriendComments(showId: Int, season: Int, episode: Int, currentEpisode: Int) -> [EpisodeComment] {
        guard episode < currentEpisode else { return [] }
        return episodeComments.filter { $0.showId == showId && $0.season == season && $0.episode == episode && !$0.isOwn }
    }

    /// Friend comments that are locked because the user hasn't surpassed this episode yet.
    func lockedFriendComments(showId: Int, season: Int, episode: Int, currentEpisode: Int) -> [EpisodeComment] {
        guard episode >= currentEpisode else { return [] }
        return episodeComments.filter { $0.showId == showId && $0.season == season && $0.episode == episode && !$0.isOwn }
    }

    // ── Season ratings ────────────────────────────────────────────────────────
    func mySeasonRating(showId: Int, season: Int) -> UserSeasonRating? {
        seasonRatings.first { $0.showId == showId && $0.season == season && $0.isOwn }
    }

    func seasonRatingsFor(showId: Int, season: Int) -> [UserSeasonRating] {
        seasonRatings.filter { $0.showId == showId && $0.season == season }
    }

    func submitSeasonRating(showId: Int, season: Int, score: Double) {
        let snapped = CheckInStep.from(score).score
        seasonRatings.removeAll { $0.showId == showId && $0.season == season && $0.isOwn }
        let nextId = (seasonRatings.map(\.id).max() ?? -1) + 1
        let newRating = UserSeasonRating(
            id: nextId,
            showId: showId,
            season: season,
            score: snapped,
            authorName: "You",
            authorInitials: "ME",
            authorHexColor: shows.first(where: { $0.id == showId })?.accentColor ?? "38b8c4",
            isOwn: true,
            timeAgo: "just now"
        )
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            seasonRatings.insert(newRating, at: 0)
        }
        refreshDerivedRankingScores()
        if isAuthenticated {
            Task { try? await supabase.upsertSeasonRating(showId: showId, season: season, score: snapped) }
        }
    }

    // ── Helper lookups ────────────────────────────────────────────────────────
    func show(for id: Int) -> Show? { shows.first(where: { $0.id == id }) }
    func friend(for id: Int) -> Friend? { friends.first(where: { $0.id == id }) }
    func myShow(for showId: Int) -> MyShow? { myShows.first(where: { $0.showId == showId }) }
    func friendsWatching(showId: Int) -> [Friend] {
        friends.filter { $0.watchedShowIds.contains(showId) }
    }

    func coWatchStreaks(showId: Int) -> [CoWatchStreak] {
        friendsWatching(showId: showId)
            .prefix(5)
            .enumerated()
            .map { index, friend in
                let days = max(2, 8 - index + (friend.id % 2))
                return CoWatchStreak(
                    showId: showId,
                    friend: friend,
                    days: days,
                    label: index == 0 ? "in sync" : "watching together",
                    isSynced: index < 2
                )
            }
    }

    func communityScore(for showId: Int) -> Double? {
        let scores = friendsWatching(showId: showId).map(\.score).filter { $0 >= 1 && $0 <= 5 }
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / Double(scores.count)
    }

    private func recordCheckInMilestones(show: Show, isFirstCheckInForShow: Bool) {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            if isFirstCheckInForShow {
                // Pioneer check: no one in the friend group has seen this show yet.
                // Rover supersedes the plain firstVibeCheck — no need to show both.
                let noFriendsWatching = friendsWatching(showId: show.id).isEmpty
                if noFriendsWatching {
                    prependMilestone(
                        kind: .roverPioneer,
                        title: "Rover",
                        subtitle: "You're the first in your orbit to explore \(show.title).",
                        badge: "1st",
                        systemImage: "scope",
                        accentHex: "D4832A",
                        showId: show.id,
                        friendId: nil
                    )
                } else {
                    prependMilestone(
                        kind: .firstVibeCheck,
                        title: "First vibe check",
                        subtitle: "\(show.title) has its first trail marker.",
                        badge: "new",
                        systemImage: "sparkle",
                        accentHex: show.accentColor,
                        showId: show.id,
                        friendId: nil
                    )
                }
            }

            checkInStreakDays += 1
            if checkInStreakDays == 3 || checkInStreakDays == 5 || checkInStreakDays % 7 == 0 {
                prependMilestone(
                    kind: .checkInStreak,
                    title: "\(checkInStreakDays)-day check-in streak",
                    subtitle: "You kept your orbit active.",
                    badge: "\(checkInStreakDays)d",
                    systemImage: "flame.fill",
                    accentHex: "E5604A",
                    showId: show.id,
                    friendId: nil
                )
            }

            if let streak = coWatchStreaks(showId: show.id).first {
                prependMilestone(
                    kind: .coWatchStreak,
                    title: "\(streak.friend.name) is in sync",
                    subtitle: "You both checked in on \(show.title).",
                    badge: "\(streak.days)d",
                    systemImage: "person.2.fill",
                    accentHex: show.accentColor,
                    showId: show.id,
                    friendId: streak.friend.id
                )
            }
        }
    }

    private func prependMilestone(
        kind: MilestoneKind,
        title: String,
        subtitle: String,
        badge: String,
        systemImage: String,
        accentHex: String,
        showId: Int?,
        friendId: Int?
    ) {
        milestones.removeAll { $0.kind == kind && $0.showId == showId && $0.friendId == friendId && $0.badge == badge }
        let nextId = (milestones.map(\.id).max() ?? -1) + 1
        let milestone = Milestone(
            id: nextId,
            kind: kind,
            title: title,
            subtitle: subtitle,
            badge: badge,
            systemImage: systemImage,
            accentHex: accentHex,
            showId: showId,
            friendId: friendId,
            timeAgo: "just now"
        )
        milestones.insert(milestone, at: 0)
        if milestones.count > 8 {
            milestones = Array(milestones.prefix(8))
        }
        enqueueAchievementToast(milestone)
    }

    func completeAchievementToast(id: Int) {
        guard activeAchievementToast?.id == id else { return }
        activeAchievementToast = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { [weak self] in
            self?.presentNextAchievementToastIfNeeded()
        }
    }

    private func enqueueAchievementToast(_ milestone: Milestone) {
        queuedAchievementToasts.append(milestone)
        presentNextAchievementToastIfNeeded()
    }

    private func presentNextAchievementToastIfNeeded() {
        guard activeAchievementToast == nil, !queuedAchievementToasts.isEmpty else { return }
        activeAchievementToast = queuedAchievementToasts.removeFirst()
    }

    private func seasonEpisodeLimit(for show: Show, season: Int, fallback: Int) -> Int {
        show.episodeCount(forSeason: season, fallback: fallback) ?? fallback
    }
}
