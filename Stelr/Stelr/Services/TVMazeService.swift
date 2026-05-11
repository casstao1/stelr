import Foundation

actor TVMazeService {
    static let shared = TVMazeService()
    private let base = AppConfig.tvmazeBaseURL
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // Search shows by query
    func searchShows(query: String) async throws -> [TVMazeSearchResult] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(base)/search/shows?q=\(encoded)") else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try decoder.decode([TVMazeSearchResult].self, from: data)
    }

    // Get a single show by TVMaze ID
    func getShow(id: Int) async throws -> TVMazeShow {
        guard let url = URL(string: "\(base)/shows/\(id)") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try decoder.decode(TVMazeShow.self, from: data)
    }

    // Get cast for a show
    func getCast(showId: Int) async throws -> [TVMazeCastMember] {
        guard let url = URL(string: "\(base)/shows/\(showId)/cast") else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try decoder.decode([TVMazeCastMember].self, from: data)
    }

    func getEpisodes(showId: Int) async throws -> [TVMazeEpisode] {
        guard let url = URL(string: "\(base)/shows/\(showId)/episodes") else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try decoder.decode([TVMazeEpisode].self, from: data)
    }

    // Enrich a Show model with live TVMaze data
    func enrichShow(_ show: inout Show) async {
        guard let tvmazeId = show.tvmazeId else { return }
        do {
            let tvShow = try await getShow(id: tvmazeId)
            let cast = try await getCast(showId: tvmazeId)
            let episodes = try await getEpisodes(showId: tvmazeId)
            let apiImageURL = tvShow.image?.original ?? tvShow.image?.medium
            show.detailMetadata = ShowDetailMetadata.fromTVMaze(tvShow)
            show.summary = tvShow.summary?.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            if show.metadataSource != .sample || show.imageURL == nil {
                show.imageURL = apiImageURL
            }
            show.previewImageURL = show.previewImageURL ?? apiImageURL ?? show.imageURL
            show.imageURL = show.imageURL ?? show.previewImageURL
            show.genre = tvShow.genres?.prefix(2).joined(separator: " · ")
            show.year = tvShow.premiered.flatMap { Int($0.prefix(4)) }
            show.globalRating = tvShow.rating?.average
            if !episodes.isEmpty {
                let seasonCounts = Dictionary(grouping: episodes, by: \.season)
                    .mapValues { seasonEpisodes in
                        seasonEpisodes.compactMap(\.number).max() ?? seasonEpisodes.count
                    }
                show.episodeCountsBySeason = seasonCounts
                show.seasons = seasonCounts.keys.max()
                show.totalEpisodes = episodes.count
            }
            let castMembers = cast.prefix(6).map { member in
                CastMember(
                    name: member.person.name,
                    characterName: member.character.name,
                    imageURL: member.person.image?.original ?? member.person.image?.medium
                )
            }
            show.cast = castMembers.map(\.name)
            show.castMembers = castMembers
            let network = tvShow.network?.name ?? tvShow.webChannel?.name
            if let net = network { show.platforms = [net] }
        } catch {
            // Silently use static data if TVMaze is unavailable
        }
    }
}

actor AniListService {
    static let shared = AniListService()
    private let endpoint = AppConfig.anilistGraphQLEndpoint
    private let decoder = JSONDecoder()

    func searchAnime(query: String) async throws -> [AniListMedia] {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: [
                "query": """
                query ($search: String) {
                  Page(page: 1, perPage: 8) {
                    media(search: $search, type: ANIME, isAdult: false) {
                      id
                      idMal
                      title {
                        romaji
                        english
                        native
                      }
                      description(asHtml: false)
                      seasonYear
                      episodes
                      averageScore
                      genres
                      duration
                      season
                      source
                      siteUrl
                      countryOfOrigin
                      startDate {
                        year
                        month
                        day
                      }
                      endDate {
                        year
                        month
                        day
                      }
                      studios(isMain: true) {
                        nodes {
                          name
                        }
                      }
                      coverImage {
                        extraLarge
                        large
                        medium
                      }
                      status
                      format
                    }
                  }
                }
                """,
                "variables": [
                    "search": query
                ]
            ]
        )

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try decoder.decode(AniListGraphQLResponse<AniListPageData>.self, from: data)
        return response.data?.Page.media ?? []
    }

    func getAnime(id: Int) async throws -> AniListMedia {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: [
                "query": """
                query ($id: Int) {
                  Media(id: $id, type: ANIME, isAdult: false) {
                    id
                    idMal
                    title {
                      romaji
                      english
                      native
                    }
                    description(asHtml: false)
                    seasonYear
                    episodes
                    averageScore
                    genres
                    duration
                    season
                    source
                    siteUrl
                    countryOfOrigin
                    startDate {
                      year
                      month
                      day
                    }
                    endDate {
                      year
                      month
                      day
                    }
                    studios(isMain: true) {
                      nodes {
                        name
                      }
                    }
                    coverImage {
                      extraLarge
                      large
                      medium
                    }
                    status
                    format
                  }
                }
                """,
                "variables": [
                    "id": id
                ]
            ]
        )

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try decoder.decode(AniListGraphQLResponse<AniListMediaData>.self, from: data)
        if let media = response.data?.Media {
            return media
        }
        throw URLError(.cannotParseResponse)
    }
}
