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
        case .justOk:      return "Red Dwarf"
        case .superBoring: return "Cold Rock"
        case .notForMe:    return "Dark Matter"
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
        case .goingGood:   return "E5813A"   // warm orange — Orange Star
        case .justOk:      return "8B1A1A"   // deep red — Red Dwarf
        case .superBoring: return "5A5A5A"   // flat grey — Cold Rock
        case .notForMe:    return "2244bb"   // deep blue — Dark Matter
        case .notWatching: return "4A4A4A"
        }
    }
    /// Pulse animation: hot vibes breathe, cold rocks are static
    var pulseEnabled: Bool {
        switch self {
        case .mustWatch:   return true
        case .goingGood:   return true
        case .justOk:      return false
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
        switch score {
        case ..<2.5:  return .notForMe     // 1.0 – 2.0
        case ..<3.5:  return .superBoring  // 2.5 – 3.0
        case 3.5:     return .justOk       // 3.5
        case ..<4.5:  return .goingGood    // 4.0
        default:      return .mustWatch    // 4.5 – 5.0
        }
    }
}

// MARK: - CheckInStep
/// One of the 9 discrete rating steps on the check-in slider.
struct CheckInStep {
    let score: Double
    let starType: String
    let coreHex: String      // star core colour
    let pulseSeconds: Double // full pulse cycle duration
    let vibe: VibeOption

    static let all: [CheckInStep] = [
        CheckInStep(score: 1.0, starType: "Cold rock",   coreHex: "1a1a2e", pulseSeconds: 5.0, vibe: .notForMe),
        CheckInStep(score: 1.5, starType: "Dead star",   coreHex: "0f1f4a", pulseSeconds: 4.5, vibe: .notForMe),
        CheckInStep(score: 2.0, starType: "Blue dwarf",  coreHex: "1a2f7a", pulseSeconds: 4.0, vibe: .notForMe),
        CheckInStep(score: 2.5, starType: "Blue star",   coreHex: "2244bb", pulseSeconds: 3.5, vibe: .superBoring),
        CheckInStep(score: 3.0, starType: "Blue-white",  coreHex: "3388dd", pulseSeconds: 3.0, vibe: .superBoring),
        CheckInStep(score: 3.5, starType: "Light blue",  coreHex: "66bbff", pulseSeconds: 2.6, vibe: .justOk),
        CheckInStep(score: 4.0, starType: "Yellow star", coreHex: "ffdd44", pulseSeconds: 2.2, vibe: .goingGood),
        CheckInStep(score: 4.5, starType: "Orange star", coreHex: "ff8833", pulseSeconds: 1.8, vibe: .mustWatch),
        CheckInStep(score: 5.0, starType: "Supernova",   coreHex: "ffffff", pulseSeconds: 1.4, vibe: .mustWatch),
    ]

    static func from(_ score: Double) -> CheckInStep {
        all.min(by: { abs($0.score - score) < abs($1.score - score) }) ?? all[0]
    }

    /// core size: 32pt at 1.0 → 60pt at 5.0
    static func coreSize(for score: Double) -> CGFloat {
        32 + CGFloat((score - 1.0) / 4.0) * 28
    }
}

// MARK: - Show
struct Show: Identifiable, Codable, Equatable {
    var id: Int
    var tvmazeId: Int?
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
    var cast: [String]?
    var castMembers: [CastMember]? = nil
    var platforms: [String]?
    var imageURL: String?
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
    var timeAgo: String
    var action: String
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
    let summary: String?
    let premiered: String?
    let genres: [String]?
    let image: TVMazeImage?
    let network: TVMazeNetwork?
    let webChannel: TVMazeNetwork?
    let rating: TVMazeRating?
}
struct TVMazeImage: Codable {
    let medium: String?
    let original: String?
}
struct TVMazeNetwork: Codable {
    let name: String?
}
struct TVMazeRating: Codable {
    let average: Double?
}
struct TVMazeCastMember: Codable {
    let person: TVMazePerson
    let character: TVMazeCharacter
}
struct TVMazePerson: Codable {
    let name: String
    let image: TVMazeImage?
}
struct TVMazeCharacter: Codable {
    let name: String
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

// MARK: - Sample Data
extension Show {
    static let samples: [Show] = [
        Show(id: 0, tvmazeId: 44933, title: "Severance", platform: "Apple TV+",
             currentEpisode: "S2 · E8", gradient1: "081e24", gradient2: "020b0e",
             accentColor: "38b8c4", summary: "Mark leads a team of office workers whose memories have been surgically divided between work and personal lives.",
             genre: "Sci-Fi · Thriller", year: 2022, seasons: 2, totalEpisodes: 19,
             cast: ["Adam Scott","Zach Cherry","Britt Lower","Tramell Tillman","John Turturro"],
             platforms: ["Apple TV+"], imageURL: "https://static.tvmaze.com/uploads/images/original_untouched/548/1371406.jpg"),
        Show(id: 1, tvmazeId: 46562, title: "The Last of Us", platform: "HBO",
             currentEpisode: "S2 · E4", gradient1: "1c160a", gradient2: "0a0804",
             accentColor: "c4922a", summary: "After a global pandemic, a hardened survivor takes charge of a teenage girl who may be humanity's last hope.",
             genre: "Drama · Horror", year: 2023, seasons: 2, totalEpisodes: 16,
             cast: ["Pedro Pascal","Bella Ramsey","Anna Torv","Gabriel Luna"],
             platforms: ["HBO","Max"], imageURL: "https://static.tvmaze.com/uploads/images/original_untouched/563/1409008.jpg"),
        Show(id: 2, tvmazeId: 51394, title: "The White Lotus", platform: "HBO",
             currentEpisode: "S3 · E6", gradient1: "281610", gradient2: "120806",
             accentColor: "c07040", summary: "A social satire following the staff and guests of an exclusive tropical resort across three anthology seasons.",
             genre: "Drama · Dark Comedy", year: 2021, seasons: 3, totalEpisodes: 24,
             cast: ["Jennifer Coolidge","Theo James","Carrie Coon","Walton Goggins"],
             platforms: ["HBO","Max"], imageURL: "https://static.tvmaze.com/uploads/images/original_untouched/557/1393876.jpg"),
        Show(id: 3, tvmazeId: 78570, title: "Adolescence", platform: "Netflix",
             currentEpisode: "E3", gradient1: "0c1420", gradient2: "05080f",
             accentColor: "587ec0", summary: "A working-class family is thrown into crisis when their 13-year-old son is arrested for murder.",
             genre: "Crime · Drama", year: 2025, seasons: 1, totalEpisodes: 4,
             cast: ["Stephen Graham","Owen Cooper","Erin Doherty","Ashley Walters"],
             platforms: ["Netflix"], imageURL: "https://static.tvmaze.com/uploads/images/original_untouched/558/1395109.jpg"),
        Show(id: 4, tvmazeId: 45039, title: "Slow Horses", platform: "Apple TV+",
             currentEpisode: "S4 · E5", gradient1: "12180c", gradient2: "070a05",
             accentColor: "78aa48", summary: "A group of MI5 agents navigate the grey areas of British intelligence from Slough House.",
             genre: "Spy Thriller", year: 2022, seasons: 4, totalEpisodes: 24,
             cast: ["Gary Oldman","Kristin Scott Thomas","Jack Lowden","Saskia Reeves"],
             platforms: ["Apple TV+"], imageURL: "https://static.tvmaze.com/uploads/images/original_untouched/593/1484384.jpg"),
    ]
}
extension Friend {
    static let samples: [Friend] = [
        Friend(id: 0, name: "Maya",  initials: "M", username: "maya.tv",    hexColor: "c06060", currentShowId: 0, watchingShowIds: [0, 4],    vibe: .goingGood,   score: 8.4, isActive: true),
        Friend(id: 1, name: "Kai",   initials: "K", username: "kaibinges",  hexColor: "6090c0", currentShowId: 0, watchingShowIds: [0, 3],    vibe: .mustWatch,   score: 9.0, isActive: true),
        Friend(id: 2, name: "Priya", initials: "P", username: "priya.queue", hexColor: "a060c4", currentShowId: 2, watchingShowIds: [2, 0],    vibe: .goingGood,   score: 9.1, isActive: false),
        Friend(id: 3, name: "Luca",  initials: "L", username: "lucawatches", hexColor: "60c48a", currentShowId: 2, watchingShowIds: [2, 1],    vibe: .justOk,      score: 6.4, isActive: true),
        Friend(id: 4, name: "Zara",  initials: "Z", username: "zara.after",  hexColor: "c4a840", currentShowId: 4, watchingShowIds: [4, 2],    vibe: .goingGood,   score: 7.8, isActive: false),
        Friend(id: 5, name: "Noah",  initials: "N", username: "noahnext",    hexColor: "d08050", currentShowId: 0, watchingShowIds: [0, 2, 4], vibe: .goingGood,   score: 8.1, isActive: true),
        Friend(id: 6, name: "Iris",  initials: "I", username: "iris.recs",   hexColor: "58b8a8", currentShowId: 1, watchingShowIds: [1, 3],    vibe: .mustWatch,   score: 8.7, isActive: true),
        Friend(id: 7, name: "Theo",  initials: "T", username: "theo.streams", hexColor: "b0a0e0", currentShowId: 3, watchingShowIds: [3, 1],    vibe: .justOk,      score: 6.0, isActive: false),
    ]
}
extension Activity {
    static let samples: [Activity] = [
        Activity(id: 0, friendId: 0, showId: 0, vibe: .goingGood,   timeAgo: "2m ago",  action: "just re-rated"),
        Activity(id: 1, friendId: 1, showId: 3, vibe: .justOk,      timeAgo: "18m ago", action: "started watching"),
        Activity(id: 2, friendId: 2, showId: 2, vibe: .goingGood,   timeAgo: "1h ago",  action: "updated vibe on"),
        Activity(id: 3, friendId: 3, showId: 1, vibe: .superBoring, timeAgo: "3h ago",  action: "lost the vibe on"),
        Activity(id: 4, friendId: 4, showId: 4, vibe: .notWatching, timeAgo: "5h ago",  action: "paused watching"),
    ]
}
extension MyShow {
    static let samples: [MyShow] = [
        MyShow(id: 0, showId: 0, score: 7.4, currentEpisode: 7,  totalEpisodes: 10, currentSeason: 2, lastChecked: "5 eps ago",  vibe: .goingGood,   needsVibeCheck: true),
        MyShow(id: 1, showId: 2, score: 8.9, currentEpisode: 5,  totalEpisodes: 8,  currentSeason: 3, lastChecked: "yesterday",   vibe: .goingGood,   needsVibeCheck: false),
        MyShow(id: 2, showId: 3, score: 5.8, currentEpisode: 2,  totalEpisodes: 4,  currentSeason: 1, lastChecked: "1 week ago",  vibe: .justOk,      needsVibeCheck: false),
    ]
}
