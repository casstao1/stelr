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

    // Enrich a Show model with live TVMaze data
    func enrichShow(_ show: inout Show) async {
        guard let tvmazeId = show.tvmazeId else { return }
        do {
            let tvShow = try await getShow(id: tvmazeId)
            let cast = try await getCast(showId: tvmazeId)
            show.summary = tvShow.summary?.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            show.imageURL = tvShow.image?.original ?? tvShow.image?.medium
            show.genre = tvShow.genres?.prefix(2).joined(separator: " · ")
            show.year = tvShow.premiered.flatMap { Int($0.prefix(4)) }
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
