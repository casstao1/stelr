import Foundation
import Darwin
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
    }

    // MARK: - Auth
    func checkSession() async {
        guard AppConfig.supabaseEnabled else {
            currentUser = nil
            isAuthenticated = false
            return
        }
        do {
            try ensureSupabaseHostResolves()
            let session = try await client.auth.session
            currentUser = session.user
            isAuthenticated = true
        } catch {
            currentUser = nil
            isAuthenticated = false
        }
    }

    func signUp(email: String, password: String) async throws {
        try ensureSupabaseReady()
        let response = try await client.auth.signUp(email: email, password: password)
        currentUser = response.user
        isAuthenticated = currentUser != nil
    }

    func signIn(email: String, password: String) async throws {
        try ensureSupabaseReady()
        let session = try await client.auth.signIn(email: email, password: password)
        currentUser = session.user
        isAuthenticated = true
    }

    func signOut() async throws {
        try ensureSupabaseReady()
        try await client.auth.signOut()
        currentUser = nil
        isAuthenticated = false
    }

    private func ensureSupabaseReady() throws {
        guard AppConfig.supabaseEnabled else {
            throw SupabaseConnectionError.disabled
        }
        try ensureSupabaseHostResolves()
    }

    private func ensureSupabaseHostResolves() throws {
        guard let host = AppConfig.supabaseURL.host, !host.isEmpty else {
            throw SupabaseConnectionError.invalidURL
        }

        var hints = addrinfo(
            ai_flags: AI_DEFAULT,
            ai_family: AF_UNSPEC,
            ai_socktype: SOCK_STREAM,
            ai_protocol: IPPROTO_TCP,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        var result: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(host, "443", &hints, &result)
        defer {
            if let result {
                freeaddrinfo(result)
            }
        }
        guard status == 0 else {
            throw SupabaseConnectionError.unreachableHost(host)
        }
    }

    enum SupabaseConnectionError: LocalizedError {
        case disabled
        case invalidURL
        case unreachableHost(String)

        var errorDescription: String? {
            switch self {
            case .disabled:
                return "Cloud sync is disabled for this build."
            case .invalidURL:
                return "Supabase URL is invalid."
            case .unreachableHost(let host):
                return "Cannot reach \(host). Check simulator network/DNS or try again in a moment."
            }
        }
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

    func removeShowFromRotation(showId: Int, userId: String) async throws {
        try await client.from("user_shows")
            .delete()
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

    // MARK: - Season Ratings

    func fetchSeasonRatings() async throws -> [DBSeasonRating] {
        guard let uid = currentUser?.id.uuidString else { return [] }
        return try await client.from("season_ratings")
            .select()
            .eq("user_id", value: uid)
            .execute()
            .value
    }

    func upsertSeasonRating(showId: Int, season: Int, score: Double) async throws {
        guard let uid = currentUser?.id.uuidString else { return }
        let payload: [String: AnyJSON] = [
            "user_id" : .string(uid),
            "show_id" : .integer(showId),
            "season"  : .integer(season),
            "score"   : .double(score)
        ]
        try await client.from("season_ratings")
            .upsert(payload, onConflict: "user_id,show_id,season")
            .execute()
    }

    // MARK: - Lists

    func fetchMyLists() async throws -> [DBUserList] {
        guard let uid = currentUser?.id.uuidString else { return [] }
        return try await client.from("user_lists")
            .select("*, list_entries(*)")
            .eq("user_id", value: uid)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func upsertList(_ list: ShowList) async throws {
        guard let uid = currentUser?.id.uuidString else { return }
        let listId = list.id.uuidString

        // 1. Upsert the parent list row
        let listPayload: [String: AnyJSON] = [
            "id"         : .string(listId),
            "user_id"    : .string(uid),
            "title"      : .string(list.title),
            "updated_at" : .string(ISO8601DateFormatter().string(from: Date()))
        ]
        try await client.from("user_lists")
            .upsert(listPayload, onConflict: "id")
            .execute()

        // 2. Delete old entries then re-insert (simplest replace strategy)
        try await client.from("list_entries")
            .delete()
            .eq("list_id", value: listId)
            .execute()

        guard !list.entries.isEmpty else { return }

        let entryRows: [[String: AnyJSON]] = list.entries.map { entry in
            var row: [String: AnyJSON] = [
                "list_id" : .string(listId),
                "rank"    : .integer(entry.rank)
            ]
            if let showId = entry.showId       { row["show_id"]         = .integer(showId) }
            if let text   = entry.freeTextTitle { row["free_text_title"] = .string(text) }
            return row
        }
        try await client.from("list_entries")
            .insert(entryRows)
            .execute()
    }

    func deleteList(id: UUID) async throws {
        // list_entries cascade-delete via FK
        try await client.from("user_lists")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
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
