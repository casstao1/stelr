import SwiftUI

private enum ShowDetailDataTab: String, CaseIterable, Identifiable {
    case takes
    case vibes
    case spaceRace
    case details

    var id: String { rawValue }

    var title: String {
        switch self {
        case .takes:
            return "Takes"
        case .vibes:
            return "Vibes"
        case .spaceRace:
            return "Space Race"
        case .details:
            return "Details"
        }
    }
}

private struct DetailStarScatterOverlay: View {
    var starCount: Int = 120

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }

            for index in 0..<starCount {
                let x = CGFloat(Double(index * 151).truncatingRemainder(dividingBy: 997) / 997) * size.width
                let y = CGFloat(Double(index * 211 + 37).truncatingRemainder(dividingBy: 991) / 991) * size.height
                let radius = CGFloat(0.48 + Double(index % 7) * 0.11)
                let opacity = 0.08 + Double(index % 5) * 0.018
                let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)

                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))

                if index % 17 == 0 {
                    let glowRect = rect.insetBy(dx: -2.8, dy: -2.8)
                    context.fill(Path(ellipseIn: glowRect), with: .color(Color(hex: "FFF2BA").opacity(0.035)))
                }
            }
        }
    }
}

struct ShowDetailView: View {
    let show: Show
    let watchingFriends: [Friend]
    var onClose: (() -> Void)? = nil

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSendProbe = false
    @State private var checkInShow: Show? = nil
    @State private var markedWatched = false
    @State private var pageAppeared = false
    @State private var dataTabContentAppeared = true
    @State private var showEpisodeNoteSheet = false
    @State private var showSummarySheet = false
    @State private var noteTargetEpisode: Int = 1
    @State private var sharedSelectedSeason: Int = 1
    @State private var selectedDataTab: ShowDetailDataTab = .takes
    @State private var showSeasonRatingSheet = false
    @State private var seasonRatingTarget: Int = 1
    @State private var profileFriend: Friend?

    private var myShow: MyShow? {
        appState.myShow(for: show.id)
    }

    private var isInRotation: Bool {
        myShow != nil
    }

    private var isWatchlisted: Bool {
        appState.isWatchlisted(showId: show.id)
    }

    private var seasonCount: Int {
        max(show.seasons ?? currentSeason, currentSeason)
    }

    private var currentSeason: Int {
        max(1, myShow?.currentSeason ?? inferredSeason)
    }

    private var currentEpisode: Int {
        min(max(1, myShow?.currentEpisode ?? inferredEpisode), totalEpisodes)
    }

    private var totalEpisodes: Int {
        let seasonTotal = show.episodeCount(
            forSeason: currentSeason,
            fallback: myShow?.totalEpisodes ?? show.totalEpisodes ?? 10
        )
        return max(1, seasonTotal ?? 10)
    }

    private var progressFraction: CGFloat {
        guard totalEpisodes > 0 else { return 0 }
        return min(1, max(0, CGFloat(currentEpisode) / CGFloat(totalEpisodes)))
    }

    private var summaryText: String {
        show.summary ?? "No summary available yet."
    }

    private var friendRatingScores: [Double] {
        watchingFriends.map(\.score).filter { $0 >= 1 && $0 <= 5 }
    }

    private var communityRating: Double? {
        guard !friendRatingScores.isEmpty else { return nil }
        return friendRatingScores.reduce(0, +) / Double(friendRatingScores.count)
    }

    private var raceEntries: [EpisodeRaceEntry] {
        let youEntry = EpisodeRaceEntry(
            id: "you",
            name: "You",
            initials: "YOU",
            colorHex: show.accentColor,
            episode: currentEpisode,
            isYou: true,
            lastCheckIn: myShow?.lastChecked,
            interactionScore: Int.max,
            friendID: nil,
            imageURL: nil
        )

        let friendEntries = watchingFriends
            .sorted(by: raceFriendSort)
            .map { friend in
                EpisodeRaceEntry(
                    id: "friend-\(friend.id)",
                    name: friend.name,
                    initials: friend.initials,
                    colorHex: friend.hexColor,
                    episode: raceEpisode(for: friend),
                    isYou: false,
                    lastCheckIn: lastCheckInText(for: friend),
                    interactionScore: interactionScore(for: friend),
                    friendID: friend.id,
                    imageURL: friend.imageURL
                )
            }

        return [youEntry] + friendEntries
    }

    private func raceFriendSort(_ lhs: Friend, _ rhs: Friend) -> Bool {
        let lhsInteraction = interactionScore(for: lhs)
        let rhsInteraction = interactionScore(for: rhs)
        if lhsInteraction != rhsInteraction { return lhsInteraction > rhsInteraction }

        let lhsEpisode = raceEpisode(for: lhs)
        let rhsEpisode = raceEpisode(for: rhs)
        if lhsEpisode != rhsEpisode { return lhsEpisode > rhsEpisode }

        if lhs.isActive != rhs.isActive { return lhs.isActive && !rhs.isActive }
        if lhs.score != rhs.score { return lhs.score > rhs.score }
        return lhs.id < rhs.id
    }

    private func interactionScore(for friend: Friend) -> Int {
        var score = 0

        for (index, activity) in appState.activities.enumerated() where activity.friendId == friend.id {
            score += max(1, 12 - index)
            if activity.showId == show.id {
                score += 6
            }
        }

        for probe in appState.probeRequests where probe.fromFriendId == friend.id || probe.toFriendIds.contains(friend.id) {
            score += 8
            if probe.showId == show.id {
                score += 3
            }
        }

        for comment in appState.episodeComments where !comment.isOwn && comment.authorName == friend.name {
            score += 5
            if comment.showId == show.id {
                score += 3
            }
        }

        if friend.isActive {
            score += 2
        }
        if friend.currentShowId == show.id {
            score += 2
        }

        return score
    }

    private func raceEpisode(for friend: Friend) -> Int {
        if let activity = appState.activities.first(where: { $0.friendId == friend.id && $0.showId == show.id }) {
            let action = activity.action.lowercased()
            if action.contains("finish") {
                return totalEpisodes
            }
            if action.contains("start") {
                return 1
            }
        }

        if friend.currentShowId == show.id {
            return currentEpisode
        }

        let normalizedScore = min(1, max(0, (friend.score - 1.0) / 4.0))
        let seededNudge = Double((friend.id + show.id) % 3) * 0.035
        let progress = min(0.96, max(0.16, 0.18 + normalizedScore * 0.70 + seededNudge))
        return min(totalEpisodes, max(1, Int((progress * Double(totalEpisodes)).rounded())))
    }

    private func lastCheckInText(for friend: Friend) -> String? {
        if let checkIn = appState.activities.first(where: {
            $0.friendId == friend.id &&
            $0.showId == show.id &&
            $0.action.lowercased().contains("check")
        }) {
            return checkIn.timeAgo
        }

        return appState.activities.first(where: {
            $0.friendId == friend.id &&
            $0.showId == show.id
        })?.timeAgo
    }

    private var raceClusters: [EpisodeRaceCluster] {
        let grouped = Dictionary(grouping: raceEntries, by: \.episode)
        return grouped
            .map { episode, entries in
                EpisodeRaceCluster(
                    episode: episode,
                    entries: entries.sorted { lhs, rhs in
                        if lhs.isYou != rhs.isYou { return lhs.isYou && !rhs.isYou }
                        return lhs.name < rhs.name
                    }
                )
            }
            .sorted { lhs, rhs in
                if lhs.episode != rhs.episode { return lhs.episode > rhs.episode }
                return lhs.containsYou && !rhs.containsYou
            }
    }

    private var recentActivityRows: [PlanetActivityRowData] {
        let rows = appState.activities
            .filter { $0.showId == show.id }
            .prefix(3)
            .map { activity in
                PlanetActivityRowData(
                    id: activity.id,
                    name: appState.friend(for: activity.friendId)?.name ?? "Someone",
                    action: activity.action,
                    timeAgo: activity.timeAgo
                )
            }

        if !rows.isEmpty {
            return Array(rows)
        }

        return [
            PlanetActivityRowData(id: -1, name: "You", action: isInRotation ? "are watching" : "opened", timeAgo: "now")
        ]
    }

    private var primaryButtonTitle: String {
        if markedWatched { return "✓ Marked watched" }
        if currentEpisode >= totalEpisodes { return "Season finished" }
        return "Mark E\(currentEpisode + 1) watched"
    }

    private var primaryButtonDisabled: Bool {
        markedWatched || currentEpisode >= totalEpisodes
    }

    private var inferredSeason: Int {
        let pattern = #"S(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: show.currentEpisode, range: NSRange(show.currentEpisode.startIndex..., in: show.currentEpisode)),
              let range = Range(match.range(at: 1), in: show.currentEpisode),
              let season = Int(show.currentEpisode[range]) else {
            return 1
        }
        return season
    }

    private var inferredEpisode: Int {
        let pattern = #"E(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: show.currentEpisode, range: NSRange(show.currentEpisode.startIndex..., in: show.currentEpisode)),
              let range = Range(match.range(at: 1), in: show.currentEpisode),
              let episode = Int(show.currentEpisode[range]) else {
            return 1
        }
        return episode
    }

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width

            ZStack(alignment: .top) {
                StelrStarFieldBackground(includesRadialBloom: false, starCount: 86)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        .clear,
                        Color(hex: show.gradient2).opacity(0.08),
                        Color.stelrBg.opacity(0.18),
                        Color.black.opacity(0.44)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                DetailStarScatterOverlay(starCount: 132)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        DetailMockHeroSection(
                            show: show,
                            episodeCount: show.totalEpisodes ?? totalEpisodes,
                            communityScore: communityRating,
                            communityCount: friendRatingScores.count,
                            globalRating: show.globalRating
                        )
                        .frame(width: screenWidth, alignment: .leading)
                        .opacity(pageAppeared ? 1 : 0)
                        .offset(y: pageAppeared ? 0 : 28)
                        .animation(.spring(response: 0.58, dampingFraction: 0.86).delay(0.06), value: pageAppeared)

                        VStack(alignment: .leading, spacing: 0) {
                            HStack(alignment: .center, spacing: 12) {
                                Text("Summary")
                                    .font(StelrTypography.sectionTitle)
                                    .foregroundStyle(.primary)

                                Spacer(minLength: 12)

                                DetailHeroActionCluster(
                                    showsBookmark: !isInRotation,
                                    isWatchlisted: isWatchlisted,
                                    onToggleBookmark: {
                                        appState.toggleWatchlist(for: show)
                                        StelrHaptics.success()
                                    },
                                    onCheckIn: {
                                        checkInShow = show
                                    },
                                    onSendProbe: {
                                        showSendProbe = true
                                    }
                                )
                            }
                            .padding(.top, 6)
                            .padding(.bottom, 9)

                            DetailSummarySection(summary: summaryText) {
                                showSummarySheet = true
                            }

                            Text("Watching")
                                .font(StelrTypography.sectionTitle)
                                .foregroundStyle(.primary)
                                .padding(.top, 28)
                                .padding(.bottom, 12)

                            DetailWatchingFriendsRow(friends: watchingFriends) { friend in
                                profileFriend = friend
                            }
                        }
                        .padding(.horizontal, 18)
                        .frame(width: screenWidth, alignment: .leading)
                        .opacity(pageAppeared ? 1 : 0)
                        .offset(y: pageAppeared ? 0 : 28)
                        .animation(.spring(response: 0.58, dampingFraction: 0.86).delay(0.06), value: pageAppeared)

                        Section {
                            detailDataContent(screenWidth: screenWidth)

                            Spacer(minLength: 20)
                        } header: {
                            detailDataHeader(screenWidth: screenWidth)
                                .zIndex(3)
                            }
                        }
                    .frame(width: screenWidth, alignment: .topLeading)
                    .padding(.bottom, max(20, geometry.safeAreaInsets.bottom + 18))
                }
                .frame(width: screenWidth, height: geometry.size.height)
                .clipped()

                topChrome
                    .frame(width: screenWidth, alignment: .top)
            }
            .frame(width: screenWidth, height: geometry.size.height)
            .clipped()
        }
        .sheet(isPresented: $showSendProbe) {
            SendProbeSheet(show: show)
        }
        .sheet(item: $checkInShow) { show in
            VibeCheckSheet(show: show, currentMyShow: appState.myShow(for: show.id)) { season, episode, score in
                appState.submitCheckIn(show: show, season: season, episode: episode, score: score)
            } onSeasonRating: { season, score in
                appState.submitSeasonRating(showId: show.id, season: season, score: score)
            }
        }
        .sheet(isPresented: $showSummarySheet) {
            SummaryPopupSheet(title: show.title, summary: summaryText)
        }
        .sheet(isPresented: $showEpisodeNoteSheet) {
            EpisodeNoteSheet(
                show: show,
                currentSeason: noteSheetSeason,
                currentEpisode: noteSheetEpisodeLimit,
                preSelectedEpisode: noteTargetEpisode
            ) { season, episode, text in
                appState.addEpisodeComment(showId: show.id, season: season, episode: episode, text: text)
            }
        }
        .sheet(isPresented: $showSeasonRatingSheet) {
            SeasonRatingSheet(
                show: show,
                season: seasonRatingTarget,
                existingScore: appState.mySeasonRating(showId: show.id, season: seasonRatingTarget)?.score
            ) { score in
                appState.submitSeasonRating(showId: show.id, season: seasonRatingTarget, score: score)
            }
        }
        .sheet(item: $profileFriend) { friend in
            FriendProfileSheet(friend: friend)
        }
        .onAppear {
            appState.beginShowDetailPresentation()
            sharedSelectedSeason = currentSeason
            pageAppeared = false
            dataTabContentAppeared = true
            DispatchQueue.main.async {
                pageAppeared = true
            }
        }
        .onChange(of: selectedDataTab) { _, _ in
            runDataTabContentEntrance()
        }
        .onDisappear {
            appState.endShowDetailPresentation()
        }
        .onChange(of: currentSeason) { _, newSeason in
            sharedSelectedSeason = min(max(1, newSeason), seasonCount)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(backSwipeGesture)
        .preferredColorScheme(.dark)
    }

    private func detailDataHeader(screenWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if seasonCount > 1 {
                SeasonSwitcher(
                    selectedSeason: $sharedSelectedSeason,
                    seasonCount: seasonCount
                )
                .padding(.horizontal, 18)
                .frame(width: screenWidth, alignment: .leading)
                .padding(.top, 16)
            }

            DetailDataTabBar(selectedTab: $selectedDataTab)
                .frame(width: screenWidth, alignment: .leading)
                .padding(.top, seasonCount > 1 ? 12 : 16)
                .padding(.bottom, 10)
        }
        .opacity(pageAppeared ? 1 : 0)
        .offset(y: pageAppeared ? 0 : 26)
        .animation(.spring(response: 0.52, dampingFraction: 0.84).delay(0.10), value: pageAppeared)
        .background(
            LinearGradient(
                colors: [
                    Color.stelrBg.opacity(0.96),
                    Color.stelrBg.opacity(0.86),
                    Color.stelrBg.opacity(0.34),
                    Color.stelrBg.opacity(0.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .horizontal)
        )
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    @ViewBuilder
    private func detailDataContent(screenWidth: CGFloat) -> some View {
        Group {
            switch selectedDataTab {
            case .takes:
                EpisodeNotesSection(
                    show: show,
                    currentSeason: currentSeason,
                    currentEpisode: currentEpisode,
                    selectedSeason: $sharedSelectedSeason,
                    seasonCount: seasonCount,
                    isLocked: !isInRotation,
                    onAddNote: { episode in
                        noteTargetEpisode = episode
                        showEpisodeNoteSheet = true
                    }
                )
            case .vibes:
                VibesTabView(
                    show: show,
                    selectedSeason: sharedSelectedSeason,
                    seasonCount: seasonCount,
                    canRateSeason: isInRotation,
                    onRateSeason: { season in
                        seasonRatingTarget = season
                        showSeasonRatingSheet = true
                    }
                )
            case .spaceRace:
                SpaceRaceView(
                    entries: raceEntries,
                    currentSeason: currentSeason,
                    currentEpisode: currentEpisode,
                    totalEpisodes: totalEpisodes,
                    episodeCountsBySeason: show.episodeCountsBySeason,
                    seasonCount: seasonCount,
                    selectedSeason: $sharedSelectedSeason,
                    accentHex: show.accentColor,
                    onFriendTap: { friendID in
                        if let friend = appState.friend(for: friendID) {
                            profileFriend = friend
                        }
                    }
                )
            case .details:
                DetailInfoTabView(show: show, castMembers: castMembers)
            }
        }
        .frame(width: screenWidth, alignment: .topLeading)
        .padding(.top, 8)
        .opacity(pageAppeared && dataTabContentAppeared ? 1 : 0)
        .offset(y: (pageAppeared ? 0 : 34) + (dataTabContentAppeared ? 0 : 22))
        .animation(.spring(response: 0.52, dampingFraction: 0.84).delay(0.20), value: pageAppeared)
        .animation(.spring(response: 0.36, dampingFraction: 0.84), value: dataTabContentAppeared)
        .id(selectedDataTab)
    }

    private var backSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .local)
            .onEnded { value in
                guard shouldCloseFromBackSwipe(value) else { return }
                closeNormally()
            }
    }

    private func shouldCloseFromBackSwipe(_ value: DragGesture.Value) -> Bool {
        let horizontalDistance = value.translation.width
        let verticalDistance = abs(value.translation.height)
        let predictedHorizontalDistance = value.predictedEndTranslation.width
        let startsNearLeadingEdge = value.startLocation.x <= 56

        return startsNearLeadingEdge
            && horizontalDistance > 72
            && predictedHorizontalDistance > 112
            && verticalDistance < 54
    }

    private var topChrome: some View {
        HStack {
            Button {
                closeNormally()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.78))
                    .frame(width: 30, height: 30)
                    .background(Color.black.opacity(0.10), in: Circle())
                    .background(.ultraThinMaterial.opacity(0.72), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.055), lineWidth: 0.6))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 5)
            }
            .buttonStyle(.stelrPress)

            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 44)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var primaryCTA: some View {
        Button {
            markNextEpisodeWatched()
        } label: {
            Text(primaryButtonTitle)
                .font(StelrTypography.button)
                .foregroundColor(primaryButtonDisabled ? .stelrMuted : Color(hex: "1a0e02"))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(primaryButtonDisabled ? Color.white.opacity(0.08) : Color.stelrAccent)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: primaryButtonDisabled ? .clear : Color.stelrAccent.opacity(0.18), radius: 12, y: 7)
        }
        .disabled(primaryButtonDisabled)
        .buttonStyle(.stelrPress)
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [
                    Color.stelrBg.opacity(0.02),
                    Color.stelrBg.opacity(0.80),
                    Color.stelrBg
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    // Season / episode scope for the EpisodeNoteSheet — follows the shared picker,
    // and for past seasons allows writing notes up to the full season episode count.
    private var noteSheetSeason: Int { sharedSelectedSeason }
    private var noteSheetEpisodeLimit: Int {
        if sharedSelectedSeason < currentSeason {
            return show.episodeCount(forSeason: sharedSelectedSeason, fallback: 10) ?? 10
        }
        return currentEpisode
    }

    private var castMembers: [CastMember] {
        if let castMembers = show.castMembers, !castMembers.isEmpty {
            return castMembers
        }
        let mockedEnsemble = mockCastEnsemble(for: show)
        if !mockedEnsemble.isEmpty {
            return mockedEnsemble
        }
        return (show.cast ?? []).enumerated().map { idx, name in
            CastMember(
                name: name,
                characterName: genericMockRole(for: idx),
                imageURL: mockProfileURL(imageIndex: show.id * 9 + idx + 1)
            )
        }
    }

    private func mockCastEnsemble(for show: Show) -> [CastMember] {
        switch show.id {
        case 1:
            return [
                CastMember(name: "Pedro Pascal", characterName: "Joel", imageURL: mockProfileURL(imageIndex: 12)),
                CastMember(name: "Bella Ramsey", characterName: "Ellie", imageURL: mockProfileURL(imageIndex: 32)),
                CastMember(name: "Gabriel Luna", characterName: "Tommy", imageURL: mockProfileURL(imageIndex: 15)),
                CastMember(name: "Isabela Merced", characterName: "Dina", imageURL: mockProfileURL(imageIndex: 44)),
                CastMember(name: "Young Mazino", characterName: "Jesse", imageURL: mockProfileURL(imageIndex: 18)),
                CastMember(name: "Kaitlyn Dever", characterName: "Abby", imageURL: mockProfileURL(imageIndex: 47)),
                CastMember(name: "Rutina Wesley", characterName: "Maria", imageURL: mockProfileURL(imageIndex: 39)),
                CastMember(name: "Anna Torv", characterName: "Tess", imageURL: mockProfileURL(imageIndex: 52)),
                CastMember(name: "Jeffrey Wright", characterName: "Isaac", imageURL: mockProfileURL(imageIndex: 58)),
                CastMember(name: "Catherine O'Hara", characterName: "Gail", imageURL: mockProfileURL(imageIndex: 65))
            ]
        default:
            let baseNames = show.cast ?? []
            let featured = baseNames.enumerated().map { idx, name in
                CastMember(
                    name: name,
                    characterName: genericMockRole(for: idx),
                    imageURL: mockProfileURL(imageIndex: show.id * 9 + idx + 1)
                )
            }

            let extras = [
                "Naomi Hart",
                "Elliot Cruz",
                "Sasha Park",
                "Milo Bennett",
                "Talia Brooks",
                "Reed Sullivan"
            ]
            .enumerated()
            .map { idx, name in
                CastMember(
                    name: name,
                    characterName: genericMockRole(for: idx + featured.count),
                    imageURL: mockProfileURL(imageIndex: show.id * 9 + featured.count + idx + 1)
                )
            }

            return Array((featured + extras).prefix(max(8, featured.count)))
        }
    }

    private func genericMockRole(for index: Int) -> String {
        let roles = [
            "Lead",
            "Co-Lead",
            "Rival",
            "Best Friend",
            "Mentor",
            "Wildcard",
            "Commander",
            "Neighbor",
            "Detective",
            "Guest Star"
        ]
        return roles[index % roles.count]
    }

    private func mockProfileURL(imageIndex: Int) -> String {
        let normalizedIndex = ((imageIndex - 1) % 70) + 1
        return "https://i.pravatar.cc/160?img=\(normalizedIndex)"
    }

    private func markNextEpisodeWatched() {
        guard !primaryButtonDisabled else { return }

        if !isInRotation {
            appState.addShowToRotation(show)
        }

        // Detect if marking this episode will finish the season
        let willFinishSeason: Int? = {
            guard let ms = appState.myShow(for: show.id) else { return nil }
            let afterEp = min(ms.totalEpisodes, ms.currentEpisode + 1)
            return afterEp >= ms.totalEpisodes ? ms.currentSeason : nil
        }()

        if let myShow = appState.myShow(for: show.id) {
            appState.logEpisode(myShowId: myShow.id)
        }

        markedWatched = true
        StelrHaptics.success()

        // Prompt for season rating if season just finished and not yet rated
        if let season = willFinishSeason,
           appState.mySeasonRating(showId: show.id, season: season) == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                seasonRatingTarget = season
                showSeasonRatingSheet = true
            }
        }
    }

    private func runDataTabContentEntrance() {
        dataTabContentAppeared = false
        if reduceMotion {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                dataTabContentAppeared = true
            }
        } else {
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
                    dataTabContentAppeared = true
                }
            }
        }
    }

    private func closeNormally() {
        StelrHaptics.lightTap()
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}

// MARK: - VibesTabView
private struct VibesTabView: View {
    let show: Show
    let selectedSeason: Int
    let seasonCount: Int
    let canRateSeason: Bool
    let onRateSeason: (Int) -> Void

    @EnvironmentObject var appState: AppState

    private var allRatings: [UserSeasonRating] {
        appState.seasonRatingsFor(showId: show.id, season: selectedSeason)
    }

    private var myScore: Double? {
        appState.mySeasonRating(showId: show.id, season: selectedSeason)?.score
    }

    private var totalRatings: Int { allRatings.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Season header ───────────────────────────────────────────────
            HStack(alignment: .firstTextBaseline) {
                Text("Season \(selectedSeason) Vibes")
                    .font(StelrTypography.sectionTitle)
                    .foregroundStyle(.primary)
                Spacer()
                if totalRatings > 0 {
                    Text("\(totalRatings) rating\(totalRatings == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)

            // ── Letterboxd-style column chart ───────────────────────────
            VibesColumnChart(ratings: allRatings, myScore: myScore)
                .padding(.horizontal, 18)
                .padding(.bottom, 20)

            if canRateSeason {
                // ── Rate this season nudge ──────────────────────────────────
                Button {
                    StelrHaptics.lightTap()
                    onRateSeason(selectedSeason)
                } label: {
                    SeasonRateCTA(
                        season: selectedSeason,
                        score: myScore,
                        accentHex: show.accentColor
                    )
                }
                .buttonStyle(.stelrPress)
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }

            // ── Friend activity feed ────────────────────────────────────
            if !allRatings.isEmpty {
                Text("Friend Ratings")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 10)

                VStack(spacing: 0) {
                    ForEach(allRatings) { entry in
                        SeasonRatingRow(entry: entry)
                        if entry.id != allRatings.last?.id {
                            Divider().padding(.leading, 56).opacity(0.15)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.7)
                        )
                )
                .padding(.horizontal, 18)
            }
        }
        .padding(.top, 4)
    }
}

private struct SeasonRateCTA: View {
    let season: Int
    let score: Double?
    let accentHex: String

    private var accent: Color {
        Color(hex: accentHex)
    }

    private var formattedScore: String {
        guard let score else { return "" }
        return score.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", score)
            : String(format: "%.1f", score)
    }

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.13))
                Circle()
                    .strokeBorder(accent.opacity(0.22), lineWidth: 0.7)
                Image(systemName: score == nil ? "sparkle" : "pencil")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(score == nil ? "Rate season \(season)" : "Update season \(season)")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(score == nil ? "Add a quick 1-5 star vibe" : "Your season vibe is saved")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if score != nil {
                Text("\(formattedScore) ★")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(accent)
                    .monospacedDigit()
                    .padding(.horizontal, 9)
                    .frame(height: 27)
                    .background(accent.opacity(0.11), in: Capsule(style: .continuous))
                    .overlay(Capsule(style: .continuous).strokeBorder(accent.opacity(0.20), lineWidth: 0.7))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.48))
                .frame(width: 24, height: 24)
                .background(Color.white.opacity(0.055), in: Circle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(accent.opacity(score == nil ? 0.055 : 0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            accent.opacity(score == nil ? 0.24 : 0.16),
                            Color.white.opacity(0.075)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: accent.opacity(score == nil ? 0.08 : 0.04), radius: 12, y: 6)
    }
}

// MARK: - VibesColumnChart (Letterboxd-style)

private struct VibesColumnChart: View {
    let ratings: [UserSeasonRating]
    let myScore: Double?

    private let steps = CheckInStep.all   // 9 values: 1.0 … 5.0

    private var counts: [Double: Int] {
        Dictionary(grouping: ratings, by: { CheckInStep.from($0.score).score })
            .mapValues(\.count)
    }

    private var maxCount: Int { counts.values.max() ?? 1 }

    var body: some View {
        VStack(spacing: 6) {
            // ── Bars ────────────────────────────────────────────────────────
            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: columnGap(width: geo.size.width)) {
                    ForEach(steps, id: \.score) { step in
                        let count = counts[step.score] ?? 0
                        let fraction = count == 0 ? 0.0 : CGFloat(count) / CGFloat(max(1, maxCount))
                        let isOwn = myScore.map { abs($0 - step.score) < 0.01 } ?? false
                        let barColor = Color(hex: step.coreHex)

                        VStack(spacing: 0) {
                            Spacer(minLength: 0)

                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            barColor.opacity(isOwn ? 1.0 : 0.65),
                                            barColor.opacity(isOwn ? 0.7 : 0.35)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: max(2, fraction * geo.size.height))
                                .overlay(
                                    isOwn
                                        ? RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .strokeBorder(barColor, lineWidth: 1)
                                        : nil
                                )
                                .shadow(
                                    color: isOwn ? barColor.opacity(0.55) : .clear,
                                    radius: 6, y: 2
                                )
                                .animation(
                                    .spring(response: 0.44, dampingFraction: 0.80)
                                        .delay(Double(steps.firstIndex(where: { $0.score == step.score }) ?? 0) * 0.03),
                                    value: fraction
                                )
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 56)

            // ── X-axis labels ────────────────────────────────────────────────
            HStack(spacing: 0) {
                ForEach(steps, id: \.score) { step in
                    let isOwn = myScore.map { abs($0 - step.score) < 0.01 } ?? false
                    Group {
                        if step.score.truncatingRemainder(dividingBy: 1.0) == 0 {
                            // Whole numbers get a star label
                            Text("\(Int(step.score))★")
                                .font(.system(size: 9.5, weight: isOwn ? .bold : .regular, design: .rounded))
                                .foregroundStyle(isOwn ? Color(hex: step.coreHex) : Color.secondary.opacity(0.7))
                        } else {
                            // Half steps get a dot
                            Circle()
                                .fill(isOwn ? Color(hex: step.coreHex) : Color.secondary.opacity(0.3))
                                .frame(width: 3, height: 3)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func columnGap(width: CGFloat) -> CGFloat {
        // 9 columns; keep a small readable gap
        max(2, width * 0.015)
    }
}

// MARK: - SeasonRatingRow
private struct SeasonRatingRow: View {
    let entry: UserSeasonRating

    private var step: CheckInStep { CheckInStep.from(entry.score) }

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(
                initials: entry.authorInitials,
                hexColor: entry.authorHexColor,
                size: 36
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.isOwn ? "You" : entry.authorName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(entry.timeAgo)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Score pill with half-star precision
            HStack(spacing: 4) {
                Text(entry.score.truncatingRemainder(dividingBy: 1) == 0
                     ? String(format: "%.0f", entry.score)
                     : String(format: "%.1f", entry.score))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Image(systemName: "star.fill")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundStyle(Color(hex: step.coreHex))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(hex: step.coreHex).opacity(0.14))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color(hex: step.coreHex).opacity(0.28), lineWidth: 0.7)
                    )
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: - SeasonRatingSheet
// MARK: - SeasonRatingSheet
/// Uses the same CheckInRatingSlider as vibe check-ins for a consistent UX.
private struct SeasonRatingSheet: View {
    let show: Show
    let season: Int
    let existingScore: Double?
    let onSubmit: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedScore: Double? = 3.0
    @State private var previewScore: Double = 3.0
    @State private var appeared = false

    private var step: CheckInStep { CheckInStep.from(selectedScore ?? previewScore) }
    private var ratingColor: Color { Color(hex: step.coreHex) }

    var body: some View {
        ZStack {
            Color.stelrBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.20))
                    .frame(width: 36, height: 4)
                    .padding(.top, 10)
                    .padding(.bottom, 22)

                // ── Header ───────────────────────────────────────────────────
                VStack(spacing: 6) {
                    Text("Season \(season) complete 🎬")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.stelrMuted)
                    Text("how was it?")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.stelrText)
                    Text(show.title)
                        .font(.system(size: 13.4, weight: .medium))
                        .foregroundColor(.stelrMuted.opacity(0.72))
                        .lineLimit(1)
                }
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)

                // Fixed-height star area keeps the slider from moving as the visual changes.
                ZStack {
                    VibeWaveView(vibe: step.vibe, score: step.score, size: 64, animate: true)
                        .frame(width: 132, height: 132)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .padding(.bottom, 18)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.46, dampingFraction: 0.84).delay(0.06), value: appeared)

                // ── Slider (same component as vibe check-in) ─────────────────
                CheckInRatingSlider(selectedScore: $selectedScore, previewScore: $previewScore, stableTicks: true)
                    .padding(.horizontal, 20)
                    .frame(height: 88)
                    .padding(.bottom, 32)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.46, dampingFraction: 0.84).delay(0.10), value: appeared)

                Spacer(minLength: 16)

                // ── Save button ──────────────────────────────────────────────
                Button {
                    let score = selectedScore ?? previewScore
                    StelrHaptics.success()
                    onSubmit(score)
                    dismiss()
                } label: {
                    Text("Save")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "1a0e02"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(ratingColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: ratingColor.opacity(0.25), radius: 12, y: 6)
                }
                .buttonStyle(.stelrPress)
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .animation(.easeInOut(duration: 0.18), value: selectedScore)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
        .onAppear {
            if let existing = existingScore {
                let snapped = CheckInStep.from(existing).score
                previewScore = snapped
                selectedScore = snapped
            }
            DispatchQueue.main.async { appeared = true }
        }
    }
}

private struct DetailMockHeroSection: View {
    let show: Show
    let episodeCount: Int
    let communityScore: Double?
    let communityCount: Int
    let globalRating: Double?

    private var seasonText: String? {
        guard let seasons = show.seasons, seasons > 0 else { return nil }
        return seasons == 1 ? "1 season" : "\(seasons) seasons"
    }

    private var rawGlobalRating: Double {
        if let globalRating { return globalRating }
        let mockRatings = [8.7, 8.4, 7.9, 8.2, 8.5, 8.9, 7.8, 8.1]
        return mockRatings[abs(show.id) % mockRatings.count]
    }

    private var displayGlobalRating: Double {
        min(5, max(0, rawGlobalRating / 2.0))
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            DetailHeroBackgroundArt(show: show)

            VStack(alignment: .leading, spacing: 8) {
                Text(show.title)
                    .font(.system(size: 24, weight: .semibold, design: .default))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.74)
                    .shadow(color: .black.opacity(0.45), radius: 10, y: 4)

                Text(detailMetaLine)
                    .font(StelrTypography.metadata)
                    .foregroundStyle(Color.white.opacity(0.82))
                    .lineLimit(2)

                if !seasonEpisodeMetaLine.isEmpty {
                    Text(seasonEpisodeMetaLine)
                        .font(StelrTypography.metadata)
                        .foregroundStyle(Color.white.opacity(0.64))
                        .lineLimit(1)
                }

                HStack(alignment: .top, spacing: 18) {
                    DetailInlineRating(
                        label: "Friends",
                        value: communityScore.map { String(format: "%.1f", $0) } ?? "--",
                        starScore: communityScore
                    )

                    DetailInlineRating(
                        label: "Global",
                        value: String(format: "%.1f", displayGlobalRating),
                        starScore: displayGlobalRating
                    )
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 354)
        .clipped()
    }

    private var detailMetaLine: String {
        var parts: [String] = []
        if let year = show.year {
            parts.append("\(year)")
        }
        if let genre = show.genre, !genre.isEmpty {
            parts.append(genre)
        }
        if let platformText {
            parts.append(platformText)
        }
        return parts.joined(separator: "  ·  ")
    }

    private var seasonEpisodeMetaLine: String {
        var parts: [String] = []
        if let seasonText {
            parts.append(seasonText)
        }
        if episodeCount > 0 {
            parts.append(episodeCount == 1 ? "1 episode" : "\(episodeCount) episodes")
        }
        return parts.joined(separator: " · ")
    }

    private var platformText: String? {
        if let platforms = show.platforms, let first = platforms.first, !first.isEmpty {
            return first
        }
        return show.platform.isEmpty ? nil : show.platform
    }
}

private struct DetailInlineRating: View {
    let label: String
    let value: String
    let starScore: Double?

    private var displayScore: Double {
        starScore ?? 2.5
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                StarGlowView(score: displayScore, maxCoreSize: 20, animate: starScore != nil)
                    .frame(width: 24, height: 24)
                    .opacity(starScore == nil ? 0.34 : 1)

                Text(value)
                    .font(StelrTypography.bodyStrong)
                    .foregroundStyle(starScore == nil ? Color.white.opacity(0.44) : .white)
                    .monospacedDigit()
            }

            Text(label)
                .font(StelrTypography.metadata)
                .foregroundStyle(Color.white.opacity(0.62))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) rating \(value)")
    }
}

private struct DetailHeroActionCluster: View {
    let showsBookmark: Bool
    let isWatchlisted: Bool
    let onToggleBookmark: () -> Void
    let onCheckIn: () -> Void
    let onSendProbe: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button {
                onCheckIn()
            } label: {
                Label {
                    Text("Check in")
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                } icon: {
                    Image(systemName: "sparkle")
                }
                .font(StelrTypography.button)
                .foregroundStyle(.white)
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 13)
                .frame(minWidth: 100, minHeight: 34)
                .background(Color.stelrAccent, in: Capsule(style: .continuous))
                .shadow(color: Color.stelrAccent.opacity(0.22), radius: 10, y: 5)
            }
            .buttonStyle(.stelrPress)
            .layoutPriority(1)

            if showsBookmark {
                Button {
                    onToggleBookmark()
                } label: {
                    Image(systemName: isWatchlisted ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isWatchlisted ? Color(hex: "73D27D") : Color.white.opacity(0.84))
                        .frame(width: 32, height: 32)
                        .background(Color.black.opacity(0.16), in: Circle())
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.07), lineWidth: 0.7))
                }
                .buttonStyle(.stelrPress)
                .accessibilityLabel(isWatchlisted ? "Remove bookmark" : "Bookmark show")
            }

            Button {
                onSendProbe()
            } label: {
                SputnikProbeIcon()
                    .frame(width: 13.5, height: 13.5)
                    .foregroundStyle(Color.white.opacity(0.86))
                    .frame(width: 32, height: 32)
                    .background(Color.black.opacity(0.16), in: Circle())
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.07), lineWidth: 0.7))
            }
            .buttonStyle(.stelrPress)
            .accessibilityLabel("Send probe")
        }
    }
}

private struct DetailHeroBackgroundArt: View {
    let show: Show

    private var heroImageURL: String? {
        show.previewImageURL ?? show.imageURL
    }

    var body: some View {
        ZStack {
            if let imageURL = heroImageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                    case .failure:
                        fallbackBackground
                    default:
                        fallbackBackground
                            .overlay(
                                Rectangle()
                                    .fill(Color.white.opacity(0.05))
                                    .blur(radius: 20)
                            )
                    }
                }
            } else {
                fallbackBackground
            }

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.18),
                            Color.black.opacity(0.22),
                            Color.black.opacity(0.66)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.68),
                            Color.black.opacity(0.30),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [
                    .clear,
                    Color.black.opacity(0.34),
                    Color.stelrBg.opacity(0.88),
                    Color.stelrBg
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 184)
        }
        .clipped()
    }

    private var fallbackBackground: some View {
        LinearGradient(
            colors: [
                Color(hex: show.gradient1),
                Color(hex: show.gradient2),
                Color.black.opacity(0.82)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            StelrStarFieldBackground(includesRadialBloom: false, starCount: 22)
                .opacity(0.26)
        )
    }
}

private struct DetailRatingCenterStrip: View {
    let communityScore: Double?
    let communityCount: Int
    let globalRating: Double?

    var body: some View {
        HStack(spacing: 12) {
            DetailRatingStarCard(
                title: "Friends",
                score: communityScore,
                scoreText: communityScore.map { String(format: "%.1f", $0) } ?? "--",
                scaleText: "/5",
                subtitle: communitySubtitle
            )

            DetailRatingStarCard(
                title: "Global",
                score: globalAppScore,
                scoreText: globalAppScore.map { String(format: "%.1f", $0) } ?? "--",
                scaleText: "/5",
                subtitle: globalRating == nil ? "global not rated" : "global rating"
            )
        }
        .frame(maxWidth: .infinity)
    }

    private var communitySubtitle: String {
        if communityCount <= 0 { return "community not rated" }
        return communityCount == 1 ? "1 friend rating" : "\(communityCount) friend ratings"
    }

    private var globalAppScore: Double? {
        guard let globalRating else { return nil }
        return min(5, max(1, globalRating / 2.0))
    }
}

private struct DetailRatingStarCard: View {
    let title: String
    let score: Double?
    let scoreText: String
    let scaleText: String
    let subtitle: String

    private var displayScore: Double {
        score ?? 2.5
    }

    private var tint: Color {
        score.map { H7bStarVisualStyle(appScore: $0).color } ?? .stelrMuted
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(title.uppercased())
                .font(StelrTypography.microLabel)
                .tracking(1.4)
                .foregroundStyle(.tertiary)

            ZStack {
                StarGlowView(score: displayScore, maxCoreSize: 48, animate: score != nil)
                    .opacity(score == nil ? 0.34 : 1)
                    .frame(width: 58, height: 58)

                VStack(spacing: -1) {
                    Text(scoreText)
                        .font(StelrTypography.sectionTitle)
                        .foregroundStyle(score == nil ? .secondary : .primary)
                    Text(scaleText)
                        .font(StelrTypography.metadata)
                        .foregroundStyle(.tertiary)
                }
            }

            Text(subtitle)
                .font(StelrTypography.metadata)
                .foregroundStyle(score == nil ? .secondary : .secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 13)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.075), lineWidth: 0.7)
        )
        .shadow(color: .black.opacity(0.22), radius: 15, y: 9)
    }
}

private struct DetailPlatformPills: View {
    let show: Show

    private var options: [StreamingPlatformOption] {
        let primaryLabels = (show.platforms ?? [show.platform])
            .map(trimmedLabel)
            .filter { !$0.isEmpty }

        var values: [StreamingPlatformOption] = primaryLabels.map {
            StreamingPlatformOption(label: $0, isPrimary: true)
        }

        values.append(contentsOf: supplementalStreamingSites.map {
            StreamingPlatformOption(label: $0, isPrimary: false)
        })

        var seen = Set<String>()
        return values.filter { option in
            let key = option.label.lowercased()
            guard !option.label.isEmpty, !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    private var supplementalStreamingSites: [String] {
        ["HBO", "Hulu", "Netflix", "Prime Video", "Max", "Disney+"]
    }

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                StreamingPlatformRow(option: option, accentHex: show.accentColor)

                if index < options.count - 1 {
                    Divider()
                        .background(Color.white.opacity(0.06))
                        .padding(.leading, 58)
                }
            }
        }
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 0.7)
        )
    }

    private func trimmedLabel(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct StreamingPlatformOption: Identifiable {
    let label: String
    let isPrimary: Bool

    var id: String { label }
}

private struct StreamingPlatformRow: View {
    let option: StreamingPlatformOption
    let accentHex: String

    private var iconName: String {
        switch option.label.lowercased() {
        case let value where value.contains("apple"):
            return "apple.logo"
        case let value where value.contains("disney"):
            return "sparkles"
        case let value where value.contains("prime"):
            return "shippingbox.fill"
        default:
            return "play.rectangle.fill"
        }
    }

    private var subtitle: String {
        option.isPrimary ? "Streaming now" : "Browse availability"
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: accentHex).opacity(option.isPrimary ? 0.26 : 0.12),
                                Color.white.opacity(option.isPrimary ? 0.10 : 0.055)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(option.isPrimary ? Color(hex: accentHex) : Color.secondary)
            }
            .frame(width: 38, height: 38)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.7)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(option.label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            if option.isPrimary {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: accentHex))
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DetailWatchingFriendsRow: View {
    let friends: [Friend]
    var onFriendTap: (Friend) -> Void

    var body: some View {
        if friends.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "person.2")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)

                Text("No friends watching this one yet")
                    .font(StelrTypography.metadata)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.7)
            )
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 11) {
                    ForEach(friends) { friend in
                        WatchingFriendBubble(friend: friend) {
                            onFriendTap(friend)
                        }
                    }
                }
                .padding(.vertical, 1)
                .padding(.trailing, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
        }
    }
}

private struct WatchingFriendBubble: View {
    let friend: Friend
    var onTap: () -> Void

    var body: some View {
        Button {
            StelrHaptics.lightTap()
            onTap()
        } label: {
            VStack(spacing: 5) {
                AvatarView(initials: friend.initials, hexColor: friend.hexColor, imageURL: friend.imageURL, size: 32, showBorder: true)
                    .shadow(color: .black.opacity(0.20), radius: 6, y: 3)

                VStack(spacing: 2) {
                    Text(friend.name.split(separator: " ").first.map(String.init) ?? friend.name)
                        .font(.caption2)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("@\(friend.username)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 54)
        }
        .buttonStyle(.plain)
    }
}

private struct SpaceRaceView: View {
    let entries: [EpisodeRaceEntry]
    let currentSeason: Int
    let currentEpisode: Int
    let totalEpisodes: Int
    let episodeCountsBySeason: [Int: Int]?
    let seasonCount: Int
    let accentHex: String
    let onFriendTap: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selectedSeason: Int
    @State private var selectedParticipantID: String?

    private let rowHeight: CGFloat = 42
    private let avatarColumnWidth: CGFloat = 36
    private let planetColumnWidth: CGFloat = 36
    private let maxRaceViewportHeight: CGFloat = 244

    init(
        entries: [EpisodeRaceEntry],
        currentSeason: Int,
        currentEpisode: Int,
        totalEpisodes: Int,
        episodeCountsBySeason: [Int: Int]? = nil,
        seasonCount: Int,
        selectedSeason: Binding<Int>,
        accentHex: String,
        onFriendTap: @escaping (Int) -> Void = { _ in }
    ) {
        self.entries = entries
        self.currentSeason = currentSeason
        self.currentEpisode = currentEpisode
        self.totalEpisodes = max(1, totalEpisodes)
        self.episodeCountsBySeason = episodeCountsBySeason
        self.seasonCount = max(1, seasonCount)
        self._selectedSeason = selectedSeason
        self.accentHex = accentHex
        self.onFriendTap = onFriendTap
        _selectedParticipantID = State(initialValue: nil)
    }

    private var visibleParticipants: [RaceProgressParticipant] {
        let participants = entries.compactMap { participant(from: $0) }
        guard let currentUser = participants.first(where: \.isCurrentUser) else {
            return participants
        }

        return [currentUser] + participants.filter { !$0.isCurrentUser }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Space Race")
                        .font(StelrTypography.sectionTitle)
                        .foregroundStyle(.primary)

                    Text("Be the first to finish the season!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    SpaceRaceParticles()
                        .opacity(0.35)
                        .allowsHitTesting(false)

                    ScrollView(.vertical, showsIndicators: shouldScrollParticipants) {
                        VStack(spacing: 6) {
                            ForEach(visibleParticipants) { participant in
                                SpaceRaceRow(
                                    participant: participant,
                                    isSelected: selectedParticipantID == participant.id,
                                    isDimmed: selectedParticipantID != nil && selectedParticipantID != participant.id,
                                    totalEpisodes: activeTotalEpisodes,
                                    avatarColumnWidth: avatarColumnWidth,
                                    accentHex: accentHex,
                                    onAvatarTap: participant.friendID.map { friendID in
                                        { onFriendTap(friendID) }
                                    }
                                ) {
                                    withAnimation(.easeInOut(duration: reduceMotion ? 0.12 : 0.22)) {
                                        selectedParticipantID = selectedParticipantID == participant.id ? nil : participant.id
                                    }
                                }
                            }
                        }
                        .padding(.vertical, shouldScrollParticipants ? 2 : 0)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            .frame(height: raceViewportHeight)

            RaceEpisodeMarkers(
                totalEpisodes: activeTotalEpisodes,
                leftColumnWidth: avatarColumnWidth,
                planetColumnWidth: planetColumnWidth
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(Color(hex: "030810").opacity(0.30), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.075), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 10)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: selectedSeason) { _, _ in
            selectedParticipantID = nil
        }
        .animation(.easeInOut(duration: reduceMotion ? 0.12 : 0.22), value: visibleParticipants.map(\.id))
    }

    private var activeTotalEpisodes: Int {
        max(1, episodeCountsBySeason?[selectedSeason] ?? totalEpisodes)
    }

    private var rowStackHeight: CGFloat {
        let participants = visibleParticipants
        let rowsHeight = participants.reduce(CGFloat.zero) { partial, participant in
            partial + rowHeight(for: participant)
        }
        return rowsHeight + CGFloat(max(0, participants.count - 1)) * 5
    }

    private var raceViewportHeight: CGFloat {
        min(rowStackHeight, maxRaceViewportHeight)
    }

    private var shouldScrollParticipants: Bool {
        rowStackHeight > maxRaceViewportHeight + 1
    }

    private func rowHeight(for participant: RaceProgressParticipant) -> CGFloat {
        selectedParticipantID == participant.id ? 96 : rowHeight
    }

    private func participant(from entry: EpisodeRaceEntry) -> RaceProgressParticipant? {
        guard let episode = episodeProgress(for: entry) else { return nil }
        return RaceProgressParticipant(
            id: entry.id,
            name: entry.isYou ? "You" : entry.name,
            initials: entry.initials,
            colorHex: entry.colorHex,
            season: selectedSeason,
            episode: episode,
            totalEpisodes: activeTotalEpisodes,
            isCurrentUser: entry.isYou,
            deltaFromCurrentUser: deltaFromCurrentUser(for: episode),
            lastCheckIn: entry.lastCheckIn,
            friendID: entry.friendID,
            imageURL: entry.imageURL
        )
    }

    private func episodeProgress(for entry: EpisodeRaceEntry) -> Int? {
        let seasonTotal = activeTotalEpisodes

        if selectedSeason == currentSeason {
            return min(seasonTotal, max(1, entry.isYou ? currentEpisode : entry.episode))
        }

        if selectedSeason < currentSeason {
            let lag = entry.isYou ? 0 : (stableValue(for: entry.id) % 3)
            return max(1, seasonTotal - lag)
        }

        if selectedSeason == currentSeason + 1 {
            guard entry.isYou || stableValue(for: entry.id) % 3 != 0 else { return nil }
            return entry.isYou ? 1 : min(seasonTotal, 1 + stableValue(for: entry.id) % min(3, seasonTotal))
        }

        return nil
    }

    private func deltaFromCurrentUser(for episode: Int) -> Int {
        guard let currentUserEpisode = entries.first(where: \.isYou).flatMap({ episodeProgress(for: $0) }) else {
            return 0
        }
        return episode - currentUserEpisode
    }

    private func stableValue(for id: String) -> Int {
        id.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
    }
}

private struct SeasonSwitcher: View {
    @Binding var selectedSeason: Int
    let seasonCount: Int

    var body: some View {
        Menu {
            ForEach(1...seasonCount, id: \.self) { season in
                Button {
                    guard selectedSeason != season else { return }
                    StelrHaptics.selection()
                    selectedSeason = season
                } label: {
                    if selectedSeason == season {
                        Label("Season \(season)", systemImage: "checkmark")
                    } else {
                        Text("Season \(season)")
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text("Season \(selectedSeason)")
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule(style: .continuous))
            .background(Color.white.opacity(0.045), in: Capsule(style: .continuous))
            .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.075), lineWidth: 0.7))
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}

private struct DetailDataTabBar: View {
    @Binding var selectedTab: ShowDetailDataTab
    @Namespace private var tabNamespace

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ShowDetailDataTab.allCases) { tab in
                    Button {
                        if selectedTab != tab {
                            StelrHaptics.selection()
                        }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                            selectedTab = tab
                        }
                    } label: {
                        Text(tab.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(selectedTab == tab ? Color.primary : Color.secondary)
                            .padding(.horizontal, 18)
                            .frame(height: 38)
                            .background {
                                if selectedTab == tab {
                                    Capsule(style: .continuous)
                                        .fill(Color.white.opacity(0.13))
                                        .matchedGeometryEffect(id: "tabSelection", in: tabNamespace)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.07))
            )
            .padding(.horizontal, 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }
}

private struct RaceEpisodeMarkers: View {
    let totalEpisodes: Int
    let leftColumnWidth: CGFloat
    let planetColumnWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: leftColumnWidth + 20)

            GeometryReader { geo in
                let trackWidth = max(1, geo.size.width)
                let episodes = markerEpisodes(for: trackWidth)

                ZStack(alignment: .topLeading) {
                    Capsule()
                        .fill(Color.white.opacity(0.055))
                        .frame(width: trackWidth, height: 1)
                        .position(x: trackWidth / 2, y: 4)

                    ForEach(episodes, id: \.self) { episode in
                        let markerProgress = totalEpisodes <= 1
                            ? CGFloat(0)
                            : CGFloat(episode - 1) / CGFloat(max(1, totalEpisodes - 1))
                        let markerX = trackWidth * markerProgress

                        Capsule()
                            .fill(Color.white.opacity(episode == 1 || episode == totalEpisodes ? 0.18 : 0.10))
                            .frame(width: 1, height: episode == 1 || episode == totalEpisodes ? 6 : 4)
                            .position(x: markerX, y: 4)

                        Text("E\(episode)")
                            .font(.caption2)
                            .foregroundStyle(episode == 1 || episode == totalEpisodes ? .secondary : .tertiary)
                            .lineLimit(1)
                            .frame(width: 42, alignment: labelAlignment(for: episode))
                            .position(x: labelCenter(for: markerX, trackWidth: trackWidth, episode: episode), y: 17)
                    }
                }
            }
            .frame(height: 26)

            Color.clear
                .frame(width: planetColumnWidth)
        }
        .frame(height: 26)
    }

    private func markerEpisodes(for trackWidth: CGFloat) -> [Int] {
        guard totalEpisodes > 1 else { return [1] }

        let maxLabelCount = max(2, min(totalEpisodes, Int(trackWidth / 42)))
        if totalEpisodes <= maxLabelCount {
            return Array(1...totalEpisodes)
        }

        let interval = max(1, Int(ceil(Double(totalEpisodes - 1) / Double(max(1, maxLabelCount - 1)))))
        var episodes: [Int] = [1]
        var next = 1 + interval
        while next < totalEpisodes {
            episodes.append(next)
            next += interval
        }

        if let last = episodes.last,
           totalEpisodes - last <= max(1, interval / 2),
           episodes.count > 1 {
            episodes.removeLast()
        }
        episodes.append(totalEpisodes)
        return episodes
    }

    private func labelAlignment(for episode: Int) -> Alignment {
        if episode == 1 { return .leading }
        if episode == totalEpisodes { return .trailing }
        return .center
    }

    private func labelCenter(for markerX: CGFloat, trackWidth: CGFloat, episode: Int) -> CGFloat {
        if episode == 1 { return 21 }
        if episode == totalEpisodes { return max(21, trackWidth - 21) }
        return min(max(21, markerX), max(21, trackWidth - 21))
    }
}

private struct SpaceRaceRow: View {
    let participant: RaceProgressParticipant
    let isSelected: Bool
    let isDimmed: Bool
    let totalEpisodes: Int
    let avatarColumnWidth: CGFloat
    let accentHex: String
    let onAvatarTap: (() -> Void)?
    let onTap: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            HStack(alignment: .center, spacing: 8) {
                avatarControl
                    .frame(width: avatarColumnWidth, alignment: .leading)

                GeometryReader { geo in
                    RaceTrailIndicator(
                        participant: participant,
                        progress: participant.progress,
                        isCurrentUser: participant.isCurrentUser,
                        isSelected: isSelected,
                        accentHex: accentHex
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .frame(height: isSelected ? 56 : 28)
            }
            .padding(.top, isSelected ? 6 : 0)
            .padding(.bottom, isSelected ? 24 : 0)

            if isSelected {
                Text(participant.lastCheckInDisplay)
                    .font(.caption2)
                    .foregroundStyle(participant.isCurrentUser ? Color.stelrAccent.opacity(0.86) : Color.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 8)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: isSelected ? 96 : 42)
        .background(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.045))
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(isSelected ? 0.08 : 0), lineWidth: 0.7)
        )
        .opacity(isDimmed ? 0.45 : 1)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityLabel("\(participant.name), season \(participant.season), episode \(participant.episode), \(participant.lastCheckInDisplay)")
    }

    @ViewBuilder
    private var avatarControl: some View {
        if let onAvatarTap, !participant.isCurrentUser {
            Button {
                StelrHaptics.lightTap()
                onAvatarTap()
            } label: {
                SpaceRaceAvatar(participant: participant)
            }
            .buttonStyle(.plain)
        } else {
            SpaceRaceAvatar(participant: participant)
        }
    }
}

private struct RaceTrailIndicator: View {
    let participant: RaceProgressParticipant
    let progress: Double
    let isCurrentUser: Bool
    let isSelected: Bool
    let accentHex: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    private var pointColor: Color {
        isCurrentUser ? Color.stelrAccent : Color.white.opacity(0.86)
    }

    var body: some View {
        GeometryReader { geo in
            let pointX = max(8, min(geo.size.width - 10, geo.size.width * CGFloat(progress)))
            let laneY = isSelected ? geo.size.height * 0.64 : geo.size.height / 2
            let spaceshipX = min(geo.size.width - 8, pointX + 7)
            let tooltipWidth: CGFloat = participant.deltaFromCurrentUser == 0 ? 104 : 132
            let tooltipX = min(max(tooltipWidth / 2, spaceshipX), max(tooltipWidth / 2, geo.size.width - tooltipWidth / 2))
            let trailWidth = isSelected ? 58.0 : 34.0
            let planetSize: CGFloat = isSelected ? 17 : 10
            let planetX = geo.size.width - planetSize / 2 - 2

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(isSelected ? 0.040 : 0.026))
                    .frame(width: max(1, planetX), height: 1)
                    .position(x: planetX / 2, y: laneY)

                SpaceRaceDestinationPlanet(accentHex: accentHex, isSelected: isSelected)
                    .frame(width: planetSize, height: planetSize)
                    .position(x: planetX, y: laneY)
                    .allowsHitTesting(false)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                (isCurrentUser ? Color.stelrAccent : Color.white).opacity(isSelected ? 0.28 : 0.14),
                                pointColor.opacity(isSelected ? 0.62 : 0.42)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: trailWidth, height: isSelected ? 3 : 2)
                    .blur(radius: isSelected ? 1.4 : 1.0)
                    .position(x: pointX - CGFloat(trailWidth) / 2 + 3, y: laneY)
                    .offset(x: reduceMotion ? 0 : (drift ? 1.2 : -0.5))

                if isSelected {
                    RaceSpaceshipTooltip(participant: participant)
                        .frame(width: tooltipWidth)
                        .position(x: tooltipX, y: max(12, laneY - 37))
                        .transition(.opacity.combined(with: .scale(scale: 0.94)))

                    RaceSpaceshipSprite(isCurrentUser: isCurrentUser)
                        .frame(width: 31, height: 16)
                        .position(x: spaceshipX, y: laneY)
                        .transition(.opacity.combined(with: .scale(scale: 0.86)))
                } else {
                    Circle()
                        .fill(pointColor)
                        .frame(width: isCurrentUser ? 6 : 5, height: isCurrentUser ? 6 : 5)
                    .shadow(color: pointColor.opacity(isCurrentUser ? 0.40 : 0.18), radius: isCurrentUser ? 6 : 4)
                    .position(x: pointX, y: laneY)
                }
            }
            .animation(.easeInOut(duration: reduceMotion ? 0.12 : 0.22), value: isSelected)
            .animation(.easeInOut(duration: reduceMotion ? 0.12 : 0.24), value: progress)
            .onAppear { drift = true }
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                value: drift
            )
        }
    }
}

private struct RaceSpaceshipTooltip: View {
    let participant: RaceProgressParticipant

    private var deltaText: String? {
        guard participant.deltaFromCurrentUser != 0 else { return nil }
        return participant.deltaFromCurrentUser > 0
            ? "+\(participant.deltaFromCurrentUser)"
            : "\(participant.deltaFromCurrentUser)"
    }

    var body: some View {
        HStack(spacing: 5) {
            Text(participant.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text("S\(participant.season) · E\(participant.episode)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let deltaText {
                Text(deltaText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(participant.isCurrentUser ? Color.stelrAccent : Color.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Color.white.opacity(0.060), in: Capsule(style: .continuous))
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .background(Color.white.opacity(0.045), in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.075), lineWidth: 0.7)
        )
        .shadow(color: .black.opacity(0.22), radius: 8, y: 4)
    }
}

private struct RaceSpaceshipSprite: View {
    let isCurrentUser: Bool

    var body: some View {
        Canvas { context, size in
            let w = size.width * 0.86
            let h = size.height * 0.56
            let cx = size.width * 0.58
            let cy = size.height * 0.50
            let tailX = cx - w * 0.46
            let bodyX1 = tailX + w * 0.12
            let bodyX2 = cx + w * 0.18
            let noseX = cx + w * 0.48

            let flameEnd = tailX - w * 0.30
            context.fill(
                Path(ellipseIn: CGRect(x: flameEnd, y: cy - h * 0.10, width: tailX - flameEnd, height: h * 0.20)),
                with: .linearGradient(
                    Gradient(colors: [
                        .clear,
                        Color.stelrAccent.opacity(isCurrentUser ? 0.42 : 0.18)
                    ]),
                    startPoint: CGPoint(x: flameEnd, y: cy),
                    endPoint: CGPoint(x: tailX, y: cy)
                )
            )

            let finColor = isCurrentUser ? Color.stelrAccent.opacity(0.38) : Color.white.opacity(0.38)
            var topFin = Path()
            topFin.move(to: CGPoint(x: tailX + w * 0.08, y: cy - h * 0.48))
            topFin.addLine(to: CGPoint(x: tailX - w * 0.03, y: cy - h * 0.88))
            topFin.addLine(to: CGPoint(x: tailX + w * 0.22, y: cy - h * 0.46))
            topFin.closeSubpath()
            context.fill(topFin, with: .color(finColor))

            var bottomFin = Path()
            bottomFin.move(to: CGPoint(x: tailX + w * 0.08, y: cy + h * 0.48))
            bottomFin.addLine(to: CGPoint(x: tailX - w * 0.03, y: cy + h * 0.88))
            bottomFin.addLine(to: CGPoint(x: tailX + w * 0.22, y: cy + h * 0.46))
            bottomFin.closeSubpath()
            context.fill(bottomFin, with: .color(finColor))

            let bodyRect = CGRect(x: bodyX1, y: cy - h * 0.50, width: bodyX2 - bodyX1, height: h)
            context.fill(
                Path(roundedRect: bodyRect, cornerRadius: h * 0.42),
                with: .color(isCurrentUser ? Color(red: 0.92, green: 0.78, blue: 0.72).opacity(0.92) : Color.white.opacity(0.72))
            )
            context.fill(
                Path(roundedRect: bodyRect, cornerRadius: h * 0.42),
                with: .linearGradient(
                    Gradient(colors: [Color.white.opacity(0.18), Color.black.opacity(0.18)]),
                    startPoint: CGPoint(x: bodyX1, y: cy - h * 0.5),
                    endPoint: CGPoint(x: bodyX1, y: cy + h * 0.5)
                )
            )

            var nose = Path()
            nose.move(to: CGPoint(x: bodyX2, y: cy - h * 0.44))
            nose.addQuadCurve(to: CGPoint(x: noseX, y: cy), control: CGPoint(x: noseX - w * 0.06, y: cy - h * 0.54))
            nose.addQuadCurve(to: CGPoint(x: bodyX2, y: cy + h * 0.44), control: CGPoint(x: noseX - w * 0.06, y: cy + h * 0.54))
            nose.closeSubpath()
            context.fill(nose, with: .color(isCurrentUser ? Color.stelrAccent.opacity(0.52) : Color.white.opacity(0.58)))
        }
    }
}

private struct SpaceRaceAvatar: View {
    let participant: RaceProgressParticipant

    var body: some View {
        AvatarView(
            initials: participant.isCurrentUser ? "ME" : String(participant.initials.prefix(2)),
            hexColor: participant.isCurrentUser ? "E5604A" : participant.colorHex,
            imageURL: participant.isCurrentUser ? nil : participant.imageURL,
            size: 28,
            showBorder: true
        )
        .shadow(color: .black.opacity(0.22), radius: 7, y: 3)
    }
}

private struct SpaceRaceDestinationPlanet: View {
    let accentHex: String
    var isSelected: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "E56A35").opacity(isSelected ? 0.22 : 0.14))
                .blur(radius: isSelected ? 4 : 2.5)

            Image("planet_texture")
                .resizable()
                .scaledToFill()
                .scaleEffect(1.54)
                .offset(x: -3, y: 1.5)
                .clipShape(Circle())
                .colorMultiply(Color(red: 1.0, green: 0.63, blue: 0.40))
                .saturation(1.18)
                .contrast(1.04)
                .brightness(0.08)
                .overlay(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(isSelected ? 0.22 : 0.16),
                                    Color(hex: "F59A4A").opacity(isSelected ? 0.18 : 0.12),
                                    .clear
                                ],
                                center: UnitPoint(x: 0.24, y: 0.16),
                                startRadius: 1,
                                endRadius: isSelected ? 13 : 9
                            )
                        )
                        .blendMode(.screen)
                )
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.black.opacity(isSelected ? 0.46 : 0.50)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Circle()
                        .stroke(Color(hex: "FFB06A").opacity(isSelected ? 0.26 : 0.18), lineWidth: 0.7)
                )
                .shadow(color: Color(hex: "E56A35").opacity(isSelected ? 0.26 : 0.16), radius: isSelected ? 11 : 7, y: 2)
                .shadow(color: .black.opacity(0.26), radius: 7, y: 4)
        }
    }
}

private struct SpaceRaceParticles: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<20 {
                let x = seeded(index, salt: 1) * size.width
                let y = seeded(index, salt: 2) * size.height
                let radius = 0.45 + seeded(index, salt: 3) * 0.65
                let opacity = 0.028 + seeded(index, salt: 4) * 0.040
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)),
                    with: .color(.white.opacity(opacity))
                )
            }
        }
    }

    private func seeded(_ index: Int, salt: Int) -> CGFloat {
        let value = sin(Double(index * 193 + salt * 389)) * 43758.5453
        return CGFloat(value - floor(value))
    }
}

private struct RaceProgressParticipant: Identifiable, Equatable {
    let id: String
    let name: String
    let initials: String
    let colorHex: String
    let season: Int
    let episode: Int
    let totalEpisodes: Int
    let isCurrentUser: Bool
    let deltaFromCurrentUser: Int
    let lastCheckIn: String?
    let friendID: Int?
    let imageURL: String?

    var progress: Double {
        guard totalEpisodes > 1 else { return 1 }
        return min(1, max(0, Double(episode - 1) / Double(totalEpisodes - 1)))
    }

    var lastCheckInDisplay: String {
        guard let lastCheckIn, !lastCheckIn.isEmpty else {
            return "No recent check-in"
        }
        return "Checked in \(lastCheckIn)"
    }
}

private struct PlanetHeroSection: View {
    let show: Show
    let score: Double?
    let ratingCount: Int

    private var subtitle: String {
        show.platform.uppercased()
    }

    private var metaLine: String {
        var parts: [String] = []
        if let genre = show.genre, !genre.isEmpty { parts.append(genre) }
        if let year = show.year { parts.append("\(year)") }
        return parts.joined(separator: "  ·  ")
    }

    var body: some View {
        VStack(spacing: 12) {
            PlanetDetailOrbView(show: show, score: score)
                .frame(width: 184, height: 184)
                .padding(.bottom, 2)

            Text(subtitle)
                .font(.caption)
                .tracking(1.2)
                .foregroundStyle(.tertiary)

            Text(show.title)
                .font(StelrTypography.sectionTitle)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .shadow(color: .black.opacity(0.45), radius: 10, y: 4)

            if !metaLine.isEmpty {
                Text(metaLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            PlanetCommunityScoreLine(score: score, ratingCount: ratingCount, accentHex: show.accentColor)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PlanetDetailOrbView: View {
    let show: Show
    let score: Double?

    private var accent: Color {
        if let score {
            return H7bStarVisualStyle(appScore: score).color
        }
        return Color(hex: show.accentColor)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.24))
                .frame(width: 178, height: 178)
                .blur(radius: 20)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "f3b26a"),
                            Color(hex: show.accentColor).opacity(0.88),
                            Color(hex: "5b2d12"),
                            Color(hex: "090502")
                        ],
                        center: UnitPoint(x: 0.30, y: 0.28),
                        startRadius: 8,
                        endRadius: 86
                    )
                )
                .frame(width: 126, height: 126)
                .overlay(PlanetSurfaceTexture(accentHex: show.accentColor).clipShape(Circle()))
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    .black.opacity(0.05),
                                    .black.opacity(0.64),
                                    .black.opacity(0.90)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.28),
                                    .white.opacity(0.06),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: accent.opacity(0.34), radius: 28)
                .shadow(color: .black.opacity(0.52), radius: 16, y: 10)

            ForEach(0..<5, id: \.self) { idx in
                let angle = Double(idx) / 5.0 * .pi * 2.0 + 0.28
                let radius: CGFloat = idx.isMultiple(of: 2) ? 82 : 96
                StelrFourPointStar()
                    .fill(Color.white.opacity(idx == 0 ? 0.78 : 0.48))
                    .frame(width: idx == 0 ? 10 : 7, height: idx == 0 ? 10 : 7)
                    .shadow(color: .white.opacity(0.38), radius: 8)
                    .offset(
                        x: cos(angle) * radius,
                        y: sin(angle) * radius * 0.72
                    )
            }
        }
    }
}

private struct PlanetSurfaceTexture: View {
    let accentHex: String

    var body: some View {
        Canvas { context, size in
            for idx in 0..<12 {
                let x = n(idx, 1) * size.width
                let y = n(idx, 2) * size.height
                let diameter = 4 + n(idx, 3) * 13
                let rect = CGRect(x: x, y: y, width: diameter, height: diameter)
                context.fill(Path(ellipseIn: rect), with: .color(.black.opacity(0.10 + n(idx, 4) * 0.12)))
                context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.035)), lineWidth: 0.4)
            }

            for idx in 0..<7 {
                var path = Path()
                let y = n(idx, 8) * size.height
                path.move(to: CGPoint(x: size.width * -0.05, y: y))
                path.addCurve(
                    to: CGPoint(x: size.width * 1.05, y: y + CGFloat(n(idx, 9) - 0.5) * 16),
                    control1: CGPoint(x: size.width * 0.28, y: y - CGFloat(n(idx, 10)) * 20),
                    control2: CGPoint(x: size.width * 0.62, y: y + CGFloat(n(idx, 11)) * 18)
                )
                context.stroke(path, with: .color(Color(hex: accentHex).opacity(0.08)), lineWidth: 1.2)
            }
        }
        .opacity(0.88)
    }

    private func n(_ index: Int, _ salt: Int) -> CGFloat {
        let value = sin(Double(index * 127 + salt * 311)) * 43758.5453
        return CGFloat(value - floor(value))
    }
}

private struct PlanetCommunityScoreLine: View {
    let score: Double?
    let ratingCount: Int
    let accentHex: String

    private var color: Color {
        if let score { return H7bStarVisualStyle(appScore: score).color }
        return Color(hex: accentHex)
    }

    private var scoreText: String {
        guard let score else { return "--" }
        return String(format: "%.1f", score)
    }

    private var ratingText: String {
        ratingCount == 1 ? "1 friend rating" : "\(ratingCount) friend ratings"
    }

    var body: some View {
        HStack(spacing: 10) {
            StarGlowView(score: score ?? 0, maxCoreSize: 28, animate: score != nil)
                .frame(width: 28, height: 28)
                .opacity(score == nil ? 0.45 : 0.92)

            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(scoreText)
                        .font(StelrTypography.statValue)
                        .foregroundStyle(score == nil ? .secondary : .primary)
                    Text("/ 5")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Text(score == nil ? "friend community not rated" : ratingText)
                    .font(.caption)
                    .foregroundStyle(score == nil ? Color.secondary : color)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.7))
    }
}

private struct PlanetProgressSection: View {
    let currentSeason: Int
    let currentEpisode: Int
    let totalEpisodes: Int
    let progressFraction: CGFloat
    let accentHex: String

    var body: some View {
        VStack(spacing: 9) {
            HStack {
                Text("S\(currentSeason) · E\(currentEpisode)")
                    .font(.subheadline)
                    .tracking(0.8)
                    .foregroundStyle(.primary)
                Spacer()
                Text("of \(totalEpisodes)")
                    .font(.subheadline)
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.stelrAccent, Color(hex: accentHex).opacity(0.88), Color(hex: "ffc07a")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(5, geo.size.width * progressFraction))
                        .shadow(color: Color.stelrAccent.opacity(0.22), radius: 8)
                }
            }
            .frame(height: 3)
        }
        .padding(.horizontal, 4)
    }
}

private struct EpisodeRaceEntry: Identifiable {
    let id: String
    let name: String
    let initials: String
    let colorHex: String
    let episode: Int
    let isYou: Bool
    let lastCheckIn: String?
    let interactionScore: Int
    let friendID: Int?
    let imageURL: String?
}

private struct EpisodeRaceCluster: Identifiable {
    let episode: Int
    let entries: [EpisodeRaceEntry]

    var id: String {
        "\(episode)-\(entries.map(\.id).joined(separator: "-"))"
    }

    var containsYou: Bool {
        entries.contains { $0.isYou }
    }

    var leadEntry: EpisodeRaceEntry {
        entries.first(where: { $0.isYou }) ?? entries[0]
    }
}

private struct FriendsRaceSection: View {
    let entries: [EpisodeRaceEntry]
    let totalEpisodes: Int
    let accentHex: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DetailSectionLabel("Watching with you")

            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.06), .white.opacity(0.18), .white.opacity(0.06)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 1)
                        .position(x: geo.size.width / 2, y: 24)

                    ForEach(entries) { entry in
                        RaceAvatar(entry: entry, accentHex: accentHex)
                            .position(x: xPosition(for: entry, width: geo.size.width), y: 24)
                    }

                    HStack {
                        Text("E1")
                        Spacer()
                        Text("E\(totalEpisodes)")
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .position(x: geo.size.width / 2, y: 74)
                }
            }
            .frame(height: 88)
        }
    }

    private func xPosition(for entry: EpisodeRaceEntry, width: CGFloat) -> CGFloat {
        let denom = max(1, totalEpisodes - 1)
        let fraction = CGFloat(max(0, entry.episode - 1)) / CGFloat(denom)
        return min(width - 18, max(18, fraction * width))
    }
}

private struct RaceAvatar: View {
    let entry: EpisodeRaceEntry
    let accentHex: String

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(Color(hex: entry.colorHex))
                Text(String(entry.initials.prefix(entry.isYou ? 1 : 2)))
                    .font(.caption)
                    .fontWeight(.regular)
                    .foregroundColor(Color(hex: "130b04"))
            }
            .frame(width: 30, height: 30)
            .overlay(
                Circle()
                    .stroke(entry.isYou ? Color.stelrAccent : Color.stelrBg, lineWidth: entry.isYou ? 3 : 2)
            )
            .shadow(color: entry.isYou ? Color.stelrAccent.opacity(0.28) : .black.opacity(0.22), radius: 10, y: 5)

            Text(entry.isYou ? "You" : entry.name)
                .font(.caption)
                .foregroundStyle(entry.isYou ? Color.stelrAccent : Color.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}

private struct PlanetActivityRowData: Identifiable {
    let id: Int
    let name: String
    let action: String
    let timeAgo: String
}

private struct RecentShowActivitySection: View {
    let rows: [PlanetActivityRowData]
    let accentHex: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailSectionLabel("Recent activity")

            VStack(spacing: 0) {
                ForEach(rows) { row in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.stelrAccent)
                            .frame(width: 6, height: 6)
                            .shadow(color: Color.stelrAccent.opacity(0.46), radius: 7)

                        Text(row.name)
                            .font(.body)
                            .fontWeight(.regular)
                            .foregroundStyle(.primary)
                        Text(row.action)
                            .font(.body)
                            .fontWeight(.regular)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        Text(row.timeAgo)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 12)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.white.opacity(0.055))
                            .frame(height: 0.5)
                    }
                }
            }
        }
    }
}

private struct DetailSummarySection: View {
    let summary: String
    var onExpand: () -> Void

    private let collapsedLineLimit = 4
    private let expandableCharacterThreshold = 170

    private var isExpandable: Bool {
        summary.count > expandableCharacterThreshold
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if isExpandable {
                    Button(action: onExpand) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(summary)
                                .font(StelrTypography.metadata)
                                .foregroundStyle(.secondary)
                                .lineSpacing(3)
                                .lineLimit(collapsedLineLimit)
                                .multilineTextAlignment(.leading)

                            HStack(spacing: 6) {
                                Text("Tap to read more")
                                    .font(StelrTypography.metadataStrong)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(StelrTypography.microLabel)
                            }
                            .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(summary)
                        .font(StelrTypography.metadata)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
            }
        }
    }
}

private struct SummaryPopupSheet: View {
    let title: String
    let summary: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                Text(summary)
                    .font(StelrTypography.metadata)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
            }
            .background(Color(hex: "1c1814").ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.stelrAccent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }
}

private struct DetailCastSection: View {
    let castMembers: [CastMember]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailSectionLabel("Cast")

            LazyVStack(spacing: 8) {
                ForEach(castMembers) { member in
                    CastListRow(member: member)

                    if member.id != castMembers.last?.id {
                        Divider()
                            .background(Color.white.opacity(0.06))
                            .padding(.leading, 58)
                    }
                }
            }
        }
    }
}

private struct DetailInfoTabView: View {
    let show: Show
    let castMembers: [CastMember]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                DetailSectionLabel("Details")
                DetailMetadataGrid(show: show)
                DetailExtendedMetadataSections(show: show)
            }

            DetailSoftDivider()

            VStack(alignment: .leading, spacing: 12) {
                DetailSectionLabel("Where to Watch")
                DetailPlatformPills(show: show)
            }

            DetailSoftDivider()

            DetailCastSection(castMembers: castMembers)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(Color(hex: "030810").opacity(0.30), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.075), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 10)
        .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DetailMetadataGrid: View {
    let show: Show

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    private var items: [DetailMetadataItem] {
        var values: [DetailMetadataItem] = []

        if let status = show.detailMetadata?.status, !status.isEmpty {
            values.append(DetailMetadataItem(title: "Status", value: cleanMetadataValue(status), systemName: "dot.radiowaves.left.and.right"))
        } else if show.currentEpisode.localizedCaseInsensitiveContains("finished") {
            values.append(DetailMetadataItem(title: "Status", value: "Finished", systemName: "dot.radiowaves.left.and.right"))
        }

        if let type = show.detailMetadata?.type, !type.isEmpty {
            values.append(DetailMetadataItem(title: "Type", value: cleanMetadataValue(type), systemName: "rectangle.on.rectangle"))
        } else if let animeFormat = show.detailMetadata?.animeFormat, !animeFormat.isEmpty {
            values.append(DetailMetadataItem(title: "Type", value: cleanMetadataValue(animeFormat), systemName: "rectangle.on.rectangle"))
        } else {
            values.append(DetailMetadataItem(title: "Type", value: show.isAnime ? "Anime" : "TV series", systemName: "rectangle.on.rectangle"))
        }

        if let runtime = show.detailMetadata?.averageRuntimeMinutes
            ?? show.detailMetadata?.runtimeMinutes
            ?? show.detailMetadata?.animeDurationMinutes {
            values.append(DetailMetadataItem(title: "Runtime", value: "\(runtime) min", systemName: "clock"))
        }

        if let language = show.detailMetadata?.language, !language.isEmpty {
            values.append(DetailMetadataItem(title: "Language", value: language, systemName: "character.bubble"))
        }

        if let genre = show.genre?.trimmingCharacters(in: .whitespacesAndNewlines), !genre.isEmpty {
            values.append(DetailMetadataItem(title: "Genre", value: genre, systemName: "theatermasks"))
        }

        if let year = show.year {
            values.append(DetailMetadataItem(title: "Year", value: "\(year)", systemName: "calendar"))
        }

        if let seasons = show.seasons, seasons > 0 {
            values.append(DetailMetadataItem(title: "Seasons", value: "\(seasons)", systemName: "square.stack.3d.up"))
        }

        if let totalEpisodes = show.totalEpisodes, totalEpisodes > 0 {
            values.append(DetailMetadataItem(title: "Episodes", value: "\(totalEpisodes)", systemName: "list.number"))
        }

        if !show.currentEpisode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            values.append(DetailMetadataItem(title: "Current", value: show.currentEpisode, systemName: "play.tv"))
        }

        return values
    }

    private func cleanMetadataValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .lowercased()
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    var body: some View {
        if !items.isEmpty {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(items) { item in
                    DetailMetadataTile(item: item, accentHex: show.accentColor)
                }
            }
        }
    }
}

private struct DetailExtendedMetadataSections: View {
    let show: Show

    private var sections: [DetailMetadataSection] {
        var values: [DetailMetadataSection] = []
        var release: [DetailMetadataItem] = []
        var schedule: [DetailMetadataItem] = []
        var anime: [DetailMetadataItem] = []
        var links: [DetailMetadataItem] = []

        let metadata = show.detailMetadata

        append(metadata?.premiered, to: &release, title: "Premiered", icon: "calendar.badge.clock")
        append(metadata?.ended, to: &release, title: "Ended", icon: "calendar.badge.checkmark")

        if let scheduleValue = scheduleValue(from: metadata) {
            schedule.append(DetailMetadataItem(title: "Schedule", value: scheduleValue, systemName: "calendar"))
        }
        if let countryValue = countryValue(from: metadata) {
            schedule.append(DetailMetadataItem(title: "Country", value: countryValue, systemName: "globe.americas"))
        }
        append(metadata?.timezone, to: &schedule, title: "Timezone", icon: "clock.badge")

        append(metadata?.animeFormat, to: &anime, title: "Format", icon: "rectangle.portrait.on.rectangle.portrait")
        append(metadata?.animeSource, to: &anime, title: "Source", icon: "book")
        append(metadata?.animeCountryOfOrigin, to: &anime, title: "Origin", icon: "flag")
        append(metadata?.animeStartDate, to: &anime, title: "Start date", icon: "calendar.badge.clock")
        append(metadata?.animeEndDate, to: &anime, title: "End date", icon: "calendar.badge.checkmark")
        if let studios = metadata?.animeStudios, !studios.isEmpty {
            anime.append(DetailMetadataItem(title: "Studio", value: studios.prefix(3).joined(separator: ", "), systemName: "building.2"))
        }

        if let alternateTitles = show.alternateTitles?.filter({ $0 != show.title }), !alternateTitles.isEmpty {
            links.append(DetailMetadataItem(title: "Also known as", value: alternateTitles.prefix(3).joined(separator: ", "), systemName: "textformat"))
        }
        if let officialSite = metadata?.officialSite {
            links.append(DetailMetadataItem(title: "Official site", value: displayURL(officialSite), systemName: "safari", url: normalizedURLString(officialSite)))
        }
        if let animeSiteURL = metadata?.animeSiteURL {
            links.append(DetailMetadataItem(title: "AniList page", value: displayURL(animeSiteURL), systemName: "link", url: normalizedURLString(animeSiteURL)))
        }
        if let externalIds = metadata?.externalIds {
            if let imdb = externalIds.imdb?.trimmingCharacters(in: .whitespacesAndNewlines), !imdb.isEmpty {
                links.append(DetailMetadataItem(title: "IMDb", value: imdb, systemName: "number", url: "https://www.imdb.com/title/\(imdb)"))
            }
            if let thetvdb = externalIds.thetvdb {
                links.append(DetailMetadataItem(title: "TheTVDB", value: "\(thetvdb)", systemName: "number.square", url: "https://thetvdb.com/dereferrer/series/\(thetvdb)"))
            }
            if let tvrage = externalIds.tvrage {
                links.append(DetailMetadataItem(title: "TVRage", value: "\(tvrage)", systemName: "number.square"))
            }
            if let aniList = externalIds.aniList {
                links.append(DetailMetadataItem(title: "AniList ID", value: "\(aniList)", systemName: "number.square", url: "https://anilist.co/anime/\(aniList)"))
            }
            if let myAnimeList = externalIds.myAnimeList {
                links.append(DetailMetadataItem(title: "MyAnimeList", value: "\(myAnimeList)", systemName: "number.square", url: "https://myanimelist.net/anime/\(myAnimeList)"))
            }
        }

        appendSection("Release", release, to: &values)
        appendSection(show.isAnime ? "Anime" : "Broadcast", show.isAnime ? anime : schedule, to: &values)
        if show.isAnime, !schedule.isEmpty {
            appendSection("Broadcast", schedule, to: &values)
        }
        appendSection("Links", links, to: &values)
        return values
    }

    var body: some View {
        if !sections.isEmpty {
            VStack(spacing: 10) {
                ForEach(sections) { section in
                    DetailMetadataRowSection(section: section, accentHex: show.accentColor)
                }
            }
        }
    }

    private func append(_ value: String?, to items: inout [DetailMetadataItem], title: String, icon: String) {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return }
        items.append(DetailMetadataItem(title: title, value: clean(value), systemName: icon))
    }

    private func appendSection(_ title: String, _ items: [DetailMetadataItem], to sections: inout [DetailMetadataSection]) {
        guard !items.isEmpty else { return }
        sections.append(DetailMetadataSection(title: title, items: items))
    }

    private func scheduleValue(from metadata: ShowDetailMetadata?) -> String? {
        let days = metadata?.scheduleDays?.filter { !$0.isEmpty } ?? []
        let time = metadata?.scheduleTime?.trimmingCharacters(in: .whitespacesAndNewlines)
        if days.isEmpty {
            return (time?.isEmpty == false) ? time : nil
        }
        if let time, !time.isEmpty {
            return "\(days.joined(separator: ", ")) at \(time)"
        }
        return days.joined(separator: ", ")
    }

    private func countryValue(from metadata: ShowDetailMetadata?) -> String? {
        guard let name = metadata?.countryName, !name.isEmpty else { return metadata?.countryCode }
        if let code = metadata?.countryCode, !code.isEmpty {
            return "\(name) (\(code))"
        }
        return name
    }

    private func displayURL(_ value: String) -> String {
        guard let url = URL(string: value) else { return value }
        let host = url.host?.replacingOccurrences(of: "www.", with: "") ?? value
        return url.path.isEmpty || url.path == "/" ? host : "\(host)\(url.path)"
    }

    private func normalizedURLString(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return trimmed
        }
        return "https://\(trimmed)"
    }

    private func clean(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { part in
                let raw = String(part)
                if raw.count <= 4, raw == raw.uppercased() {
                    return raw
                }
                return raw.prefix(1).uppercased() + raw.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }
}

private struct DetailMetadataSection: Identifiable {
    let title: String
    let items: [DetailMetadataItem]

    var id: String { title }
}

private struct DetailMetadataRowSection: View {
    let section: DetailMetadataSection
    let accentHex: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(section.title)
                .font(.system(size: 10.8, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.horizontal, 12)
                .padding(.top, 11)
                .padding(.bottom, 3)

            ForEach(section.items) { item in
                DetailMetadataRow(item: item, accentHex: accentHex)
                if item.id != section.items.last?.id {
                    Divider()
                        .background(Color.white.opacity(0.06))
                        .padding(.leading, 42)
                }
            }
        }
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.7)
        )
    }
}

private struct DetailMetadataRow: View {
    let item: DetailMetadataItem
    let accentHex: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(hex: accentHex).opacity(0.9))
                .frame(width: 22, height: 22)
                .background(Color(hex: accentHex).opacity(0.11), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text(item.title)
                .font(.system(size: 12.4, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 10)

            metadataValue
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var metadataValue: some View {
        if let url = item.linkURL {
            Link(destination: url) {
                HStack(spacing: 4) {
                    Text(item.value)
                        .multilineTextAlignment(.trailing)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .font(.system(size: 12.8, weight: .semibold))
                .foregroundStyle(Color(hex: accentHex).opacity(0.95))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Text(item.value)
                .font(.system(size: 12.8, weight: .semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct DetailMetadataItem: Identifiable {
    let title: String
    let value: String
    let systemName: String
    var url: String? = nil

    var id: String { "\(title)-\(value)-\(url ?? "")" }

    var linkURL: URL? {
        guard let url, !url.isEmpty else { return nil }
        return URL(string: url)
    }
}

private struct DetailMetadataTile: View {
    let item: DetailMetadataItem
    let accentHex: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: item.systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: accentHex).opacity(0.92))
                .frame(width: 24, height: 24)
                .background(Color(hex: accentHex).opacity(0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .lineLimit(1)

                Text(item.value)
                    .font(.system(size: 13.2, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.040), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.065), lineWidth: 0.7)
        )
    }
}

private struct DetailSoftDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.075))
            .frame(height: 0.7)
            .padding(.horizontal, 2)
    }
}

private struct DetailSectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(StelrTypography.microLabel)
            .foregroundStyle(.tertiary)
            .tracking(1.1)
    }
}

private struct CastListRow: View {
    let member: CastMember

    var body: some View {
        HStack(spacing: 12) {
            castImage
                .frame(width: 46, height: 46)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.7)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(member.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let characterName = member.characterName, !characterName.isEmpty {
                    Text(characterName)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var castImage: some View {
        if let imageURL = member.imageURL, let url = URL(string: imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                default:
                    fallbackIcon
                }
            }
        } else {
            fallbackIcon
        }
    }

    private var fallbackIcon: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.08))
            Image(systemName: "person.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Episode Notes

private struct EpisodeNotesSection: View {
    let show: Show
    let currentSeason: Int
    let currentEpisode: Int
    @Binding var selectedSeason: Int
    let seasonCount: Int
    let isLocked: Bool
    let onAddNote: (Int) -> Void

    @EnvironmentObject var appState: AppState
    @State private var selectedEpisode: Int

    init(show: Show, currentSeason: Int, currentEpisode: Int, selectedSeason: Binding<Int>, seasonCount: Int, isLocked: Bool = false, onAddNote: @escaping (Int) -> Void) {
        self.show = show
        self.currentSeason = currentSeason
        self.currentEpisode = currentEpisode
        self._selectedSeason = selectedSeason
        self.seasonCount = seasonCount
        self.isLocked = isLocked
        self.onAddNote = onAddNote
        _selectedEpisode = State(initialValue: isLocked ? 1 : currentEpisode)
    }

    // Effective episode ceiling for spoiler logic — past seasons fully unlocked
    private var effectiveCurrentEpisode: Int {
        if selectedSeason < currentSeason { return Int.max }
        if selectedSeason > currentSeason { return 0 }
        return currentEpisode
    }

    private var completedEpisodes: [Int] {
        if isLocked { return [] }
        if selectedSeason < currentSeason {
            let total = show.episodeCount(forSeason: selectedSeason, fallback: 10) ?? 10
            return Array(1...max(1, total))
        } else if selectedSeason == currentSeason {
            guard currentEpisode >= 1 else { return [] }
            return Array(1...currentEpisode)
        } else {
            return []
        }
    }

    // Episodes the user hasn't reached yet — shown as locked chips
    private var lockedEpisodes: [Int] {
        let total = show.episodeCount(forSeason: selectedSeason, fallback: 10) ?? 10
        guard total > 0 else { return [] }
        // When the show isn't in rotation, all episodes are locked
        if isLocked { return Array(1...total) }
        if selectedSeason < currentSeason { return [] } // past seasons fully unlocked
        if selectedSeason > currentSeason {
            return Array(1...total) // whole future season is locked
        }
        // current season: episodes after currentEpisode
        guard total > currentEpisode else { return [] }
        return Array((currentEpisode + 1)...total)
    }

    // True when the selected episode is beyond what the user has checked in to
    private var isEpisodeLocked: Bool {
        selectedEpisode > effectiveCurrentEpisode
    }

    private var myNote: EpisodeComment? {
        appState.myComment(showId: show.id, season: selectedSeason, episode: selectedEpisode)
    }

    private var visibleFriendNotes: [EpisodeComment] {
        appState.visibleFriendComments(
            showId: show.id, season: selectedSeason,
            episode: selectedEpisode, currentEpisode: effectiveCurrentEpisode
        )
    }

    private var lockedCount: Int {
        appState.lockedFriendComments(
            showId: show.id, season: selectedSeason,
            episode: selectedEpisode, currentEpisode: effectiveCurrentEpisode
        ).count
    }

    private var hasAnyContent: Bool {
        myNote != nil || !visibleFriendNotes.isEmpty || lockedCount > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section header row
            HStack(alignment: .center) {
                Text("TAKES")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .tracking(1.1)

                Spacer()

                if !isEpisodeLocked && !isLocked {
                    Button {
                        onAddNote(selectedEpisode)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: myNote != nil ? "pencil" : "pencil.line")
                                .font(.system(size: 11, weight: .medium))
                            Text(myNote != nil ? "Edit" : "Add take")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(Color(hex: show.accentColor).opacity(0.85))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Color(hex: show.accentColor).opacity(0.10), in: Capsule(style: .continuous))
                        .overlay(Capsule(style: .continuous).stroke(Color(hex: show.accentColor).opacity(0.20), lineWidth: 0.7))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Episode chip scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(completedEpisodes, id: \.self) { ep in
                        episodeChip(ep)
                    }
                    ForEach(lockedEpisodes, id: \.self) { ep in
                        lockedEpisodeChip(ep)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()

            // Comment content
            VStack(alignment: .leading, spacing: 10) {
                if isEpisodeLocked {
                    lockedEpisodeState
                } else {
                    if let myNote {
                        EpisodeCommentRow(comment: myNote, accentHex: show.accentColor)
                    }

                    if !visibleFriendNotes.isEmpty {
                        if myNote != nil {
                            Divider()
                                .background(Color.white.opacity(0.08))
                        }
                        ForEach(visibleFriendNotes) { note in
                            EpisodeCommentRow(comment: note, accentHex: show.accentColor)
                        }
                    }

                    // Locked friend notes indicator (friends commented but you haven't passed this episode)
                    if lockedCount > 0 {
                        if myNote != nil || !visibleFriendNotes.isEmpty {
                            Divider().background(Color.white.opacity(0.08))
                        }
                        lockedNotesView
                    }

                    // Empty state
                    if !hasAnyContent {
                        emptyState
                    }
                }
            }
            .animation(.easeInOut(duration: 0.22), value: selectedEpisode)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .background(
            Color(hex: "030810").opacity(0.30),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.075), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 10)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.spring(response: 0.32, dampingFraction: 0.84), value: selectedEpisode)
        .onChange(of: selectedSeason) { _, _ in
            selectedEpisode = completedEpisodes.last ?? 1
        }
    }

    private func episodeChip(_ ep: Int) -> some View {
        let isSelected = ep == selectedEpisode
        let hasOwn = appState.myComment(showId: show.id, season: selectedSeason, episode: ep) != nil
        let hasFriend = appState.episodeComments.contains {
            $0.showId == show.id && $0.season == selectedSeason && $0.episode == ep && !$0.isOwn
                && ep < effectiveCurrentEpisode
        }
        let hasLocked = appState.episodeComments.contains {
            $0.showId == show.id && $0.season == selectedSeason && $0.episode == ep && !$0.isOwn
                && ep >= effectiveCurrentEpisode
        }
        let accent = Color(hex: show.accentColor)

        return Button {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) {
                selectedEpisode = ep
            }
            StelrHaptics.selection()
        } label: {
            HStack(spacing: 4) {
                Text("E\(ep)")
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(
                        isSelected
                            ? Color.white
                            : Color.white.opacity(0.72)
                    )

                if hasOwn {
                    Circle()
                        .fill(accent.opacity(isSelected ? 1 : 0.78))
                        .frame(width: 4, height: 4)
                } else if hasFriend || hasLocked {
                    Circle()
                        .fill(hasLocked ? Color.white.opacity(0.34) : Color.white.opacity(0.52))
                        .frame(width: 4, height: 4)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(
                isSelected
                    ? accent.opacity(0.24)
                    : Color.white.opacity(0.075),
                in: Capsule(style: .continuous)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(
                        isSelected
                            ? accent.opacity(0.74)
                            : Color.white.opacity(0.12),
                        lineWidth: isSelected ? 1.2 : 0.7
                    )
            )
            .shadow(color: isSelected ? accent.opacity(0.18) : .clear, radius: 8, y: 4)
            .scaleEffect(isSelected ? 1.04 : 1)
        }
        .buttonStyle(.plain)
    }

    private var lockedNotesView: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(lockedCount) \(lockedCount == 1 ? "friend" : "friends") shared \(lockedCount == 1 ? "a take" : "takes")")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Text("Unlocks after you check in past this episode")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.065), lineWidth: 0.7)
        )
    }

    private var emptyState: some View {
        Button {
            onAddNote(selectedEpisode)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "pencil.line")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                Text("No notes - add your predictions, comments, and reactions here!")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    // Shown in place of content when the user taps a locked episode chip
    private var lockedEpisodeState: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(isLocked ? "Add show to unlock" : "E\(selectedEpisode) is locked")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Text(isLocked ? "Track this show to write and read episode takes" : "Check in to E\(selectedEpisode) to read and share takes")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.065), lineWidth: 0.7)
        )
    }

    // Dimmed tappable chip for episodes beyond the user's current progress
    private func lockedEpisodeChip(_ ep: Int) -> some View {
        let isSelected = ep == selectedEpisode
        return Button {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) {
                selectedEpisode = ep
            }
            StelrHaptics.selection()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.secondary) : AnyShapeStyle(.quaternary))
                Text("E\(ep)")
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.secondary) : AnyShapeStyle(.quaternary))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(
                isSelected ? Color.white.opacity(0.07) : Color.white.opacity(0.025),
                in: Capsule(style: .continuous)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(
                        isSelected ? Color.white.opacity(0.14) : Color.white.opacity(0.04),
                        lineWidth: 0.7
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct EpisodeCommentRow: View {
    let comment: EpisodeComment
    let accentHex: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Avatar bubble
            ZStack {
                Circle()
                    .fill(
                        comment.isOwn
                            ? Color(hex: accentHex).opacity(0.18)
                            : Color(hex: comment.authorHexColor).opacity(0.16)
                    )
                Text(comment.isOwn ? "ME" : String(comment.authorInitials.prefix(2)))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(
                        comment.isOwn
                            ? Color(hex: accentHex)
                            : Color(hex: comment.authorHexColor)
                    )
            }
            .frame(width: 26, height: 26)
            .overlay(Circle().stroke(Color.white.opacity(0.09), lineWidth: 0.6))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(comment.isOwn ? "You" : comment.authorName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(
                            comment.isOwn
                                ? Color(hex: accentHex)
                                : Color.primary.opacity(0.84)
                        )
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                    Text(comment.timeAgo)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Text(comment.text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

enum ElegantSpaceZoomPhase: Equatable {
    case idle
    case lockOn
    case travel
    case arrive
}

struct ElegantSpaceZoomTuning {
    var focusDuration: Double = 0.18
    var cameraPushDuration: Double = 0.58
    var arrivalDuration: Double = 0.22
    var particleCount: Int = 56
    var streakOpacity: Double = 0.44
    var zoomAmount: CGFloat = 0.055
    var blurAmount: CGFloat = 0.35
    var glowAmount: Double = 0.16

    var totalDuration: Double {
        focusDuration + cameraPushDuration + arrivalDuration
    }

    static let `default` = ElegantSpaceZoomTuning(
        focusDuration: 0.15,
        cameraPushDuration: 0.58,
        arrivalDuration: 0.22,
        particleCount: 48,
        streakOpacity: 0.28,
        zoomAmount: 0.048,
        blurAmount: 0.25,
        glowAmount: 0.12
    )
}

struct ElegantSpaceZoomTransition: View {
    let phase: ElegantSpaceZoomPhase
    let seed: Int
    let origin: CGPoint?
    var particleCount: Int = ElegantSpaceZoomTuning.default.particleCount
    var intensity: Double = 1.0
    var tuning: ElegantSpaceZoomTuning = .default

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()

    var body: some View {
        GeometryReader { geo in
            let resolvedOrigin = origin ?? CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let center = UnitPoint(
                x: max(0, min(1, resolvedOrigin.x / max(1, geo.size.width))),
                y: max(0, min(1, resolvedOrigin.y / max(1, geo.size.height)))
            )

            ZStack {
                Color(hex: "02040B")
                    .opacity(backgroundOpacity)

                RadialGradient(
                    colors: [
                        Color.white.opacity(centerGlowOpacity),
                        Color.stelrAccent.opacity(centerGlowOpacity * 0.48),
                        .clear
                    ],
                    center: center,
                    startRadius: 2,
                    endRadius: max(geo.size.width, geo.size.height) * (reduceMotion ? 0.40 : 0.50)
                )

                if reduceMotion {
                    reduceMotionLayer(center: center)
                } else {
                    ElegantSpaceZoomStarfield(
                        phase: phase,
                        seed: seed,
                        origin: resolvedOrigin,
                        particleCount: particleCount,
                        intensity: intensity,
                        tuning: tuning,
                        startedAt: startedAt
                    )
                    .blur(radius: phase == .travel ? tuning.blurAmount : 0)
                }
            }
            .compositingGroup()
            .opacity(phase == .idle ? 0 : 1)
            .scaleEffect(reduceMotion ? reduceMotionScale : 1)
            .animation(.easeInOut(duration: reduceMotion ? 0.24 : 0.18), value: phase)
            .onAppear {
                startedAt = Date()
            }
            .onChange(of: seed) { _, _ in
                startedAt = Date()
            }
        }
        .allowsHitTesting(false)
    }

    private var backgroundOpacity: Double {
        switch phase {
        case .idle: return 0
        case .lockOn: return reduceMotion ? 0.12 : 0.10
        case .travel: return reduceMotion ? 0.20 : 0.34 * intensity
        case .arrive: return reduceMotion ? 0.10 : 0.16
        }
    }

    private var centerGlowOpacity: Double {
        switch phase {
        case .idle: return 0
        case .lockOn: return tuning.glowAmount * 0.72 * intensity
        case .travel: return tuning.glowAmount * intensity
        case .arrive: return tuning.glowAmount * 0.46 * intensity
        }
    }

    private var reduceMotionScale: CGFloat {
        switch phase {
        case .idle: return 1
        case .lockOn: return 0.995
        case .travel: return 1.018
        case .arrive: return 1.006
        }
    }

    private func reduceMotionLayer(center: UnitPoint) -> some View {
        RadialGradient(
            colors: [
                Color.white.opacity(phase == .arrive ? 0.08 : 0.12),
                Color.stelrAccent.opacity(phase == .lockOn ? 0.06 : 0.04),
                .clear
            ],
            center: center,
            startRadius: 0,
            endRadius: 240
        )
        .scaleEffect(phase == .arrive ? 1.04 : 0.98)
        .animation(.easeInOut(duration: 0.22), value: phase)
    }
}

private struct ElegantSpaceZoomStarfield: View {
    let phase: ElegantSpaceZoomPhase
    let seed: Int
    let origin: CGPoint
    let particleCount: Int
    let intensity: Double
    let tuning: ElegantSpaceZoomTuning
    let startedAt: Date

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startedAt)
            Canvas { context, size in
                drawParticles(
                    context: &context,
                    size: size,
                    origin: origin,
                    elapsed: elapsed
                )
            }
        }
    }

    private func drawParticles(
        context: inout GraphicsContext,
        size: CGSize,
        origin: CGPoint,
        elapsed: TimeInterval
    ) {
        guard phase != .idle else { return }

        let maxDimension = max(size.width, size.height)
        let focusProgress = eased(clamped(elapsed / tuning.focusDuration))
        let travelProgress = eased(clamped((elapsed - tuning.focusDuration) / tuning.cameraPushDuration))
        let arrivalProgress = eased(clamped((elapsed - tuning.focusDuration - tuning.cameraPushDuration) / tuning.arrivalDuration))
        let focusAmount = phase == .lockOn ? focusProgress : max(0, 1 - travelProgress)

        drawCenterBloom(
            context: &context,
            origin: origin,
            radius: 54 + 28 * focusAmount,
            opacity: 0.025 + 0.05 * focusAmount
        )

        let globalFade = max(0, sin(travelProgress * .pi) * (1 - arrivalProgress * 0.9))

        guard phase == .travel || phase == .arrive || phase == .lockOn else { return }

        for index in 0..<particleCount {
            let depth = 0.32 + random(index, 8) * 0.68
            let angle = random(index, 1) * .pi * 2
            let direction = CGPoint(x: cos(angle), y: sin(angle))
            let startRadius = 18 + random(index, 2) * maxDimension * 0.50
            let drift = maxDimension * tuning.zoomAmount * travelProgress * (0.55 + depth * 1.35)
            let radius = startRadius + drift
            let point = CGPoint(
                x: origin.x + direction.x * radius,
                y: origin.y + direction.y * radius
            )

            let isStreak = index % 5 == 0 && travelProgress > 0.08
            let isWarmHighlight = index % 17 == 0
            let color = isWarmHighlight ? Color.stelrAccent : Color.white

            if isStreak {
                let length = min(18, 2 + pow(travelProgress, 1.25) * (3.5 + random(index, 5) * 11.5) * depth)
                let opacity = (isWarmHighlight ? 0.16 : tuning.streakOpacity) * (0.42 + depth * 0.42) * globalFade * intensity
                let start = CGPoint(
                    x: point.x - direction.x * length,
                    y: point.y - direction.y * length
                )
                var path = Path()
                path.move(to: start)
                path.addLine(to: point)

                context.stroke(
                    path,
                    with: .color(color.opacity(opacity)),
                    style: StrokeStyle(lineWidth: 0.55 + depth * 0.55, lineCap: .round)
                )
            } else {
                let pointSize = 0.7 + depth * 1.05
                let opacity = (0.12 + depth * 0.22) * max(0.20, 1 - arrivalProgress) * intensity
                let rect = CGRect(
                    x: point.x - pointSize / 2,
                    y: point.y - pointSize / 2,
                    width: pointSize,
                    height: pointSize
                )
                context.fill(Path(ellipseIn: rect), with: .color(color.opacity(opacity)))
            }
        }
    }

    private func drawCenterBloom(
        context: inout GraphicsContext,
        origin: CGPoint,
        radius: CGFloat,
        opacity: Double
    ) {
        let rect = CGRect(
            x: origin.x - radius / 2,
            y: origin.y - radius / 2,
            width: radius,
            height: radius
        )
        context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(opacity * intensity)))
        context.fill(
            Path(ellipseIn: rect.insetBy(dx: radius * 0.22, dy: radius * 0.22)),
            with: .color(Color.stelrAccent.opacity(opacity * 0.28 * intensity))
        )
    }

    private func random(_ index: Int, _ salt: Int) -> Double {
        let raw = sin(Double(seed * 997 + index * 131 + salt * 521)) * 43758.5453123
        return raw - floor(raw)
    }

    private func eased(_ value: Double) -> Double {
        let t = clamped(value)
        return t * t * (3 - 2 * t)
    }

    private func clamped(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
