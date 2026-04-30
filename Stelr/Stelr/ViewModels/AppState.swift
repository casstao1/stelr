import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    // MARK: - Data
    @Published var shows: [Show] = Show.samples
    @Published var friends: [Friend] = Friend.samples
    @Published var activities: [Activity] = Activity.samples
    @Published var myShows: [MyShow] = MyShow.samples

    // MARK: - TVMaze enrichment
    @Published var isEnrichingShows = false

    // MARK: - Auth state (mirrors SupabaseManager)
    @Published var isAuthenticated = false

    let supabase = SupabaseManager.shared

    init() {
        Task { await enrichShowsFromTVMaze() }
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
                enriched[i] = updated
            }
        }
        shows = enriched
        isEnrichingShows = false
    }

    func searchTVMaze(query: String) async -> [Show] {
        do {
            let results = try await TVMazeService.shared.searchShows(query: query)
            return results.prefix(10).map { res in
                let tv = res.show
                let network = tv.network?.name ?? tv.webChannel?.name ?? "Unknown"
                // Use tvmazeId directly as show ID so repeated searches stay stable
                return Show(
                    id: tv.id,
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
                    cast: nil,
                    platforms: network.isEmpty ? nil : [network],
                    imageURL: tv.image?.original ?? tv.image?.medium
                )
            }
        } catch {
            return []
        }
    }

    // ── Rotation management ───────────────────────────────────────────────────
    func addShowToRotation(_ show: Show) {
        // Upsert show into catalog (avoid duplicates by id)
        if !shows.contains(where: { $0.id == show.id }) {
            shows.append(show)
        }
        // Don't add duplicate rotation entries
        guard !myShows.contains(where: { $0.showId == show.id }) else { return }

        let nextId = (myShows.map(\.id).max() ?? -1) + 1
        let newMyShow = MyShow(
            id: nextId,
            showId: show.id,
            score: 5.0,
            currentEpisode: 1,
            totalEpisodes: show.totalEpisodes ?? 10,
            currentSeason: 1,
            lastChecked: "never",
            vibe: .justOk,
            needsVibeCheck: false
        )
        myShows.append(newMyShow)
    }

    // ── Vibes ─────────────────────────────────────────────────────────────────
    func updateVibeForFriend(friendId: Int, vibe: VibeOption) {
        if let idx = friends.firstIndex(where: { $0.id == friendId }) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                friends[idx].vibe  = vibe
                friends[idx].score = min(10, max(0, friends[idx].score + vibe.scoreDelta))
            }
        }
    }

    func updateVibeForMyShow(myShowId: Int, vibe: VibeOption) {
        guard let idx = myShows.firstIndex(where: { $0.id == myShowId }) else { return }

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
                updated[updatedIndex].score = min(10, max(0, updated[updatedIndex].score + vibe.scoreDelta))
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

    // ── Helper lookups ────────────────────────────────────────────────────────
    func show(for id: Int) -> Show? { shows.first(where: { $0.id == id }) }
    func friend(for id: Int) -> Friend? { friends.first(where: { $0.id == id }) }
    func friendsWatching(showId: Int) -> [Friend] {
        friends.filter { $0.watchedShowIds.contains(showId) }
    }
}
