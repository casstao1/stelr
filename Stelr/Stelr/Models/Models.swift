import Foundation

// MARK: - Vibe
enum VibeOption: String, Codable, CaseIterable, Identifiable {
    case mustWatch   = "must_watch"
    case goingGood   = "going_good"
    case justOk      = "just_ok"
    case superBoring = "super_boring"
    case notForMe    = "not_for_me"
    case notWatching = "not_watching"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mustWatch:   return "can't stop"
        case .goingGood:   return "getting good"
        case .justOk:      return "it's fine"
        case .superBoring: return "losing me"
        case .notForMe:    return "not for me"
        case .notWatching: return "not watching"
        }
    }
    var emoji: String {
        switch self {
        case .mustWatch:   return "🔥"
        case .goingGood:   return "📈"
        case .justOk:      return "😐"
        case .superBoring: return "📉"
        case .notForMe:    return "🚫"
        case .notWatching: return "💤"
        }
    }
    /// Heat state display name (shown on orbs and detail views)
    var heatName: String {
        switch self {
        case .mustWatch:   return "Supernova"
        case .goingGood:   return "Orange Star"
        case .justOk:      return "Yellow Star"
        case .superBoring: return "Blue Star"
        case .notForMe:    return "Cold Rock"
        case .notWatching: return "—"
        }
    }
    var scoreDelta: Double {
        switch self {
        case .mustWatch:   return +0.6
        case .goingGood:   return +0.3
        case .justOk:      return -0.1
        case .superBoring: return -0.5
        case .notForMe:    return -0.8
        case .notWatching: return 0.0
        }
    }
    var hexColor: String {
        switch self {
        case .mustWatch:   return "FFFFFF"   // white — Supernova
        case .goingGood:   return "E5604A"   // stelr orange star
        case .justOk:      return "FFDD44"   // yellow star
        case .superBoring: return "2244BB"   // blue star
        case .notForMe:    return "050507"   // cold rock
        case .notWatching: return "4A4A4A"
        }
    }
    /// Pulse animation: hot vibes breathe, cold rocks are static
    var pulseEnabled: Bool {
        switch self {
        case .mustWatch:   return true
        case .goingGood:   return true
        case .justOk:      return true
        case .superBoring: return false
        case .notForMe:    return false
        case .notWatching: return false
        }
    }
    /// True when the orb should appear matte (no glow)
    var isCold: Bool { self == .superBoring || self == .notForMe || self == .notWatching }
    /// True when labels should use muted treatment instead of the vibe color.
    var isDark: Bool { isCold }

    /// Derive the vibe label from a numeric check-in score (1.0–5.0 in 0.5 steps).
    static func from(score: Double) -> VibeOption {
        let snapped = CheckInStep.from(score).score
        switch snapped {
        case ..<1.5:  return .notForMe     // 1.0
        case ..<3.0:  return .superBoring  // 1.5 – 2.5
        case ..<4.0:  return .justOk       // 3.0 – 3.5
        case ..<5.0:  return .goingGood    // 4.0 – 4.5
        default:      return .mustWatch    // 5.0
        }
    }

    var representativeScore: Double {
        switch self {
        case .mustWatch:   return 5.0
        case .goingGood:   return 4.25
        case .justOk:      return 3.25
        case .superBoring: return 2.0
        case .notForMe:    return 1.0
        case .notWatching: return 1.0
        }
    }
}

// MARK: - SeasonRating
enum SeasonRating: String, CaseIterable, Identifiable {
    case allTimer   = "all_timer"
    case fire       = "fire"
    case solid      = "solid"
    case meh        = "meh"
    case skip       = "skip"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .allTimer: return "🏆"
        case .fire:     return "🔥"
        case .solid:    return "⭐"
        case .meh:      return "😐"
        case .skip:     return "💀"
        }
    }

    var label: String {
        switch self {
        case .allTimer: return "all-timer"
        case .fire:     return "fire"
        case .solid:    return "solid"
        case .meh:      return "meh"
        case .skip:     return "skip it"
        }
    }

    var wholeStarValue: Int {
        switch self {
        case .allTimer: return 5
        case .fire:     return 4
        case .solid:    return 3
        case .meh:      return 2
        case .skip:     return 1
        }
    }

    var starLabel: String {
        wholeStarValue == 1 ? "1 star" : "\(wholeStarValue) stars"
    }

    var sublabel: String {
        switch self {
        case .allTimer: return "one of the best"
        case .fire:     return "really good"
        case .solid:    return "worth watching"
        case .meh:      return "take it or leave it"
        case .skip:     return "don't bother"
        }
    }

    var coreHex: String {
        switch self {
        case .allTimer: return "FFD700"
        case .fire:     return "E5604A"
        case .solid:    return "88aaff"
        case .meh:      return "888899"
        case .skip:     return "6a3a7a"
        }
    }
}

// MARK: - CheckInStep
/// One of the 9 discrete rating steps on the check-in slider.
struct CheckInStep {
    let score: Double
    let starType: String
    /// UI accent colour (used for labels, buttons, track fill). Matches spec track colours.
    let coreHex: String
    /// Slider track fill colour (same as coreHex — kept separate for clarity).
    var trackHex: String { coreHex }
    let pulseSeconds: Double  // core breathe cycle duration — matches spec pulse-speed table
    let vibe: VibeOption

    static let all: [CheckInStep] = [
        // Pulse durations match spec exactly: unrated=6.0 / 1.0=5.5 / 2.0=4.5 / 3.0=3.5 /
        //   3.5=3.0 / 4.0=2.5 / 4.5=2.0 / 5.0=1.5. Half-steps not in spec interpolated.
        CheckInStep(score: 1.0, starType: "Cold rock",    coreHex: "3a3a6a", pulseSeconds: 5.5, vibe: .notForMe),
        CheckInStep(score: 1.5, starType: "Deep blue",    coreHex: "3d3d85", pulseSeconds: 5.0, vibe: .superBoring),
        CheckInStep(score: 2.0, starType: "Blue dwarf",   coreHex: "4040a0", pulseSeconds: 4.5, vibe: .superBoring),
        CheckInStep(score: 2.5, starType: "Blue star",    coreHex: "5878c0", pulseSeconds: 4.0, vibe: .superBoring),
        CheckInStep(score: 3.0, starType: "Blue-white",   coreHex: "7090e0", pulseSeconds: 3.5, vibe: .justOk),
        CheckInStep(score: 3.5, starType: "Blue-yellow",  coreHex: "88aaff", pulseSeconds: 3.0, vibe: .justOk),
        CheckInStep(score: 4.0, starType: "Yellow star",  coreHex: "d4b040", pulseSeconds: 2.5, vibe: .goingGood),
        CheckInStep(score: 4.5, starType: "Orange star",  coreHex: "d08040", pulseSeconds: 2.0, vibe: .goingGood),
        CheckInStep(score: 5.0, starType: "Supernova",    coreHex: "e8d8c0", pulseSeconds: 1.5, vibe: .mustWatch),
    ]

    static func from(_ score: Double) -> CheckInStep {
        all.min(by: { abs($0.score - score) < abs($1.score - score) }) ?? all[0]
    }

    /// core size: 30pt at 1.0 → 54pt at 5.0 (per spec)
    static func coreSize(for score: Double) -> CGFloat {
        30 + CGFloat((score - 1.0) / 4.0) * 24
    }
}

// MARK: - Show
enum ShowMetadataSource: String, Codable {
    case sample
    case tvmaze
    case anilist
}

struct Show: Identifiable, Codable, Equatable {
    var id: Int
    var tvmazeId: Int?
    var anilistId: Int? = nil
    var malId: Int? = nil
    var title: String
    var platform: String
    var currentEpisode: String
    var gradient1: String
    var gradient2: String
    var accentColor: String
    var summary: String?
    var genre: String?
    var year: Int?
    var seasons: Int?
    var totalEpisodes: Int?
    var globalRating: Double? = nil
    var cast: [String]?
    var castMembers: [CastMember]? = nil
    var platforms: [String]?
    var imageURL: String?
    var previewImageURL: String? = nil
    var episodeCountsBySeason: [Int: Int]? = nil
    var isAnime: Bool = false
    var metadataSource: ShowMetadataSource = .sample
    var alternateTitles: [String]? = nil
    var detailMetadata: ShowDetailMetadata? = nil

    func episodeCount(forSeason season: Int, fallback: Int? = nil) -> Int? {
        if let exact = episodeCountsBySeason?[season], exact > 0 {
            return exact
        }
        if let fallback, fallback > 0 {
            return fallback
        }
        guard let totalEpisodes, totalEpisodes > 0 else { return nil }
        guard let seasons, seasons > 1 else { return totalEpisodes }
        return max(1, Int(ceil(Double(totalEpisodes) / Double(seasons))))
    }
}

struct ShowExternalIds: Codable, Equatable {
    var imdb: String?
    var thetvdb: Int?
    var tvrage: Int?
    var myAnimeList: Int?
    var aniList: Int?
}

struct ShowDetailMetadata: Codable, Equatable {
    var type: String?
    var status: String?
    var language: String?
    var runtimeMinutes: Int?
    var averageRuntimeMinutes: Int?
    var premiered: String?
    var ended: String?
    var scheduleTime: String?
    var scheduleDays: [String]?
    var networkName: String?
    var webChannelName: String?
    var countryName: String?
    var countryCode: String?
    var timezone: String?
    var officialSite: String?
    var animeFormat: String?
    var animeStatus: String?
    var animeSeason: String?
    var animeSource: String?
    var animeDurationMinutes: Int?
    var animeStudios: [String]?
    var animeSiteURL: String?
    var animeCountryOfOrigin: String?
    var animeStartDate: String?
    var animeEndDate: String?
    var externalIds: ShowExternalIds?
}

struct CastMember: Identifiable, Codable, Equatable {
    var id: String { "\(name)-\(characterName ?? "")" }
    var name: String
    var characterName: String?
    var imageURL: String?
}

// MARK: - Friend
struct Friend: Identifiable, Codable, Equatable {
    var id: Int
    var name: String
    var initials: String
    var username: String
    var hexColor: String
    var imageURL: String? = nil
    var currentShowId: Int
    var watchingShowIds: [Int]? = nil
    var vibe: VibeOption
    var score: Double
    var isActive: Bool

    var watchedShowIds: [Int] {
        var ids = [currentShowId]
        for showId in watchingShowIds ?? [] where !ids.contains(showId) {
            ids.append(showId)
        }
        return ids
    }
}

// MARK: - Activity
struct Activity: Identifiable {
    var id: Int
    var friendId: Int
    var showId: Int
    var vibe: VibeOption
    var score: Double? = nil
    var timeAgo: String
    var action: String
}

// MARK: - Milestones
enum MilestoneKind: String, Codable {
    case firstVibeCheck
    case checkInStreak
    case coWatchStreak
    case seasonComplete
}

struct Milestone: Identifiable, Equatable {
    var id: Int
    var kind: MilestoneKind
    var title: String
    var subtitle: String
    var badge: String
    var systemImage: String
    var accentHex: String
    var showId: Int?
    var friendId: Int?
    var timeAgo: String
}

struct CoWatchStreak: Identifiable, Equatable {
    var showId: Int
    var friend: Friend
    var days: Int
    var label: String
    var isSynced: Bool

    var id: String { "\(showId)-\(friend.id)" }
}

// MARK: - MyShow (rotation)
struct MyShow: Identifiable {
    var id: Int
    var showId: Int
    var score: Double
    var currentEpisode: Int
    var totalEpisodes: Int
    var currentSeason: Int
    var lastChecked: String
    var vibe: VibeOption
    var needsVibeCheck: Bool
}

// MARK: - TVMaze API
struct TVMazeSearchResult: Codable {
    let score: Double
    let show: TVMazeShow
}
struct TVMazeShow: Codable {
    let id: Int
    let name: String
    let type: String?
    let language: String?
    let status: String?
    let runtime: Int?
    let averageRuntime: Int?
    let summary: String?
    let premiered: String?
    let ended: String?
    let officialSite: String?
    let schedule: TVMazeSchedule?
    let genres: [String]?
    let image: TVMazeImage?
    let network: TVMazeNetwork?
    let webChannel: TVMazeNetwork?
    let rating: TVMazeRating?
    let externals: TVMazeExternals?
}
struct TVMazeImage: Codable {
    let medium: String?
    let original: String?
}
struct TVMazeNetwork: Codable {
    let name: String?
    let country: TVMazeCountry?
}
struct TVMazeCountry: Codable {
    let name: String?
    let code: String?
    let timezone: String?
}
struct TVMazeSchedule: Codable {
    let time: String?
    let days: [String]?
}
struct TVMazeRating: Codable {
    let average: Double?
}
struct TVMazeExternals: Codable {
    let tvrage: Int?
    let thetvdb: Int?
    let imdb: String?
}
struct TVMazeCastMember: Codable {
    let person: TVMazePerson
    let character: TVMazeCharacter
}
struct TVMazeEpisode: Codable {
    let season: Int
    let number: Int?
}
struct TVMazePerson: Codable {
    let name: String
    let image: TVMazeImage?
}
struct TVMazeCharacter: Codable {
    let name: String
}

// MARK: - AniList API
struct AniListGraphQLResponse<T: Decodable>: Decodable {
    let data: T?
}

struct AniListPageData: Decodable {
    let Page: AniListMediaPage
}

struct AniListMediaPage: Decodable {
    let media: [AniListMedia]
}

struct AniListMedia: Decodable {
    let id: Int
    let idMal: Int?
    let title: AniListTitle
    let description: String?
    let seasonYear: Int?
    let episodes: Int?
    let averageScore: Int?
    let genres: [String]?
    let coverImage: AniListCoverImage?
    let status: String?
    let format: String?
    let duration: Int?
    let season: String?
    let source: String?
    let siteUrl: String?
    let countryOfOrigin: String?
    let startDate: AniListFuzzyDate?
    let endDate: AniListFuzzyDate?
    let studios: AniListStudioConnection?
}

struct AniListTitle: Decodable {
    let romaji: String?
    let english: String?
    let native: String?
}

struct AniListCoverImage: Decodable {
    let extraLarge: String?
    let large: String?
    let medium: String?
}

struct AniListFuzzyDate: Decodable {
    let year: Int?
    let month: Int?
    let day: Int?
}

struct AniListStudioConnection: Decodable {
    let nodes: [AniListStudio]
}

struct AniListStudio: Decodable {
    let name: String?
}

extension ShowDetailMetadata {
    static func fromTVMaze(_ show: TVMazeShow) -> ShowDetailMetadata {
        let country = show.network?.country ?? show.webChannel?.country
        return ShowDetailMetadata(
            type: show.type,
            status: show.status,
            language: show.language,
            runtimeMinutes: show.runtime,
            averageRuntimeMinutes: show.averageRuntime,
            premiered: show.premiered,
            ended: show.ended,
            scheduleTime: show.schedule?.time,
            scheduleDays: show.schedule?.days,
            networkName: show.network?.name,
            webChannelName: show.webChannel?.name,
            countryName: country?.name,
            countryCode: country?.code,
            timezone: country?.timezone,
            officialSite: show.officialSite,
            externalIds: ShowExternalIds(
                imdb: show.externals?.imdb,
                thetvdb: show.externals?.thetvdb,
                tvrage: show.externals?.tvrage
            )
        )
    }

    static func fromAniList(_ media: AniListMedia) -> ShowDetailMetadata {
        ShowDetailMetadata(
            status: media.status,
            animeFormat: media.format,
            animeStatus: media.status,
            animeSeason: media.season,
            animeSource: media.source,
            animeDurationMinutes: media.duration,
            animeStudios: media.studios?.nodes.compactMap(\.name).filter { !$0.isEmpty },
            animeSiteURL: media.siteUrl,
            animeCountryOfOrigin: media.countryOfOrigin,
            animeStartDate: formattedDate(media.startDate),
            animeEndDate: formattedDate(media.endDate),
            externalIds: ShowExternalIds(
                myAnimeList: media.idMal,
                aniList: media.id
            )
        )
    }

    private static func formattedDate(_ date: AniListFuzzyDate?) -> String? {
        guard let date, let year = date.year else { return nil }
        guard let month = date.month else { return "\(year)" }
        guard let day = date.day else { return String(format: "%04d-%02d", year, month) }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

// MARK: - Rankings

enum RankingDimension: String, CaseIterable, Identifiable {
    case seasons   = "Seasons"
    case shows     = "Shows"
    case influence = "Influence"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .seasons:   return "play.square.stack"
        case .shows:     return "tv"
        case .influence: return "antenna.radiowaves.left.and.right"
        }
    }

    var unitLabel: String {
        switch self {
        case .seasons:   return "seasons"
        case .shows:     return "shows"
        case .influence: return "pts"
        }
    }

    var emptyLabel: String {
        switch self {
        case .seasons:   return "watch more seasons to climb"
        case .shows:     return "watch or rate more shows to climb"
        case .influence: return "probe shows people actually watch and invite friends"
        }
    }

    var description: String {
        switch self {
        case .seasons:
            return "Total seasons watched across tracked shows."
        case .shows:
            return "Distinct shows each person is watching or has watched."
        case .influence:
            return "Combined score from shows you got friends to watch plus accepted invites."
        }
    }
}

/// One entry in the friends leaderboard — covers all three ranking dimensions.
struct FriendRankEntry: Identifiable {
    var id: Int              // -1 = current user; matches Friend.id otherwise
    var displayName: String
    var username: String
    var initials: String
    var hexColor: String
    var imageURL: String?
    var isYou: Bool

    /// Probes sent where the recipient watched past episode 3.
    var influenceScore: Int
    /// Sum of current season across all tracked shows (proxy for depth of watching).
    var seasonsScore: Int
    /// Count of distinct shows watched or currently being watched.
    var showsScore: Int
    /// Accepted invites — people who joined Stelr via your link.
    var inviteScore: Int

    func score(for dimension: RankingDimension) -> Int {
        switch dimension {
        case .seasons:   return seasonsScore
        case .shows:     return showsScore
        case .influence: return influenceScore + inviteScore
        }
    }
}

extension FriendRankEntry {
    /// Sample data for dev / offline mode.
    /// Scores are seeded plausibly from the Friend.samples profiles.
    static let samples: [FriendRankEntry] = [
        // The current user — scores derived from MyShow.samples (seasons 2+3+1=6)
        FriendRankEntry(id: -1, displayName: "Alex Reeves", username: "alexreeves",
                        initials: "A", hexColor: "E5604A", imageURL: nil, isYou: true,
                        influenceScore: 2, seasonsScore: 6, showsScore: 3, inviteScore: 1),
        // Maya — active watcher, 4 shows running
        FriendRankEntry(id: 0, displayName: "Maya", username: "maya.tv",
                        initials: "M", hexColor: "c06060", imageURL: "https://i.pravatar.cc/160?img=11", isYou: false,
                        influenceScore: 3, seasonsScore: 11, showsScore: 4, inviteScore: 2),
        // Kai — solid watcher
        FriendRankEntry(id: 1, displayName: "Kai", username: "kaibinges",
                        initials: "K", hexColor: "6090c0", imageURL: "https://i.pravatar.cc/160?img=22", isYou: false,
                        influenceScore: 1, seasonsScore: 8, showsScore: 3, inviteScore: 1),
        // Priya — casual
        FriendRankEntry(id: 2, displayName: "Priya", username: "priya.queue",
                        initials: "P", hexColor: "a060c4", imageURL: "https://i.pravatar.cc/160?img=33", isYou: false,
                        influenceScore: 0, seasonsScore: 5, showsScore: 2, inviteScore: 0),
        // Luca — top inviter
        FriendRankEntry(id: 3, displayName: "Luca", username: "lucawatches",
                        initials: "L", hexColor: "60c48a", imageURL: "https://i.pravatar.cc/160?img=44", isYou: false,
                        influenceScore: 2, seasonsScore: 9, showsScore: 3, inviteScore: 3),
        // Zara — mid
        FriendRankEntry(id: 4, displayName: "Zara", username: "zara.after",
                        initials: "Z", hexColor: "c4a840", imageURL: "https://i.pravatar.cc/160?img=55", isYou: false,
                        influenceScore: 1, seasonsScore: 6, showsScore: 3, inviteScore: 0),
        // Noah — top influence
        FriendRankEntry(id: 5, displayName: "Noah", username: "noahnext",
                        initials: "N", hexColor: "d08050", imageURL: "https://i.pravatar.cc/160?img=17", isYou: false,
                        influenceScore: 4, seasonsScore: 7, showsScore: 2, inviteScore: 2),
        // Iris — top seasons watcher, recommends everything
        FriendRankEntry(id: 6, displayName: "Iris", username: "iris.recs",
                        initials: "I", hexColor: "58b8a8", imageURL: "https://i.pravatar.cc/160?img=28", isYou: false,
                        influenceScore: 3, seasonsScore: 12, showsScore: 4, inviteScore: 1),
        // Theo — light watcher
        FriendRankEntry(id: 7, displayName: "Theo", username: "theo.streams",
                        initials: "T", hexColor: "b0a0e0", imageURL: "https://i.pravatar.cc/160?img=39", isYou: false,
                        influenceScore: 0, seasonsScore: 4, showsScore: 3, inviteScore: 0),
    ]
}

// MARK: - ProbeRequest

enum ProbeStatus: String, Codable {
    case pending, accepted, denied
}

struct ProbeRequest: Identifiable {
    var id: Int
    var fromFriendId: Int   // -1 = current user (for outgoing)
    var showId: Int
    var message: String?
    var status: ProbeStatus
    var timeAgo: String
    var isIncoming: Bool    // true = someone probed you; false = you probed someone
    var toFriendIds: [Int]  // populated for outgoing probes
}

// MARK: - ShowList

/// A single ranked slot in a Top-5 list.
/// Either resolves to a known show in the library (`showId` is set)
/// or holds a free-text title the user typed for an unlisted show.
struct ShowListEntry: Identifiable, Equatable {
    var id: UUID = UUID()
    var rank: Int               // 1-based rank (1 = top)
    var showId: Int?            // nil for free-text entries
    var freeTextTitle: String?  // populated only when showId is nil
    var note: String?           // optional user annotation

    var displayTitle: String {
        freeTextTitle ?? "Show \(rank)"
    }

    var isFreeText: Bool { showId == nil }
}

struct ShowList: Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String
    var entries: [ShowListEntry]   // up to 5, ordered by rank
    var createdAt: Date = Date()

    /// Entries sorted by rank, with empty placeholder slots filled in
    var slots: [ShowListEntry?] {
        (1...5).map { rank in entries.first(where: { $0.rank == rank }) }
    }

    var filledCount: Int { entries.count }
}

// MARK: - EpisodeComment
struct EpisodeComment: Identifiable {
    var id: Int
    var showId: Int
    var season: Int
    var episode: Int
    var text: String
    var authorName: String
    var authorInitials: String
    var authorHexColor: String
    var timeAgo: String
    var isOwn: Bool
}

// MARK: - UserSeasonRating
struct UserSeasonRating: Identifiable {
    var id: Int
    var showId: Int
    var season: Int
    var score: Double          // 1.0 – 5.0 in 0.5 steps (matches CheckInStep)
    var authorName: String
    var authorInitials: String
    var authorHexColor: String
    var isOwn: Bool
    var timeAgo: String

    /// Categorical tier derived from the numeric score — kept for legacy display helpers.
    var rating: SeasonRating {
        switch score {
        case ..<1.75: return .skip
        case ..<2.75: return .meh
        case ..<3.75: return .solid
        case ..<4.75: return .fire
        default:      return .allTimer
        }
    }
}

// MARK: - Supabase DB Types
struct DBProfile: Codable {
    let id: String
    var username: String?
    var displayName: String?
    var avatarColor: String?
    enum CodingKeys: String, CodingKey {
        case id, username
        case displayName = "display_name"
        case avatarColor = "avatar_color"
    }
}
struct DBUserShow: Codable {
    let id: String?
    let userId: String
    let showId: Int
    var currentSeason: Int
    var currentEpisode: Int
    var totalEpisodesInSeason: Int
    var vibe: String
    var score: Double
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case showId = "show_id"
        case currentSeason = "current_season"
        case currentEpisode = "current_episode"
        case totalEpisodesInSeason = "total_episodes_in_season"
        case vibe, score
    }
}
struct DBActivity: Codable {
    let id: String?
    let userId: String
    let showId: Int
    let action: String
    var vibe: String?
    var score: Double?
    let createdAt: String?
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case showId = "show_id"
        case action, vibe, score
        case createdAt = "created_at"
    }
}

struct DBSeasonRating: Codable {
    let id: String?
    let userId: String
    let showId: Int
    let season: Int
    let score: Double
    let createdAt: String?
    enum CodingKeys: String, CodingKey {
        case id
        case userId   = "user_id"
        case showId   = "show_id"
        case season, score
        case createdAt = "created_at"
    }
}

struct DBUserList: Codable {
    let id: String
    let userId: String
    let title: String
    let createdAt: String?
    var entries: [DBListEntry]?
    enum CodingKeys: String, CodingKey {
        case id
        case userId    = "user_id"
        case title
        case createdAt = "created_at"
        case entries   = "list_entries"
    }
}

struct DBListEntry: Codable {
    let id: String
    let listId: String
    let rank: Int
    let showId: Int?
    let freeTextTitle: String?
    enum CodingKeys: String, CodingKey {
        case id
        case listId        = "list_id"
        case rank
        case showId        = "show_id"
        case freeTextTitle = "free_text_title"
    }
}

// MARK: - Sample Data
extension Show {
    private static func samplePosterURL(_ slug: String) -> String {
        switch slug {
        case "severance":
            return "https://static2.tribute.ca/poster/660x980/severance-apple-tv-205837.jpg"
        case "the-last-of-us":
            return "https://image.tmdb.org/t/p/w500/uKvVjHNqB5VmOrdxqAt2F7J78ED.jpg"
        case "the-white-lotus":
            return "https://image.tmdb.org/t/p/w500/gbSaK9v1CbcYH1ISgbM7XObD2dW.jpg"
        case "adolescence":
            return "https://image.tmdb.org/t/p/w500/20i4nShZZg1g1VFHSB8xpaYM4r7.jpg"
        case "slow-horses":
            return "https://is1-ssl.mzstatic.com/image/thumb/bArDzA292bd3Xk7rKhn42Q/1200x2133nr-60.jpg"
        case "the-bear":
            return "https://img3.hulu.com/user/v3/artwork/05eb6a8e-90ed-4947-8c0b-e6536cbddd5f?base_image_bucket_name=image_manager&base_image=672ec510-99e9-40d9-a4bb-efda6b4ac44f&size=600x900&format=jpeg"
        case "shogun":
            return "https://img2.hulu.com/user/v3/artwork/5422a5f9-e4f1-475e-9217-65e8249388d0?base_image_bucket_name=image_manager&base_image=f592a3dc-051e-4df0-bc77-9045b69e365b&size=600x900&format=jpeg"
        case "the-studio":
            return "https://is1-ssl.mzstatic.com/image/thumb/IUeYwps2EAzS8Rpa9TLY3A/1200x2133nr-60.jpg"
        default:
            return "https://picsum.photos/seed/stelr-\(slug)-poster/400/600"
        }
    }

    private static func samplePreviewURL(_ slug: String) -> String {
        switch slug {
        case "severance":
            return "https://is1-ssl.mzstatic.com/image/thumb/sWbO9RKGr81f6-iTFF9d4g/1200x675sr-60.jpg"
        case "the-last-of-us":
            return "https://beam-images.warnermediacdn.com/2025-03/the-last-of-us_s2_bg_48x14_hero.jpg?host=wbd-dotcom-drupal-prd-us-east-1.s3.amazonaws.com&w=2400"
        case "the-white-lotus":
            return "https://beam-images.warnermediacdn.com/2025-02/twl-hero-bg_1.jpg?host=wbd-dotcom-drupal-prd-us-east-1.s3.amazonaws.com&w=2400"
        case "adolescence":
            return "https://occ-0-2433-2705.1.nflxso.net/dnm/api/v6/6AYY37jfdO6hpXcMjf9Yu5cnmO0/AAAABcKLKe3zBLLNJ1PouelWYSjmGiWys8ky3kJIc5Yw7Kfapb1srU-_zX4DtXdLqmAOEkOF6mz98X5Fw_92gZZP1J_KGKfyrWv0f4zm.jpg?r=442"
        case "slow-horses":
            return "https://is1-ssl.mzstatic.com/image/thumb/ie2RoKhs3MVe_Jon4mcDDQ/1200x675sr-60.jpg"
        case "the-bear":
            return "https://img3.hulu.com/user/v3/artwork/05eb6a8e-90ed-4947-8c0b-e6536cbddd5f?base_image_bucket_name=image_manager&base_image=1a6c5f4d-c9e3-4a75-a26a-ca8d45a90c7a&size=1600x900&format=jpeg"
        case "shogun":
            return "https://img2.hulu.com/user/v3/artwork/5422a5f9-e4f1-475e-9217-65e8249388d0?base_image_bucket_name=image_manager&base_image=04b53e27-2b43-4d16-9e71-96bdc12df8cd&size=1600x900&format=jpeg"
        case "the-studio":
            return "https://is1-ssl.mzstatic.com/image/thumb/5fF2vNTh4Bo1hT1Mcbmggw/1200x675sr-60.jpg"
        default:
            return "https://picsum.photos/seed/stelr-\(slug)-preview/1400/900"
        }
    }

    static let samples: [Show] = [
        Show(id: 0, tvmazeId: 44933, title: "Severance", platform: "Apple TV+",
             currentEpisode: "S2 · E8", gradient1: "173540", gradient2: "02090D",
             accentColor: "6FAEB8", summary: "Mark leads a team of office workers whose memories have been surgically divided between work and personal lives.",
             genre: "Sci-Fi · Thriller", year: 2022, seasons: 2, totalEpisodes: 19,
             cast: ["Adam Scott","Zach Cherry","Britt Lower","Tramell Tillman","John Turturro"],
             platforms: ["Apple TV+"], imageURL: samplePosterURL("severance"),
             previewImageURL: samplePreviewURL("severance")),
        Show(id: 1, tvmazeId: 46562, title: "The Last of Us", platform: "HBO",
             currentEpisode: "S2 · E4", gradient1: "25251B", gradient2: "090A07",
             accentColor: "A9A57A", summary: "After a global pandemic, a hardened survivor takes charge of a teenage girl who may be humanity's last hope.",
             genre: "Drama · Horror", year: 2023, seasons: 2, totalEpisodes: 16,
             cast: ["Pedro Pascal","Bella Ramsey","Anna Torv","Gabriel Luna"],
             platforms: ["HBO","Max"], imageURL: samplePosterURL("the-last-of-us"),
             previewImageURL: samplePreviewURL("the-last-of-us")),
        Show(id: 2, tvmazeId: 51394, title: "The White Lotus", platform: "HBO",
             currentEpisode: "S3 · E6", gradient1: "1E2E24", gradient2: "080F0A",
             accentColor: "6F8A52", summary: "A social satire following the staff and guests of an exclusive tropical resort across three anthology seasons.",
             genre: "Drama · Dark Comedy", year: 2021, seasons: 3, totalEpisodes: 24,
             cast: ["Jennifer Coolidge","Theo James","Carrie Coon","Walton Goggins"],
             platforms: ["HBO","Max"], imageURL: samplePosterURL("the-white-lotus"),
             previewImageURL: samplePreviewURL("the-white-lotus")),
        Show(id: 3, tvmazeId: 78570, title: "Adolescence", platform: "Netflix",
             currentEpisode: "E3", gradient1: "241C13", gradient2: "090806",
             accentColor: "8E6B4D", summary: "A working-class family is thrown into crisis when their 13-year-old son is arrested for murder.",
             genre: "Crime · Drama", year: 2025, seasons: 1, totalEpisodes: 4,
             cast: ["Stephen Graham","Owen Cooper","Erin Doherty","Ashley Walters"],
             platforms: ["Netflix"], imageURL: samplePosterURL("adolescence"),
             previewImageURL: samplePreviewURL("adolescence")),
        Show(id: 4, tvmazeId: 45039, title: "Slow Horses", platform: "Apple TV+",
             currentEpisode: "S4 · E5", gradient1: "24251A", gradient2: "090A07",
             accentColor: "A7A07A", summary: "A group of MI5 agents navigate the grey areas of British intelligence from Slough House.",
             genre: "Spy Thriller", year: 2022, seasons: 4, totalEpisodes: 24,
             cast: ["Gary Oldman","Kristin Scott Thomas","Jack Lowden","Saskia Reeves"],
             platforms: ["Apple TV+"], imageURL: samplePosterURL("slow-horses"),
             previewImageURL: samplePreviewURL("slow-horses")),
        Show(id: 5, tvmazeId: 54198, title: "The Bear", platform: "FX",
             currentEpisode: "S3 · E2", gradient1: "17243A", gradient2: "070A12",
             accentColor: "4C668A", summary: "A young chef, his kitchen crew, and a family restaurant push each other through pressure, grief, and reinvention.",
             genre: "Drama · Comedy", year: 2022, seasons: 3, totalEpisodes: 28,
             cast: ["Jeremy Allen White","Ayo Edebiri","Ebon Moss-Bachrach","Liza Colón-Zayas"],
             platforms: ["FX","Hulu"], imageURL: samplePosterURL("the-bear"),
             previewImageURL: samplePreviewURL("the-bear")),
        Show(id: 6, tvmazeId: 37336, title: "Shōgun", platform: "FX",
             currentEpisode: "Finished", gradient1: "102A33", gradient2: "040A0D",
             accentColor: "2F6E78", summary: "A stranded English pilot becomes entangled in the power struggle of feudal Japan.",
             genre: "Historical Drama", year: 2024, seasons: 1, totalEpisodes: 10,
             cast: ["Hiroyuki Sanada","Cosmo Jarvis","Anna Sawai","Tadanobu Asano"],
             platforms: ["FX","Hulu"], imageURL: samplePosterURL("shogun"),
             previewImageURL: samplePreviewURL("shogun")),
        Show(id: 7, tvmazeId: 75605, title: "The Studio", platform: "Apple TV+",
             currentEpisode: "S1 · E6", gradient1: "2A1F14", gradient2: "090705",
             accentColor: "8F6A42", summary: "A Hollywood studio head tries to keep movies alive while navigating ego, commerce, and chaos.",
             genre: "Comedy", year: 2025, seasons: 1, totalEpisodes: 10,
             cast: ["Seth Rogen","Catherine O'Hara","Ike Barinholtz","Chase Sui Wonders"],
             platforms: ["Apple TV+"], imageURL: samplePosterURL("the-studio"),
             previewImageURL: samplePreviewURL("the-studio")),
    ]
}
extension Friend {
    private static func mockProfileURL(_ imageIndex: Int) -> String {
        let normalizedIndex = ((abs(imageIndex) - 1) % 70) + 1
        return "https://i.pravatar.cc/160?img=\(normalizedIndex)"
    }

    static let samples: [Friend] = [
        Friend(id: 0, name: "Maya",  initials: "M", username: "maya.tv",    hexColor: "c06060", imageURL: mockProfileURL(11), currentShowId: 0, watchingShowIds: [1, 5, 7], vibe: .goingGood, score: 4.5, isActive: true),
        Friend(id: 1, name: "Kai",   initials: "K", username: "kaibinges",  hexColor: "6090c0", imageURL: mockProfileURL(22), currentShowId: 0, watchingShowIds: [2, 3],   vibe: .goingGood, score: 4.5, isActive: true),
        Friend(id: 2, name: "Priya", initials: "P", username: "priya.queue", hexColor: "a060c4", imageURL: mockProfileURL(33), currentShowId: 2, watchingShowIds: [6],      vibe: .justOk,    score: 3.5, isActive: false),
        Friend(id: 3, name: "Luca",  initials: "L", username: "lucawatches", hexColor: "60c48a", imageURL: mockProfileURL(44), currentShowId: 1, watchingShowIds: [3, 5],   vibe: .goingGood, score: 4.0, isActive: true),
        Friend(id: 4, name: "Zara",  initials: "Z", username: "zara.after",  hexColor: "c4a840", imageURL: mockProfileURL(55), currentShowId: 4, watchingShowIds: [0, 2],   vibe: .justOk,    score: 3.0, isActive: false),
        Friend(id: 5, name: "Noah",  initials: "N", username: "noahnext",    hexColor: "d08050", imageURL: mockProfileURL(17), currentShowId: 0, watchingShowIds: [1],      vibe: .goingGood, score: 4.5, isActive: true),
        Friend(id: 6, name: "Iris",  initials: "I", username: "iris.recs",   hexColor: "58b8a8", imageURL: mockProfileURL(28), currentShowId: 1, watchingShowIds: [0, 3, 4], vibe: .goingGood, score: 4.0, isActive: true),
        Friend(id: 7, name: "Theo",  initials: "T", username: "theo.streams", hexColor: "b0a0e0", imageURL: mockProfileURL(39), currentShowId: 4, watchingShowIds: [1, 7],   vibe: .justOk,    score: 3.0, isActive: false),
    ]

    static let suggestedSamples: [Friend] = [
        Friend(id: 20, name: "Deanna", initials: "D", username: "deanna.recs", hexColor: "8AADC0", imageURL: mockProfileURL(47), currentShowId: 6, watchingShowIds: [0, 5], vibe: .goingGood, score: 4.0, isActive: true),
        Friend(id: 21, name: "Felicia", initials: "F", username: "felicia.tv", hexColor: "C88E74", imageURL: mockProfileURL(56), currentShowId: 7, watchingShowIds: [2, 3], vibe: .justOk, score: 3.5, isActive: false),
        Friend(id: 22, name: "Najin", initials: "N", username: "najin.watch", hexColor: "9EBA70", imageURL: mockProfileURL(64), currentShowId: 5, watchingShowIds: [1, 4], vibe: .goingGood, score: 4.5, isActive: true),
    ]
}
extension Activity {
    static let samples: [Activity] = [
        Activity(id: 0, friendId: 0, showId: 0, vibe: .goingGood, score: 4.5, timeAgo: "2m ago",  action: "just re-rated"),
        Activity(id: 1, friendId: 1, showId: 3, vibe: .goingGood, score: 4.5, timeAgo: "18m ago", action: "checked in on"),
        Activity(id: 2, friendId: 2, showId: 2, vibe: .justOk,    score: 3.5, timeAgo: "1h ago",  action: "updated vibe on"),
        Activity(id: 3, friendId: 3, showId: 1, vibe: .goingGood, score: 4.0, timeAgo: "3h ago",  action: "rated"),
        Activity(id: 4, friendId: 4, showId: 4, vibe: .justOk,    score: 3.0, timeAgo: "5h ago",  action: "checked in on"),
        Activity(id: 5, friendId: 0, showId: 5, vibe: .goingGood, score: 4.0, timeAgo: "6h ago",  action: "started"),
        Activity(id: 6, friendId: 2, showId: 6, vibe: .justOk,    score: 3.0, timeAgo: "1d ago",  action: "finished"),
        Activity(id: 7, friendId: 7, showId: 7, vibe: .justOk,    score: 3.5, timeAgo: "1d ago",  action: "checked in on"),
    ]
}

extension Milestone {
    static let samples: [Milestone] = [
        Milestone(
            id: 0,
            kind: .checkInStreak,
            title: "4-day check-in streak",
            subtitle: "Keep rating once a day to hold the orbit.",
            badge: "4d",
            systemImage: "flame.fill",
            accentHex: "E5604A",
            showId: nil,
            friendId: nil,
            timeAgo: "today"
        ),
        Milestone(
            id: 1,
            kind: .coWatchStreak,
            title: "Maya is in sync",
            subtitle: "You both checked in on Severance this week.",
            badge: "7d",
            systemImage: "person.2.fill",
            accentHex: "6FAEB8",
            showId: 0,
            friendId: 0,
            timeAgo: "2m ago"
        ),
        Milestone(
            id: 2,
            kind: .firstVibeCheck,
            title: "First vibe check",
            subtitle: "Your first score starts the show’s trail.",
            badge: "new",
            systemImage: "sparkle",
            accentHex: "F0DDAF",
            showId: 3,
            friendId: nil,
            timeAgo: "1d ago"
        ),
    ]
}

extension EpisodeComment {
    // Sample data for show 0 (Severance), where user is at S2·E7.
    // - Own notes: episodes 3 and 5 (already watched)
    // - Visible friend notes: episodes 2, 4, 6 (user has surpassed them — episode < currentEpisode 7)
    // - Locked friend notes: episodes 8 and 9 (user hasn't reached them yet — spoiler protection)
    static let samples: [EpisodeComment] = [
        // Your own notes
        EpisodeComment(id: 0, showId: 0, season: 2, episode: 3,
            text: "The way the innies interact here completely reframed the whole show for me.",
            authorName: "You", authorInitials: "ME", authorHexColor: "38b8c4", timeAgo: "1w ago", isOwn: true),
        EpisodeComment(id: 1, showId: 0, season: 2, episode: 5,
            text: "Absolute gut punch. Did not see that coming at all.",
            authorName: "You", authorInitials: "ME", authorHexColor: "38b8c4", timeAgo: "4d ago", isOwn: true),

        // Visible friend notes (user has passed these episodes)
        EpisodeComment(id: 2, showId: 0, season: 2, episode: 2,
            text: "Dylan's subplot in this one is so underrated honestly.",
            authorName: "Maya", authorInitials: "M", authorHexColor: "c06060", timeAgo: "5d ago", isOwn: false),
        EpisodeComment(id: 3, showId: 0, season: 2, episode: 4,
            text: "The dancing scene. I wasn't ready. Watched it twice.",
            authorName: "Maya", authorInitials: "M", authorHexColor: "c06060", timeAgo: "3d ago", isOwn: false),
        EpisodeComment(id: 4, showId: 0, season: 2, episode: 5,
            text: "ok episode 5 broke me. just sitting here.",
            authorName: "Kai", authorInitials: "K", authorHexColor: "6090c0", timeAgo: "4d ago", isOwn: false),
        EpisodeComment(id: 5, showId: 0, season: 2, episode: 6,
            text: "That cliffhanger ending — calling someone immediately after.",
            authorName: "Kai", authorInitials: "K", authorHexColor: "6090c0", timeAgo: "2d ago", isOwn: false),
        EpisodeComment(id: 6, showId: 0, season: 2, episode: 6,
            text: "Might be the best episode of anything I've watched this year.",
            authorName: "Iris", authorInitials: "I", authorHexColor: "58b8a8", timeAgo: "1d ago", isOwn: false),

        // Locked — user hasn't surpassed these episodes yet
        EpisodeComment(id: 7, showId: 0, season: 2, episode: 8,
            text: "THIS EPISODE. I have no words. Season finale energy already??",
            authorName: "Noah", authorInitials: "N", authorHexColor: "d08050", timeAgo: "18h ago", isOwn: false),
        EpisodeComment(id: 8, showId: 0, season: 2, episode: 9,
            text: "ok I need to talk to someone about this.",
            authorName: "Maya", authorInitials: "M", authorHexColor: "c06060", timeAgo: "6h ago", isOwn: false),
    ]
}

extension UserSeasonRating {
    static let samples: [UserSeasonRating] = [
        // Season 1 ratings for Severance (show 0)
        UserSeasonRating(id: 0, showId: 0, season: 1, score: 5.0,
            authorName: "You", authorInitials: "ME", authorHexColor: "38b8c4",
            isOwn: true, timeAgo: "3w ago"),
        UserSeasonRating(id: 1, showId: 0, season: 1, score: 4.5,
            authorName: "Maya", authorInitials: "M", authorHexColor: "c06060",
            isOwn: false, timeAgo: "3w ago"),
        UserSeasonRating(id: 2, showId: 0, season: 1, score: 4.0,
            authorName: "Kai", authorInitials: "K", authorHexColor: "6090c0",
            isOwn: false, timeAgo: "2w ago"),
        UserSeasonRating(id: 3, showId: 0, season: 1, score: 3.5,
            authorName: "Iris", authorInitials: "I", authorHexColor: "58b8a8",
            isOwn: false, timeAgo: "1w ago"),
        UserSeasonRating(id: 4, showId: 0, season: 1, score: 5.0,
            authorName: "Noah", authorInitials: "N", authorHexColor: "d08050",
            isOwn: false, timeAgo: "5d ago"),
        // Season 2 ratings for Severance (show 0) — season in progress, friends ahead
        UserSeasonRating(id: 5, showId: 0, season: 2, score: 4.0,
            authorName: "Noah", authorInitials: "N", authorHexColor: "d08050",
            isOwn: false, timeAgo: "1d ago"),
        // Season 3 of The White Lotus (show 2)
        UserSeasonRating(id: 6, showId: 2, season: 3, score: 4.5,
            authorName: "You", authorInitials: "ME", authorHexColor: "38b8c4",
            isOwn: true, timeAgo: "2d ago"),
        UserSeasonRating(id: 7, showId: 2, season: 3, score: 5.0,
            authorName: "Kai", authorInitials: "K", authorHexColor: "6090c0",
            isOwn: false, timeAgo: "3d ago"),
        UserSeasonRating(id: 8, showId: 2, season: 3, score: 3.5,
            authorName: "Iris", authorInitials: "I", authorHexColor: "58b8a8",
            isOwn: false, timeAgo: "4d ago"),
    ]
}

extension ProbeRequest {
    static let samples: [ProbeRequest] = [
        // Incoming — Maya probing you with Slow Horses (show id 4)
        ProbeRequest(id: 0, fromFriendId: 0, showId: 4,
            message: "Gary Oldman is absolutely unhinged in this — you need to be watching it",
            status: .pending, timeAgo: "12m ago", isIncoming: true, toFriendIds: []),

        // Incoming — Noah probing you with The Studio (show id 7)
        ProbeRequest(id: 1, fromFriendId: 5, showId: 7,
            message: "Seth Rogen playing a studio exec is the most chaotic thing I've seen",
            status: .pending, timeAgo: "2h ago", isIncoming: true, toFriendIds: []),

        // Outgoing — you probed Kai with The White Lotus (show id 2), already accepted
        ProbeRequest(id: 2, fromFriendId: -1, showId: 2,
            message: "Season 3 in Thailand is unreal, start from the beginning",
            status: .accepted, timeAgo: "1d ago", isIncoming: false, toFriendIds: [1]),

        // Outgoing — you probed Luca with Adolescence (show id 3), pending
        ProbeRequest(id: 3, fromFriendId: -1, showId: 3,
            message: nil,
            status: .pending, timeAgo: "3d ago", isIncoming: false, toFriendIds: [3]),
    ]
}

extension MyShow {
    static let samples: [MyShow] = [
        MyShow(id: 0, showId: 0, score: 4.5, currentEpisode: 7,  totalEpisodes: 10, currentSeason: 2, lastChecked: "5 eps ago",  vibe: .goingGood, needsVibeCheck: true),
        MyShow(id: 1, showId: 2, score: 3.5, currentEpisode: 5,  totalEpisodes: 8,  currentSeason: 3, lastChecked: "yesterday",  vibe: .justOk,    needsVibeCheck: false),
        MyShow(id: 2, showId: 3, score: 3.5, currentEpisode: 2,  totalEpisodes: 4,  currentSeason: 1, lastChecked: "1 week ago", vibe: .justOk,    needsVibeCheck: false),
    ]
}

// MARK: - ShootingStarEvent

/// A queued "friend finished a show" event that produces a shooting star on the constellation.
struct ShootingStarEvent: Identifiable {
    let id: UUID
    let friend: Friend
    let show: Show
    let season: Int
    let completedAt: Date

    init(friend: Friend, show: Show, season: Int, completedAt: Date = Date(), id: UUID = UUID()) {
        self.id = id
        self.friend = friend
        self.show = show
        self.season = season
        self.completedAt = completedAt
    }
}

extension ShootingStarEvent {
    /// Two pre-seeded events so the feature is immediately visible in the simulator/preview.
    static let samples: [ShootingStarEvent] = [
        ShootingStarEvent(
            friend: Friend.samples[0],  // Maya
            show:   Show.samples[0],    // show id 0
            season: 2
        ),
        ShootingStarEvent(
            friend: Friend.samples[1],  // second friend
            show:   Show.samples[2],    // show id 2
            season: 3
        ),
    ]
}
