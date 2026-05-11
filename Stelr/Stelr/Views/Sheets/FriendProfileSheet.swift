import SwiftUI

private extension Array where Element == Double {
    var average: Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}

private enum FriendProfileSection: String, CaseIterable, Identifiable {
    case inFlight = "In flight"
    case allShows = "All shows"
    case ratings = "Ratings"

    var id: String { rawValue }
}

struct FriendProfileSheet: View {
    let friend: Friend
    var highlightedShowId: Int? = nil
    var showsCloseButton = true

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var detailShow: Show?
    @State private var selectedSection: FriendProfileSection = .inFlight
    @State private var contentAppeared = false

    private var currentShow: Show? { appState.show(for: friend.currentShowId) }
    private var heroShow: Show? {
        if let highlightedShowId, let show = appState.show(for: highlightedShowId) {
            return show
        }
        return currentShow
    }
    private var watchingShows: [Show] {
        var shows = friend.watchedShowIds.compactMap { appState.show(for: $0) }
        if let highlightedShowId, let index = shows.firstIndex(where: { $0.id == highlightedShowId }) {
            let highlighted = shows.remove(at: index)
            shows.insert(highlighted, at: 0)
        }
        return shows
    }
    private var supportingShows: [Show] {
        guard let heroShow else { return watchingShows }
        return watchingShows.filter { $0.id != heroShow.id }
    }
    private var friendActivity: [Activity] {
        appState.activities.filter { $0.friendId == friend.id }
    }
    private var sharedShows: [Show] {
        let myShowIds = Set(appState.myShows.map(\.showId))
        let overlapIds = friend.watchedShowIds.filter { myShowIds.contains($0) }
        var shows = overlapIds.compactMap { appState.show(for: $0) }
        if let highlightedShowId, let index = shows.firstIndex(where: { $0.id == highlightedShowId }) {
            let highlighted = shows.remove(at: index)
            shows.insert(highlighted, at: 0)
        }
        return shows
    }
    private var tasteCompatibility: FriendTasteCompatibility {
        FriendTasteCompatibility.make(
            friend: friend,
            myShows: appState.myShows,
            allShows: appState.shows,
            activities: appState.activities,
            highlightedShowId: highlightedShowId
        )
    }
    private var vibe: VibeOption { friend.vibe }
    private var friendRatingColor: Color {
        H7bStarVisualStyle.ratingColor(appScore: friend.score)
    }
    private var friendScoreText: String {
        String(format: "%.1f", CheckInStep.from(friend.score).score)
    }
    private var subtitleText: String {
        guard let show = heroShow else { return "\(vibe.emoji) \(vibe.label)" }
        if highlightedShowId != nil {
            return "Connected through \(show.title)"
        }
        if watchingShows.count > 1 {
            return "\(vibe.emoji) \(vibe.label) • watching \(show.title) + \(watchingShows.count - 1)"
        }
        return "\(vibe.emoji) \(vibe.label) • watching \(show.title)"
    }

    var body: some View {
        ZStack {
            StelrFrostedBackdrop()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    friendProfileHeader
                        .padding(.horizontal, 26)
                        .padding(.top, showsCloseButton ? 78 : 52)
                        .padding(.bottom, 16)

                    topBanner
                        .padding(.horizontal, 32)
                        .padding(.bottom, 14)

                    FriendCompatibilityCard(
                        friend: friend,
                        compatibility: tasteCompatibility,
                        onOpenShow: { show in detailShow = show }
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)

                    sectionPicker
                        .padding(.horizontal, 18)
                        .padding(.bottom, 24)

                    selectedSectionContent
                        .padding(.horizontal, 24)

                    Spacer(minLength: 118)
                }
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 76)
                .animation(.spring(response: 0.62, dampingFraction: 0.82), value: contentAppeared)
            }
            .ignoresSafeArea(edges: .top)
        }
        .overlay(alignment: .topTrailing) {
            if showsCloseButton {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15.8, weight: .medium))
                        .foregroundColor(.stelrMuted)
                        .frame(width: 41, height: 41)
                        .background(Color.white.opacity(0.07), in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 0.8))
                }
                .buttonStyle(.stelrPress)
                .padding(.top, 24)
                .padding(.trailing, 18)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
        .sheet(item: $detailShow) { show in
            ShowDetailView(show: show, watchingFriends: appState.friendsWatching(showId: show.id))
        }
        .onAppear { runEntranceAnimation() }
    }

    private var friendProfileHeader: some View {
        VStack(alignment: .center, spacing: 10) {
            friendAvatar

            VStack(spacing: 3) {
                Text(friend.name)
                    .font(StelrTypography.sectionTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text("@\(friend.username)")
                    .font(StelrTypography.metadata)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .center, spacing: 30) {
                inlineStat(value: "\(watchingShows.count)", label: "shows")
                inlineStat(value: "\(friendActivity.count)", label: "ratings")
                inlineStat(value: friendScoreText, label: "avg")
            }
            .padding(.top, 2)

            Text(subtitleText)
                .font(StelrTypography.metadata)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 310)
                .padding(.top, 1)

            headerAction
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var headerAction: some View {
        if appState.isFriend(friend) {
            HStack(spacing: 6) {
                VibeWaveView(vibe: vibe, score: friend.score, size: 17)
                    .frame(width: 20, height: 20)
                Text(friendScoreText)
                    .font(.system(size: 12.4, weight: .semibold, design: .rounded))
                    .foregroundColor(friendRatingColor)
                    .monospacedDigit()
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.07), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 0.8))
        } else {
            Button {
                StelrHaptics.lightTap()
                appState.addFriend(friend)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 11.8, weight: .semibold))
                    Text("Add friend")
                        .font(.system(size: 12.8, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Color.stelrAccent, in: Capsule())
            }
            .buttonStyle(.stelrPress)
            .accessibilityLabel("Add \(friend.name) as a friend")
        }
    }

    private var friendAvatar: some View {
        ZStack {
            AvatarView(initials: friend.initials, hexColor: friend.hexColor, imageURL: friend.imageURL, size: 76)
            if friend.isActive {
                Circle()
                    .fill(Color(hex: "72c97e"))
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color(hex: "1c1814"), lineWidth: 2))
                    .offset(x: 27, y: 27)
            }
        }
    }

    @ViewBuilder
    private var topBanner: some View {
        if let show = heroShow {
            Button {
                detailShow = show
            } label: {
                if highlightedShowId != nil {
                    ConnectedShowRatingCard(
                        friendName: friend.name,
                        show: show,
                        vibe: ratingVibe(for: show),
                        score: ratingScore(for: show),
                        color: ratingColor(for: show)
                    )
                } else {
                    FriendProfileBanner(
                        title: "Currently watching \(show.title)",
                        subtitle: "\(vibe.emoji) \(vibe.label) • \(show.platform)",
                        accentColor: ratingColor(for: show),
                        score: ratingScore(for: show),
                        vibe: ratingVibe(for: show)
                    )
                }
            }
            .buttonStyle(.stelrPress)
        }
    }

    private var sectionPicker: some View {
        HStack(spacing: 0) {
            ForEach(FriendProfileSection.allCases) { section in
                Button {
                    StelrHaptics.lightTap()
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        selectedSection = section
                    }
                } label: {
                    VStack(spacing: 5) {
                        Text(section.rawValue)
                            .font(.system(size: 10.6, weight: .bold))
                            .foregroundColor(selectedSection == section ? .stelrText : .stelrMuted.opacity(0.52))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        Rectangle()
                            .fill(selectedSection == section ? Color.stelrText : .clear)
                            .frame(height: 0.8)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var selectedSectionContent: some View {
        switch selectedSection {
        case .inFlight:
            if let show = heroShow {
                FriendCurrentFlightSection(
                    show: show,
                    supportingShows: supportingShows,
                    vibe: ratingVibe(for: show),
                    score: ratingScore(for: show),
                    onOpenShow: { tappedShow in
                        detailShow = tappedShow
                    }
                )
            } else {
                FriendEmptySection(
                    systemImage: "sparkles.rectangle.stack",
                    title: "nothing in flight",
                    subtitle: "\(friend.name) has not started a show yet."
                )
            }

        case .allShows:
            if watchingShows.isEmpty {
                FriendEmptySection(
                    systemImage: "tv.slash",
                    title: "no active shows",
                    subtitle: "\(friend.name) is not watching anything right now."
                )
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("ALL SHOWS")
                        .font(.system(size: 11.8))
                        .foregroundColor(.stelrMuted)
                        .kerning(0.8)

                    ForEach(watchingShows) { show in
                        FriendShowRow(
                            show: show,
                            vibe: ratingVibe(for: show),
                            score: ratingScore(for: show),
                            color: ratingColor(for: show)
                        ) {
                            detailShow = show
                        }
                    }
                }
            }

        case .ratings:
            VStack(alignment: .leading, spacing: 12) {
                Text("RECENT RATINGS")
                    .font(.system(size: 11.8))
                    .foregroundColor(.stelrMuted)
                    .kerning(0.8)

                if friendActivity.isEmpty {
                    FriendEmptySection(
                        systemImage: "star.slash",
                        title: "no ratings yet",
                        subtitle: "\(friend.name) has not checked in yet."
                    )
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(friendActivity) { activity in
                            if let show = appState.show(for: activity.showId) {
                                RatingActivityRow(activity: activity, friend: friend, show: show) {
                                    detailShow = show
                                }
                                Divider()
                                    .background(Color.stelrBorder)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    private func activity(for show: Show) -> Activity? {
        appState.activities.first { $0.friendId == friend.id && $0.showId == show.id }
    }

    private func ratingScore(for show: Show) -> Double {
        activity(for: show)?.score ?? friend.score
    }

    private func ratingVibe(for show: Show) -> VibeOption {
        activity(for: show)?.vibe ?? VibeOption.from(score: ratingScore(for: show))
    }

    private func ratingColor(for show: Show) -> Color {
        H7bStarVisualStyle.ratingColor(appScore: ratingScore(for: show))
    }

    private func scoreText(_ score: Double) -> String {
        String(format: "%.1f", CheckInStep.from(score).score)
    }

    private func inlineStat(value: String, label: String) -> some View {
        VStack(alignment: .center, spacing: 1) {
            Text(value)
                .font(StelrTypography.statValue)
                .foregroundStyle(.primary)
                .monospacedDigit()
            Text(label)
                .font(StelrTypography.statLabel)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 58)
    }

    private func runEntranceAnimation() {
        contentAppeared = false
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.62, dampingFraction: 0.82)) {
                contentAppeared = true
            }
        }
    }
}

private struct FriendTasteCompatibility {
    let score: Int
    let label: String
    let subtitle: String
    let sharedShows: [Show]
    let sharedGenres: [String]
    let ratingLine: String

    static func make(
        friend: Friend,
        myShows: [MyShow],
        allShows: [Show],
        activities: [Activity],
        highlightedShowId: Int?
    ) -> FriendTasteCompatibility {
        let showById = Dictionary(uniqueKeysWithValues: allShows.map { ($0.id, $0) })
        let myShowById = Dictionary(uniqueKeysWithValues: myShows.map { ($0.showId, $0) })
        let myShowIds = Set(myShows.map(\.showId))
        let friendShowIds = Set(friend.watchedShowIds)
        let sharedIds = myShowIds.intersection(friendShowIds)
        var sharedShows = sharedIds.compactMap { showById[$0] }
        if let highlightedShowId, let index = sharedShows.firstIndex(where: { $0.id == highlightedShowId }) {
            let highlighted = sharedShows.remove(at: index)
            sharedShows.insert(highlighted, at: 0)
        }

        let myCategoryScores = categoryScores(
            shows: myShows.compactMap { myShow in
                showById[myShow.showId].map { (show: $0, score: myShow.score, weight: 1.0) }
            }
        )
        let friendCategoryScores = categoryScores(
            shows: friend.watchedShowIds.compactMap { showId in
                guard let show = showById[showId] else { return nil }
                return (
                    show: show,
                    score: friendScore(for: showId, friend: friend, activities: activities),
                    weight: showId == friend.currentShowId ? 1.0 : 0.76
                )
            }
        )

        let overlapRatio = Double(sharedIds.count) / Double(max(1, min(max(1, myShowIds.count), max(1, friendShowIds.count))))
        let categoryOverlap = weightedJaccard(myCategoryScores, friendCategoryScores)
        let ratingAlignment = ratingAlignment(
            sharedIds: sharedIds,
            myShowById: myShowById,
            friend: friend,
            activities: activities,
            myShows: myShows
        )
        let score = Int(round((overlapRatio * 0.40 + categoryOverlap * 0.38 + ratingAlignment * 0.22) * 100))
        let sharedGenres = strongestSharedGenres(myCategoryScores, friendCategoryScores)
        let label = label(for: score, sharedCount: sharedShows.count)
        let subtitle = subtitleText(score: score, sharedShows: sharedShows, sharedGenres: sharedGenres)
        let ratingLine = ratingLineText(ratingAlignment: ratingAlignment, sharedCount: sharedShows.count)

        return FriendTasteCompatibility(
            score: min(100, max(0, score)),
            label: label,
            subtitle: subtitle,
            sharedShows: Array(sharedShows.prefix(3)),
            sharedGenres: Array(sharedGenres.prefix(3)),
            ratingLine: ratingLine
        )
    }

    private static func label(for score: Int, sharedCount: Int) -> String {
        switch score {
        case 86...100: return "taste twin"
        case 70..<86:  return "strong taste match"
        case 52..<70:  return sharedCount > 0 ? "good overlap" : "same genre lane"
        case 32..<52:  return "different but compatible"
        default:       return "new taste orbit"
        }
    }

    private static func subtitleText(score: Int, sharedShows: [Show], sharedGenres: [String]) -> String {
        let genreText = sharedGenres.prefix(2).joined(separator: " + ")
        if !sharedShows.isEmpty {
            let count = sharedShows.count
            if genreText.isEmpty {
                return "\(count) shared show\(count == 1 ? "" : "s") in rotation."
            }
            return "\(count) shared show\(count == 1 ? "" : "s") across \(genreText)."
        }
        if !genreText.isEmpty {
            return "No shared shows yet, but both lean \(genreText)."
        }
        if score > 30 {
            return "Similar rating energy, different queues."
        }
        return "Watch something together to build compatibility."
    }

    private static func ratingLineText(ratingAlignment: Double, sharedCount: Int) -> String {
        if sharedCount > 0 {
            switch ratingAlignment {
            case 0.82...: return "ratings are closely aligned"
            case 0.58..<0.82: return "ratings mostly agree"
            default: return "ratings split in interesting ways"
            }
        }
        switch ratingAlignment {
        case 0.82...: return "similar average rating energy"
        case 0.58..<0.82: return "nearby rating energy"
        default: return "opposite rating energy"
        }
    }

    private static func categoryScores(shows: [(show: Show, score: Double, weight: Double)]) -> [String: Double] {
        var result: [String: Double] = [:]
        for item in shows {
            let scoreWeight = max(0.72, min(1.28, item.score / 3.6))
            for category in categories(for: item.show) {
                result[category, default: 0] += item.weight * scoreWeight
            }
        }
        return result
    }

    private static func categories(for show: Show) -> Set<String> {
        let text = [
            show.title,
            show.genre ?? "",
            show.platform,
            show.platforms?.joined(separator: " ") ?? ""
        ]
        .joined(separator: " ")
        .lowercased()

        var categories = Set<String>()
        if text.contains("sci-fi") || text.contains("science fiction") || text.contains("sci fi") {
            categories.insert("sci-fi")
        }
        if text.contains("drama") {
            categories.insert("drama")
        }
        if text.contains("comedy") || text.contains("sitcom") {
            categories.insert("comedy")
        }
        if text.contains("thriller") || text.contains("mystery") || text.contains("spy") {
            categories.insert("thriller")
        }
        if text.contains("crime") || text.contains("detective") {
            categories.insert("crime")
        }
        if text.contains("horror") || text.contains("dark") {
            categories.insert("dark")
        }
        if text.contains("historical") || text.contains("period") {
            categories.insert("historical")
        }
        if text.contains("anime") || show.isAnime {
            categories.insert("anime")
        }
        if text.contains("romance") || text.contains("romantic") {
            categories.insert("romance")
        }
        if categories.isEmpty {
            categories.insert("eclectic")
        }
        return categories
    }

    private static func weightedJaccard(_ lhs: [String: Double], _ rhs: [String: Double]) -> Double {
        let keys = Set(lhs.keys).union(rhs.keys)
        guard !keys.isEmpty else { return 0 }
        let intersection = keys.reduce(0) { $0 + min(lhs[$1, default: 0], rhs[$1, default: 0]) }
        let union = keys.reduce(0) { $0 + max(lhs[$1, default: 0], rhs[$1, default: 0]) }
        return union <= 0 ? 0 : intersection / union
    }

    private static func strongestSharedGenres(_ lhs: [String: Double], _ rhs: [String: Double]) -> [String] {
        Set(lhs.keys)
            .intersection(rhs.keys)
            .filter { $0 != "eclectic" }
            .sorted { first, second in
                let firstScore = min(lhs[first, default: 0], rhs[first, default: 0])
                let secondScore = min(lhs[second, default: 0], rhs[second, default: 0])
                if abs(firstScore - secondScore) < 0.001 { return first < second }
                return firstScore > secondScore
            }
    }

    private static func ratingAlignment(
        sharedIds: Set<Int>,
        myShowById: [Int: MyShow],
        friend: Friend,
        activities: [Activity],
        myShows: [MyShow]
    ) -> Double {
        let sharedAlignment = sharedIds.compactMap { showId -> Double? in
            guard let myScore = myShowById[showId]?.score, myScore > 0 else { return nil }
            let friendScore = friendScore(for: showId, friend: friend, activities: activities)
            return max(0, 1 - abs(myScore - friendScore) / 4.0)
        }
        if let average = sharedAlignment.average {
            return average
        }

        let myAverage = myShows.filter { $0.score > 0 }.map(\.score).average ?? 3.5
        return max(0, 1 - abs(myAverage - friend.score) / 4.0)
    }

    private static func friendScore(for showId: Int, friend: Friend, activities: [Activity]) -> Double {
        activities.first { $0.friendId == friend.id && $0.showId == showId }?.score ?? friend.score
    }
}

private struct FriendCompatibilityCard: View {
    let friend: Friend
    let compatibility: FriendTasteCompatibility
    var onOpenShow: (Show) -> Void

    private var accent: Color {
        switch compatibility.score {
        case 86...100: return Color(hex: "8FD28A")
        case 70..<86:  return Color(hex: "F0DDAF")
        case 52..<70:  return Color(hex: "75B8FF")
        case 32..<52:  return Color(hex: "B6C7FF")
        default:       return Color(hex: friend.hexColor)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: CGFloat(compatibility.score) / 100)
                        .stroke(accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(compatibility.score)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text("TV taste compatibility")
                        .font(StelrTypography.microLabel)
                        .tracking(1.5)
                        .foregroundStyle(.secondary.opacity(0.62))
                        .textCase(.uppercase)

                    Text(compatibility.label)
                        .font(StelrTypography.calloutStrong)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(compatibility.subtitle)
                        .font(StelrTypography.metadata)
                        .foregroundStyle(.secondary.opacity(0.70))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 10.2, weight: .semibold))
                Text(compatibility.ratingLine)
                    .font(StelrTypography.metadataStrong)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(accent.opacity(0.88))

            if !compatibility.sharedGenres.isEmpty {
                HStack(spacing: 7) {
                    ForEach(compatibility.sharedGenres, id: \.self) { genre in
                        Text(genre)
                            .font(StelrTypography.microLabel)
                            .foregroundStyle(accent.opacity(0.95))
                            .padding(.horizontal, 8)
                            .frame(height: 26)
                            .background(accent.opacity(0.10), in: Capsule(style: .continuous))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(accent.opacity(0.16), lineWidth: 0.6)
                            )
                    }

                    Spacer(minLength: 0)
                }
            }

            if compatibility.sharedShows.isEmpty {
                HStack(spacing: 7) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10.5, weight: .semibold))
                    Text("No overlap yet")
                        .font(StelrTypography.metadataStrong)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(accent.opacity(0.90))
                .padding(.horizontal, 9)
                .frame(height: 30)
                .background(accent.opacity(0.10), in: Capsule(style: .continuous))
            } else {
                HStack(spacing: 8) {
                    ForEach(compatibility.sharedShows) { show in
                        Button {
                            StelrHaptics.lightTap()
                            onOpenShow(show)
                        } label: {
                            HStack(spacing: 6) {
                                ShowPosterView(show: show, width: 22, height: 30, radius: 5) {
                                    EmptyView()
                                }
                                Text(show.title)
                                    .font(StelrTypography.metadataStrong)
                                    .foregroundStyle(.primary.opacity(0.86))
                                    .lineLimit(1)
                            }
                            .padding(.leading, 5)
                            .padding(.trailing, 8)
                            .frame(height: 34)
                            .background(Color.white.opacity(0.055), in: Capsule(style: .continuous))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 0.6)
                            )
                        }
                        .buttonStyle(.stelrPress)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(13)
        .background(
            LinearGradient(
                colors: [
                    accent.opacity(0.13),
                    Color.white.opacity(0.045)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 0.7)
        )
    }
}

private struct FriendProfileBanner: View {
    let title: String
    let subtitle: String
    let accentColor: Color
    let score: Double
    let vibe: VibeOption

    private var scoreText: String {
        String(format: "%.1f", CheckInStep.from(score).score)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.regular)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                VibeWaveView(vibe: vibe, score: score, size: 20)
                    .frame(width: 24, height: 24)

                Text(scoreText)
                    .font(.system(size: 12.2, weight: .bold, design: .rounded))
                    .foregroundColor(accentColor)
                    .monospacedDigit()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10.8, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(accentColor.opacity(0.12), in: Capsule())
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 9)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "2A1012").opacity(0.78),
                    Color(hex: "150B13").opacity(0.62)
                ],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accentColor.opacity(0.18), lineWidth: 0.8)
        )
    }
}

private struct FriendCurrentFlightSection: View {
    let show: Show
    let supportingShows: [Show]
    let vibe: VibeOption
    let score: Double
    var onOpenShow: (Show) -> Void

    private var ratingColor: Color {
        H7bStarVisualStyle.ratingColor(appScore: score)
    }
    private var scoreText: String {
        String(format: "%.1f", CheckInStep.from(score).score)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("IN FLIGHT")
                .font(.system(size: 11.8))
                .foregroundColor(.stelrMuted)
                .kerning(0.8)

            Button {
                onOpenShow(show)
            } label: {
                HStack(alignment: .top, spacing: 14) {
                    ShowPosterView(show: show, width: 78, height: 116, radius: 14)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(show.title)
                            .font(StelrTypography.sectionTitle)
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Text(show.platform)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            Text("\(vibe.emoji) \(vibe.label)")
                                .font(.system(size: 12.3))
                                .foregroundColor(ratingColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(ratingColor.opacity(0.12))
                                .clipShape(Capsule())

                            Text(scoreText)
                                .font(.system(size: 13.8, weight: .semibold, design: .rounded))
                                .foregroundColor(ratingColor)
                                .monospacedDigit()
                        }

                        Text("Open show details")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13.4, weight: .medium))
                        .foregroundColor(.stelrMuted)
                        .padding(.top, 2)
                }
                .padding(14)
                .background(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.stelrBorder, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.stelrPress)

            if !supportingShows.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("ALSO IN ROTATION")
                        .font(.system(size: 11.2))
                        .foregroundColor(.stelrMuted)
                        .kerning(0.8)

                    ForEach(supportingShows) { supportingShow in
                        FriendShowRow(
                            show: supportingShow,
                            vibe: vibe,
                            score: score,
                            color: ratingColor
                        ) {
                            onOpenShow(supportingShow)
                        }
                    }
                }
            }
        }
    }
}

private struct FriendShowRow: View {
    let show: Show
    let vibe: VibeOption
    let score: Double
    let color: Color
    var onTap: () -> Void

    private var scoreText: String {
        String(format: "%.1f", CheckInStep.from(score).score)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ShowPosterView(show: show, width: 58, height: 80, radius: 10)

                VStack(alignment: .leading, spacing: 6) {
                    Text(show.title)
                        .font(StelrTypography.sectionTitle)
                        .foregroundColor(.stelrText)

                    Text(show.platform)
                        .font(.system(size: 12.3))
                        .foregroundColor(.stelrMuted)

                    HStack(spacing: 6) {
                        VibeWaveView(vibe: vibe, score: score, size: 20)
                        Text(scoreText)
                            .font(.system(size: 12.1, weight: .semibold, design: .rounded))
                            .foregroundColor(color)
                            .monospacedDigit()
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13.4, weight: .medium))
                    .foregroundColor(.stelrMuted)
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.stelrBorder, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.stelrPress)
    }
}

private struct FriendEmptySection: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .ultraLight))
                .foregroundColor(.stelrMuted)

            Text(title)
                .font(StelrTypography.sectionTitle)
                .italic()
                .foregroundColor(.stelrMuted)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

private struct ConnectedShowRatingCard: View {
    let friendName: String
    let show: Show
    let vibe: VibeOption
    let score: Double
    let color: Color

    private var scoreText: String {
        String(format: "%.1f", CheckInStep.from(score).score)
    }

    var body: some View {
        HStack(spacing: 12) {
            VibeWaveView(vibe: vibe, score: score, size: 34, animate: true)
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text("connected through")
                    .font(.system(size: 11.2, weight: .medium))
                    .foregroundColor(.white.opacity(0.58))
                    .textCase(.uppercase)
                    .tracking(0.8)
                Text(show.title)
                    .font(StelrTypography.sectionTitle)
                    .foregroundColor(.stelrText)
                    .lineLimit(1)
                Text("\(friendName) rated this \(scoreText)")
                    .font(.system(size: 12.4, weight: .medium))
                    .foregroundColor(color.opacity(0.9))
            }

            Spacer(minLength: 8)

            Text(scoreText)
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .foregroundColor(color)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.34))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), color.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.7
                )
        )
        .shadow(color: .black.opacity(0.34), radius: 18, y: 10)
    }
}

private struct RatingActivityRow: View {
    let activity: Activity
    let friend: Friend
    let show: Show
    var onTap: () -> Void

    private var ratingScore: Double? {
        if let score = activity.score { return score }
        return activity.vibe == .notWatching ? nil : friend.score
    }

    private var ratingColor: Color {
        H7bStarVisualStyle.ratingColor(score: ratingScore, fallback: activity.vibe)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ShowPosterView(show: show, width: 44, height: 44, radius: 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(show.title)
                        .font(StelrTypography.sectionTitle)
                        .foregroundColor(.stelrText)
                        .lineLimit(1)
                    Text(activity.action)
                        .font(.system(size: 12.3))
                        .foregroundColor(.stelrMuted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(activity.vibe.emoji) \(activity.vibe.label)")
                        .font(.system(size: 12.3))
                        .foregroundColor(ratingColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(ratingColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Text(activity.timeAgo)
                        .font(.system(size: 9.5))
                        .foregroundColor(.stelrMuted)
                }
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(.stelrPress)
    }
}
