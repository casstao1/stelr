import Foundation
import Supabase

@MainActor
final class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    @Published var currentUser: User?
    @Published var isAuthenticated = false

    private init() {
        client = SupabaseClient(
            supabaseURL: AppConfig.supabaseURL,
            supabaseKey: AppConfig.supabaseAnonKey
        )
        Task { await checkSession() }
    }

    // MARK: - Auth
    func checkSession() async {
        do {
            let session = try await client.auth.session
            currentUser = session.user
            isAuthenticated = true
        } catch {
            isAuthenticated = false
        }
    }

    func signUp(email: String, password: String) async throws {
        let response = try await client.auth.signUp(email: email, password: password)
        currentUser = response.user
        isAuthenticated = currentUser != nil
    }

    func signIn(email: String, password: String) async throws {
        let session = try await client.auth.signIn(email: email, password: password)
        currentUser = session.user
        isAuthenticated = true
    }

    func signOut() async throws {
        try await client.auth.signOut()
        currentUser = nil
        isAuthenticated = false
    }

    // MARK: - Shows (Supabase cache)
    func upsertShow(_ show: Show) async throws {
        guard let tvmazeId = show.tvmazeId else { return }
        struct DBShow: Codable {
            let tvmaze_id: Int
            let title: String
            let platform: String?
            let genre: String?
            let year: Int?
            let summary: String?
            let image_url: String?
            let gradient1: String
            let gradient2: String
            let accent_color: String
            let total_seasons: Int?
            let total_episodes: Int?
        }
        let row = DBShow(tvmaze_id: tvmazeId, title: show.title,
                         platform: show.platform, genre: show.genre,
                         year: show.year, summary: show.summary,
                         image_url: show.imageURL,
                         gradient1: show.gradient1, gradient2: show.gradient2,
                         accent_color: show.accentColor,
                         total_seasons: show.seasons, total_episodes: show.totalEpisodes)
        try await client.from("shows").upsert(row, onConflict: "tvmaze_id").execute()
    }

    // MARK: - User Shows
    func fetchMyShows() async throws -> [DBUserShow] {
        guard let uid = currentUser?.id.uuidString else { return [] }
        let response: [DBUserShow] = try await client.from("user_shows")
            .select()
            .eq("user_id", value: uid)
            .execute()
            .value
        return response
    }

    func addShowToRotation(showId: Int, userId: String) async throws {
        let row = DBUserShow(id: nil, userId: userId, showId: showId,
                             currentSeason: 1, currentEpisode: 1,
                             totalEpisodesInSeason: 10,
                             vibe: "just_ok", score: 7.0)
        try await client.from("user_shows").insert(row).execute()
    }

    func updateVibe(showId: Int, userId: String, vibe: VibeOption, score: Double) async throws {
        let payload: [String: AnyJSON] = [
            "vibe": .string(vibe.rawValue),
            "score": .double(score),
            "last_checked_at": .string(ISO8601DateFormatter().string(from: Date()))
        ]
        try await client.from("user_shows")
            .update(payload)
            .eq("user_id", value: userId)
            .eq("show_id", value: showId)
            .execute()
    }

    func updateEpisode(showId: Int, userId: String, episode: Int, season: Int) async throws {
        let payload: [String: AnyJSON] = [
            "current_episode": .integer(episode),
            "current_season": .integer(season)
        ]
        try await client.from("user_shows")
            .update(payload)
            .eq("user_id", value: userId)
            .eq("show_id", value: showId)
            .execute()
    }

    // MARK: - Activities
    func logActivity(showId: Int, action: String, vibe: VibeOption?, score: Double?) async throws {
        guard let uid = currentUser?.id.uuidString else { return }
        var row: [String: AnyJSON] = [
            "user_id": .string(uid),
            "show_id": .integer(showId),
            "action":  .string(action)
        ]
        if let v = vibe   { row["vibe"]  = .string(v.rawValue) }
        if let s = score  { row["score"] = .double(s) }
        try await client.from("activities").insert(row).execute()
    }

    func fetchFriendActivities() async throws -> [DBActivity] {
        let response: [DBActivity] = try await client.from("activities")
            .select()
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
            .value
        return response
    }

    // MARK: - Recommendations
    func sendRecommendation(showId: Int, toUserIds: [String], message: String) async throws {
        guard let uid = currentUser?.id.uuidString else { return }
        struct Rec: Codable {
            let from_user_id: String
            let to_user_id: String
            let show_id: Int
            let message: String
        }
        let rows = toUserIds.map { Rec(from_user_id: uid, to_user_id: $0, show_id: showId, message: message) }
        try await client.from("recommendations").insert(rows).execute()
    }

    // MARK: - Rallies
    func sendRally(showId: Int) async throws {
        guard let uid = currentUser?.id.uuidString else { return }
        struct Rally: Codable {
            let from_user_id: String
            let show_id: Int
            let message: String
        }
        let row = Rally(from_user_id: uid, show_id: showId, message: "Watch together now!")
        try await client.from("rallies").insert(row).execute()
    }
}
