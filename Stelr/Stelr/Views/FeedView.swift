import SwiftUI

private enum ActivityTypography {

    // MARK: – Fonts (SF Pro / system only, Dynamic Type–compatible)

    /// Page header – "Activity"
    static let appTitle: Font = .system(size: 19, weight: .semibold, design: .default)
    /// Section pills – "PROBES", "TAKES" etc.
    static let sectionLabel: Font = .system(size: 10, weight: .medium, design: .default)
    /// Verb phrases – "checked in on", "started"
    static let activityPrimary: Font = .system(size: 12.5, weight: .regular, design: .default)
    /// Friend names
    static let activityName: Font = .system(size: 13, weight: .semibold, design: .default)
    /// Show titles
    static let showTitle: Font = .system(size: 13, weight: .semibold, design: .default)
    /// Quoted messages / probe captions
    static let activityQuote: Font = .system(size: 12, weight: .regular, design: .default)
    /// Timestamps, episode tags, vibe labels
    static let metadata: Font = .system(size: 10.5, weight: .regular, design: .default)
    /// Metadata that needs a nudge of emphasis (e.g. count pills, hint text)
    static let metadataEmphasized: Font = .system(size: 10.5, weight: .semibold, design: .default)
    /// Primary CTA buttons
    static let primaryButton: Font = .system(size: 12, weight: .semibold, design: .default)
    /// Secondary / ghost buttons
    static let secondaryButton: Font = .system(size: 12, weight: .semibold, design: .default)
    /// Emoji reactions – keep at body so they scale with Dynamic Type
    static let reactionEmoji: Font = .system(size: 12.5, weight: .regular, design: .default)

    // MARK: – Opacity
    // Named constants replace scattered inline literals.
    // All values are tuned for legibility over a dark glass background.

    enum Opacity {
        /// Full-weight primary content: names, active titles.
        static let primary: Double = 1.0
        /// Body secondary: verb phrases, supporting body text.
        static let bodySecondary: Double = 0.78
        /// Quoted message text and descriptions. Spec: 75–85 %.
        static let quote: Double = 0.82
        /// Section header labels and badge text.
        static let sectionLabel: Double = 0.60
        /// Metadata: timestamps, episode strings, vibe labels. Spec: 45–60 %.
        static let metadata: Double = 0.52
        /// Separator dots and decorative glyphs — recessive but visible.
        static let separator: Double = 0.34
        /// Secondary badge / count values.
        static let badge: Double = 0.45
    }

    // MARK: – Spacing (8 pt grid)

    enum Spacing {
        static let sectionLabelTracking: CGFloat = 1.2
        static let rowVertical: CGFloat = 4
        static let rowBottom: CGFloat = 8
        static let inlineGap: CGFloat = 3
    }
}

struct FeedView: View {
    var animateEntrance: Bool = true
    var animationToken: Int = 0
    var exitDownToken: Int = 0
    var showsBackdrop: Bool = true
    var onFriendTap: ((Friend) -> Void)? = nil

    @EnvironmentObject var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("hasSeenReactionHint") private var hasSeenReactionHint = false
    @State private var detailShow: Show?
    @State private var checkInShow: Show?
    @State private var appeared = false
    @State private var isFadingForTabExit = false
    @State private var reactionPickerState = ReactionPickerState()
    @State private var reactions: [Int: String] = [:]
    @State private var isShowingReactionHint = false
    @State private var isShowingMomentumNotifications = false

    private var ratingNudges: [RatingNudgeItem] {
        appState.myShows
            .filter(\.needsVibeCheck)
            .compactMap { myShow in
                appState.show(for: myShow.showId).map { RatingNudgeItem(myShow: myShow, show: $0) }
            }
    }

    private var watchMomentumItems: [WatchMomentumItem] {
        let recentActivities = Array(appState.activities.prefix(12))
        let recentShowCount = Set(recentActivities.map(\.showId)).count
        let currentShowPair = appState.myShows.first.flatMap { myShow in
            appState.show(for: myShow.showId).map { (myShow, $0) }
        }
        let streakPair = appState.myShows.compactMap { myShow in
            appState.coWatchStreaks(showId: myShow.showId).first.map { (myShow, $0) }
        }.first
        let collectionCount = appState.myLists.reduce(0) { $0 + $1.filledCount } + appState.watchlistShows.count
        let ratedShows = appState.myShows.filter { $0.score > 0 }
        let averageScore = ratedShows.isEmpty ? nil : ratedShows.reduce(0.0) { $0 + $1.score } / Double(ratedShows.count)
        let returnNudge = ratingNudges.first

        let seasonTitle: String
        let seasonSubtitle: String
        let seasonMetric: String
        let seasonAction: WatchMomentumAction
        if let (myShow, show) = currentShowPair {
            seasonTitle = show.title
            seasonSubtitle = "S\(myShow.currentSeason) · E\(myShow.currentEpisode)/\(myShow.totalEpisodes)"
            seasonMetric = "\(Int(min(100, round(Double(myShow.currentEpisode) / Double(max(1, myShow.totalEpisodes)) * 100))))%"
            seasonAction = .show(show)
        } else {
            seasonTitle = "Start a season"
            seasonSubtitle = "Check in to build season momentum."
            seasonMetric = "new"
            seasonAction = .none
        }

        let consistencyTitle: String
        let consistencySubtitle: String
        let consistencyMetric: String
        let consistencyAction: WatchMomentumAction
        if let (myShow, streak) = streakPair, let show = appState.show(for: myShow.showId) {
            consistencyTitle = "\(streak.friend.name) is in sync"
            consistencySubtitle = "\(show.title) · \(streak.label)"
            consistencyMetric = "\(streak.days)d"
            consistencyAction = .friend(streak.friend)
        } else {
            consistencyTitle = "No synced lane yet"
            consistencySubtitle = "Check in with friends to start consistency."
            consistencyMetric = "0d"
            consistencyAction = .none
        }

        let tasteTitle: String
        let tasteMetric: String
        let tasteAccent: String
        if let averageScore {
            let step = CheckInStep.from(averageScore)
            tasteTitle = "Mostly \(step.vibe.label)"
            tasteMetric = String(format: "%.1f", step.score)
            tasteAccent = step.coreHex
        } else {
            tasteTitle = "Taste profile warming up"
            tasteMetric = "new"
            tasteAccent = "F0DDAF"
        }

        let returnTitle: String
        let returnSubtitle: String
        let returnMetric: String
        let returnAction: WatchMomentumAction
        if let returnNudge {
            returnTitle = returnNudge.show.title
            returnSubtitle = "Last rated \(returnNudge.myShow.lastChecked)"
            returnMetric = "rate"
            returnAction = .rate(returnNudge.show)
        } else {
            returnTitle = "All caught up"
            returnSubtitle = "Return nudges appear when a show needs a fresh check-in."
            returnMetric = "clear"
            returnAction = .none
        }

        return [
            WatchMomentumItem(
                id: "weekly-activity",
                category: "weekly activity",
                title: "\(recentActivities.count) friend updates",
                subtitle: "Across \(recentShowCount) show\(recentShowCount == 1 ? "" : "s") in your orbit.",
                metric: "7d",
                systemName: "calendar",
                accentHex: "75B8FF",
                action: .none
            ),
            WatchMomentumItem(
                id: "season-momentum",
                category: "season momentum",
                title: seasonTitle,
                subtitle: seasonSubtitle,
                metric: seasonMetric,
                systemName: "play.square.stack",
                accentHex: currentShowPair?.1.accentColor ?? "E5604A",
                action: seasonAction
            ),
            WatchMomentumItem(
                id: "friend-consistency",
                category: "friend consistency",
                title: consistencyTitle,
                subtitle: consistencySubtitle,
                metric: consistencyMetric,
                systemName: "person.2.fill",
                accentHex: streakPair?.1.friend.hexColor ?? "8FD28A",
                action: consistencyAction
            ),
            WatchMomentumItem(
                id: "collection-milestones",
                category: "collection milestones",
                title: collectionCount > 0 ? "\(collectionCount) saved picks" : "Build your collection",
                subtitle: "Lists and Watch Later picks become collection milestones.",
                metric: "\(collectionCount)",
                systemName: "bookmark.fill",
                accentHex: "F0DDAF",
                action: .none
            ),
            WatchMomentumItem(
                id: "taste-evolution",
                category: "taste evolution",
                title: tasteTitle,
                subtitle: "Your ratings shape future recommendations and stars.",
                metric: tasteMetric,
                systemName: "sparkles",
                accentHex: tasteAccent,
                action: .none
            ),
            WatchMomentumItem(
                id: "return-nudges",
                category: "return nudges",
                title: returnTitle,
                subtitle: returnSubtitle,
                metric: returnMetric,
                systemName: "arrow.uturn.backward",
                accentHex: returnNudge?.show.accentColor ?? "C8D1FF",
                action: returnAction
            ),
        ]
    }

    private var momentumNotificationCount: Int {
        appState.pendingIncomingProbes.count + watchMomentumItems.count + ratingNudges.count
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if showsBackdrop {
                StelrFrostedBackdrop()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // ── Scrollable log ────────────────────────────────────────────
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header: mirrors constellation view header style
                    HStack(alignment: .center, spacing: 12) {
                        Text("Activity")
                            .font(ActivityTypography.appTitle)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer(minLength: 12)

                        Button {
                            StelrHaptics.lightTap()
                            isShowingMomentumNotifications = true
                        } label: {
                            MomentumNotificationsButton(count: momentumNotificationCount)
                        }
                        .buttonStyle(.stelrPress)
                        .accessibilityLabel("Open notifications")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 84)
                    .padding(.bottom, 20)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 44)
                    .animation(.spring(response: 0.58, dampingFraction: 0.70), value: appeared)

                    if isShowingReactionHint {
                        Text("Tap an update to react")
                            .font(ActivityTypography.metadataEmphasized)
                            .foregroundStyle(.secondary.opacity(ActivityTypography.Opacity.sectionLabel))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 12)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 44)
                            .animation(
                                .spring(response: 0.58, dampingFraction: 0.70).delay(0.04),
                                value: appeared
                            )
                            .transition(.opacity)
                    }

                    // Timeline
                    starTimeline

                Spacer(minLength: 240)
                }
            }
            .ignoresSafeArea(edges: .top)
            .opacity(isFadingForTabExit ? 0 : 1)
            .animation(.easeOut(duration: 0.26), value: isFadingForTabExit)
        }
        .onAppear {
            runEntranceAnimation()
            showReactionHintIfNeeded()
        }
        .onChange(of: animationToken) { _, _ in runEntranceAnimation() }
        .onChange(of: exitDownToken) { _, _ in runExitDownAnimation() }
        .sheet(item: $detailShow) { show in
            ShowDetailView(show: show, watchingFriends: appState.friendsWatching(showId: show.id))
        }
        .sheet(item: $checkInShow) { show in
            VibeCheckSheet(show: show, currentMyShow: appState.myShow(for: show.id)) { season, episode, score in
                appState.submitCheckIn(show: show, season: season, episode: episode, score: score)
            } onSeasonRating: { season, rating in
                appState.submitSeasonRating(showId: show.id, season: season, score: rating)
            }
        }
        .sheet(isPresented: $isShowingMomentumNotifications) {
            momentumNotificationsSheet
        }
    }

    // MARK: - Timeline

    private var starTimeline: some View {
        let entries: [(Int, Activity, Friend, Show)] = appState.activities
            .enumerated()
            .compactMap { idx, act in
                guard let friend = appState.friend(for: act.friendId),
                      let show   = appState.show(for: act.showId) else { return nil }
                return (idx, act, friend, show)
            }

        return VStack(alignment: .leading, spacing: 0) {
            ForEach(entries, id: \.1.id) { idx, act, friend, show in
                StarLogRow(
                    index: idx,
                    activity: act,
                    friend: friend,
                    show: show,
                    appeared: appeared,
                    selectedReaction: reactions[act.id],
                    isReactionPickerPresented: reactionPickerState.selectedActivityID == act.id,
                    isReactionAnimating: reactionPickerState.animatingActivityID == act.id,
                    reduceMotion: reduceMotion,
                    onTapFriend: { onFriendTap?(friend) },
                    onTapShow: { detailShow = show },
                    onToggleReactions: { showReactionPicker(for: act.id) },
                    onSelectReaction: { emoji in selectReaction(emoji, for: act.id) },
                    onMoreReactions: { openMoreReactions(for: act.id) }
                )
            }
        }
        .padding(.horizontal, 22)
    }

    // MARK: - Animation

    private func runEntranceAnimation() {
        isFadingForTabExit = false
        appeared = false
        if animateEntrance {
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.74).delay(0.06)) {
                    appeared = true
                }
            }
        } else {
            var tx = Transaction()
            tx.disablesAnimations = true
            withTransaction(tx) { appeared = true }
        }
    }

    private func runExitDownAnimation() {
        withAnimation(.easeOut(duration: 0.26)) {
            isFadingForTabExit = true
        }
    }

    private func showReactionHintIfNeeded() {
        guard !hasSeenReactionHint else { return }
        withAnimation(.easeOut(duration: 0.22).delay(0.25)) {
            isShowingReactionHint = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            withAnimation(.easeOut(duration: 0.24)) {
                isShowingReactionHint = false
            }
            hasSeenReactionHint = true
        }
    }

    private func showReactionPicker(for activityID: Int) {
        StelrHaptics.lightTap()
        withAnimation(.spring(response: 0.22, dampingFraction: 0.88)) {
            reactionPickerState.selectedActivityID = reactionPickerState.selectedActivityID == activityID ? nil : activityID
        }
    }

    private func selectReaction(_ emoji: String, for activityID: Int) {
        StelrHaptics.softTap()
        withAnimation(.easeOut(duration: 0.16)) {
            reactions[activityID] = emoji
            reactionPickerState.selectedActivityID = nil
            reactionPickerState.animatingActivityID = reduceMotion ? nil : activityID
        }

        guard !reduceMotion else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.62)) {
                reactionPickerState.animatingActivityID = nil
            }
        }
    }

    private func openMoreReactions(for activityID: Int) {
        // SwiftUI does not expose a system emoji picker; keep the compact picker open.
        StelrHaptics.lightTap()
        withAnimation(.spring(response: 0.20, dampingFraction: 0.9)) {
            reactionPickerState.selectedActivityID = activityID
        }
    }

    // MARK: - Momentum notifications

    private var momentumNotificationsSheet: some View {
        ZStack {
            StelrFrostedBackdrop()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    momentumSheetHeader

                    if momentumNotificationCount == 0 {
                        MomentumEmptyState()
                            .padding(.horizontal, 22)
                            .padding(.top, 8)
                    } else {
                        if !appState.pendingIncomingProbes.isEmpty {
                            incomingProbesSection
                        }

                        watchMomentumSection

                        if !ratingNudges.isEmpty {
                            ratingNudgesSection
                        }
                    }

                    Spacer(minLength: 28)
                }
                .padding(.top, 24)
                .padding(.bottom, 42)
            }
        }
        .presentationDetents([.height(560), .large])
        .presentationDragIndicator(.visible)
    }

    private var momentumSheetHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Notifications")
                    .font(ActivityTypography.appTitle)
                    .foregroundStyle(.primary)

                Text("Probes and watch momentum live here.")
                    .font(ActivityTypography.metadata)
                    .foregroundStyle(.secondary.opacity(0.62))
            }

            Spacer(minLength: 10)

            if momentumNotificationCount > 0 {
                Text("\(momentumNotificationCount)")
                    .font(ActivityTypography.metadataEmphasized)
                    .foregroundStyle(Color(hex: "0A0A14"))
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(Color.stelrAccent, in: Capsule(style: .continuous))
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Watch momentum

    private var watchMomentumSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 5) {
                Image(systemName: "orbit")
                    .font(.system(size: 9.5, weight: .semibold))
                Text("watch momentum")
                    .font(ActivityTypography.sectionLabel)
                    .tracking(ActivityTypography.Spacing.sectionLabelTracking)
            }
            .foregroundStyle(.secondary.opacity(0.58))
            .padding(.horizontal, 24)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(watchMomentumItems) { item in
                    WatchMomentumCard(item: item) {
                        handleWatchMomentumTap(item)
                    }
                }
            }
            .padding(.horizontal, 22)
        }
    }

    private func handleWatchMomentumTap(_ item: WatchMomentumItem) {
        StelrHaptics.lightTap()
        switch item.action {
        case .none:
            break
        case .show(let show):
            detailShow = show
        case .friend(let friend):
            onFriendTap?(friend)
        case .rate(let show):
            checkInShow = show
        }
    }

    // MARK: - Rating nudges

    private var ratingNudgesSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Image(systemName: "sparkle")
                    .font(.system(size: 9.5, weight: .semibold))
                Text("rate when ready")
                    .font(ActivityTypography.sectionLabel)
                    .tracking(ActivityTypography.Spacing.sectionLabelTracking)
            }
            .foregroundStyle(.secondary.opacity(0.58))
            .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ratingNudges) { item in
                        RatingNudgeCard(item: item) {
                            StelrHaptics.lightTap()
                            checkInShow = item.show
                        }
                    }
                }
                .padding(.horizontal, 22)
            }
        }
    }

    // MARK: - Incoming probes section

    private var incomingProbesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 8) {
                ForEach(appState.pendingIncomingProbes) { probe in
                    if let fromFriend = appState.friend(for: probe.fromFriendId),
                       let show = appState.show(for: probe.showId) {
                        IncomingProbeCard(
                            probe: probe,
                            fromFriend: fromFriend,
                            show: show,
                            onTapFriend: {
                                onFriendTap?(fromFriend)
                            },
                            onAccept: {
                                StelrHaptics.success()
                                appState.acceptProbe(probe.id)
                                detailShow = show
                            },
                            onDeny: {
                                StelrHaptics.lightTap()
                                appState.denyProbe(probe.id)
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 22)
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: appState.pendingIncomingProbes.count)
    }
}

// MARK: - Shared frosted backdrop

struct StelrFrostedBackdrop: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)

            LinearGradient(
                colors: [
                    Color(hex: "020611").opacity(0.16),
                    Color(hex: "020611").opacity(0.08),
                    Color(hex: "1A0908").opacity(0.14)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color.stelrAccent.opacity(0.055),
                    .clear
                ],
                center: UnitPoint(x: 0.50, y: 0.92),
                startRadius: 40,
                endRadius: 360
            )
            .blendMode(.softLight)
        }
    }
}

// MARK: - Momentum notifications

private struct MomentumNotificationsButton: View {
    let count: Int

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "sparkles")
                .font(.system(size: 10.5, weight: .semibold))

            Text("Notifications")
                .font(ActivityTypography.metadataEmphasized)
                .lineLimit(1)

            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 9.5, weight: .bold, design: .default))
                    .foregroundStyle(Color(hex: "0A0A14"))
                    .padding(.horizontal, 6)
                    .frame(height: 17)
                    .background(Color.stelrAccent, in: Capsule(style: .continuous))
            }
        }
        .foregroundStyle(.primary.opacity(0.86))
        .padding(.leading, 10)
        .padding(.trailing, count > 0 ? 6 : 10)
        .frame(height: 32)
        .background(Color.white.opacity(0.075), in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 0.7)
        )
    }
}

private struct MomentumEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.stelrAccent.opacity(0.82))

            Text("No notifications right now")
                .font(ActivityTypography.showTitle)
                .foregroundStyle(.primary.opacity(0.90))

            Text("New probes, streaks, achievements, and rate nudges will collect here.")
                .font(ActivityTypography.metadata)
                .foregroundStyle(.secondary.opacity(0.62))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.7)
        )
    }
}

private enum WatchMomentumAction {
    case none
    case show(Show)
    case friend(Friend)
    case rate(Show)
}

private struct WatchMomentumItem: Identifiable {
    let id: String
    let category: String
    let title: String
    let subtitle: String
    let metric: String
    let systemName: String
    let accentHex: String
    let action: WatchMomentumAction

    var accent: Color {
        Color(hex: accentHex)
    }
}

private struct WatchMomentumCard: View {
    let item: WatchMomentumItem
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .center, spacing: 7) {
                    Image(systemName: item.systemName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(item.accent)
                        .frame(width: 24, height: 24)
                        .background(item.accent.opacity(0.12), in: Circle())

                    Text(item.metric)
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundStyle(item.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.category)
                        .font(.system(size: 9.2, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(.secondary.opacity(0.50))
                        .textCase(.uppercase)
                        .lineLimit(1)

                    Text(item.title)
                        .font(ActivityTypography.showTitle)
                        .foregroundStyle(.primary.opacity(0.92))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(item.subtitle)
                        .font(ActivityTypography.metadata)
                        .foregroundStyle(.secondary.opacity(0.58))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
            .padding(11)
            .background(
                LinearGradient(
                    colors: [
                        item.accent.opacity(0.12),
                        Color.white.opacity(0.045)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(item.accent.opacity(0.16), lineWidth: 0.7)
            )
        }
        .buttonStyle(.stelrPress)
    }
}

// MARK: - Rating nudge card

private struct RatingNudgeItem: Identifiable {
    let myShow: MyShow
    let show: Show

    var id: Int { myShow.id }
}

private struct RatingNudgeCard: View {
    let item: RatingNudgeItem
    var onRate: () -> Void

    var body: some View {
        Button(action: onRate) {
            HStack(spacing: 8) {
                ShowPosterView(show: item.show, width: 28, height: 40, radius: 6) {
                    EmptyView()
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.6)
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.show.title)
                        .font(ActivityTypography.showTitle)
                        .foregroundStyle(.primary.opacity(0.88))
                        .lineLimit(1)

                    Text("last rated \(item.myShow.lastChecked)")
                        .font(ActivityTypography.metadata)
                        .foregroundStyle(.secondary.opacity(0.56))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                HStack(spacing: 5) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 10.5, weight: .semibold))
                    Text("Check in")
                        .font(ActivityTypography.primaryButton)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Color.stelrAccent, in: Capsule(style: .continuous))
                .shadow(color: Color.stelrAccent.opacity(0.22), radius: 8, y: 4)
            }
            .frame(width: 236, alignment: .leading)
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 0.6)
            )
        }
        .buttonStyle(.stelrPress)
        .accessibilityLabel("Rate \(item.show.title)")
    }
}

// MARK: - Milestone rail card

private struct MilestoneRailCard: View {
    let milestone: Milestone
    let show: Show?
    let friend: Friend?
    var onTap: () -> Void

    private var accent: Color {
        Color(hex: milestone.accentHex)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 9) {
                milestoneArtwork

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Image(systemName: milestone.systemImage)
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(accent)
                        Text(milestone.badge)
                            .font(ActivityTypography.metadataEmphasized)
                            .foregroundStyle(accent)
                    }

                    Text(milestone.title)
                        .font(ActivityTypography.showTitle)
                        .foregroundStyle(.primary.opacity(0.92))
                        .lineLimit(1)

                    Text(milestone.subtitle)
                        .font(ActivityTypography.metadata)
                        .foregroundStyle(.secondary.opacity(0.58))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .frame(width: 246, alignment: .leading)
            .padding(9)
            .background(
                LinearGradient(
                    colors: [
                        accent.opacity(0.13),
                        Color.white.opacity(0.045)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(accent.opacity(0.18), lineWidth: 0.7)
            )
        }
        .buttonStyle(.stelrPress)
    }

    @ViewBuilder
    private var milestoneArtwork: some View {
        if let show {
            ShowPosterView(show: show, width: 34, height: 46, radius: 7) {
                EmptyView()
            }
            .overlay(alignment: .bottomTrailing) {
                if let friend {
                    AvatarView(initials: friend.initials, hexColor: friend.hexColor, imageURL: friend.imageURL, size: 17)
                        .offset(x: 4, y: 4)
                }
            }
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(accent.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(accent.opacity(0.22), lineWidth: 0.7)
                    )
                Image(systemName: milestone.systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .frame(width: 34, height: 46)
        }
    }
}

// MARK: - Incoming probe card

private struct IncomingProbeCard: View {
    let probe: ProbeRequest
    let fromFriend: Friend
    let show: Show
    let onTapFriend: () -> Void
    let onAccept: () -> Void
    let onDeny: () -> Void

    @State private var dismissed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Who & when
            HStack(spacing: 7) {
                Button {
                    StelrHaptics.lightTap()
                    onTapFriend()
                } label: {
                    AvatarView(initials: fromFriend.initials, hexColor: fromFriend.hexColor, imageURL: fromFriend.imageURL, size: 22)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(fromFriend.name)
                            .font(ActivityTypography.showTitle)
                            .foregroundStyle(.primary)
                        Text("sent you a probe")
                            .font(ActivityTypography.metadata)
                            .foregroundStyle(.secondary.opacity(ActivityTypography.Opacity.bodySecondary))
                    }
                    Text(probe.timeAgo)
                        .font(ActivityTypography.metadata)
                        .foregroundStyle(.secondary.opacity(ActivityTypography.Opacity.metadata))
                }

                Spacer()

                probeBadge

                // Show accent dot
                ShowPosterView(show: show, width: 26, height: 36, radius: 5) {
                    EmptyView()
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color(hex: show.accentColor).opacity(0.28), lineWidth: 0.7)
                )
                .shadow(color: .black.opacity(0.24), radius: 4, y: 2)
            }

            // Show name + message
            VStack(alignment: .leading, spacing: 3) {
                Text(show.title)
                    .font(ActivityTypography.activityName)
                    .foregroundStyle(Color(hex: show.accentColor))

                if let message = probe.message, !message.isEmpty {
                    Text("\"\(message)\"")
                        .font(ActivityTypography.metadata)
                        .foregroundStyle(.secondary.opacity(ActivityTypography.Opacity.quote))
                        .lineSpacing(1)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Accept / Deny
            HStack(spacing: 7) {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.80)) {
                        dismissed = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                        onDeny()
                    }
                } label: {
                    Text("Pass")
                        .font(ActivityTypography.secondaryButton)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.07), lineWidth: 0.6)
                        )
                }
                .buttonStyle(.stelrPress)

                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.80)) {
                        dismissed = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                        onAccept()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bookmark")
                            .font(ActivityTypography.primaryButton)
                        Text("Watch it")
                            .font(ActivityTypography.primaryButton)
                    }
                    .foregroundColor(Color(hex: "0a0a14"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(Color(hex: show.accentColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: Color(hex: show.accentColor).opacity(0.18), radius: 6, y: 3)
                }
                .buttonStyle(.stelrPress)
            }
        }
        .padding(9)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .background(Color(hex: "030810").opacity(0.28), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(hex: show.accentColor).opacity(0.22),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: Color(hex: show.accentColor).opacity(0.04), radius: 10, y: 5)
        .shadow(color: .black.opacity(0.16), radius: 7, y: 3)
        .scaleEffect(dismissed ? 0.94 : 1)
        .opacity(dismissed ? 0 : 1)
    }

    private var probeBadge: some View {
        HStack(spacing: 4) {
            SputnikProbeIcon()
                .frame(width: 10, height: 10)
            Text("Probe")
                .font(ActivityTypography.metadataEmphasized)
        }
        .foregroundStyle(Color(hex: show.accentColor).opacity(0.82))
        .padding(.horizontal, 7)
        .frame(height: 22)
        .background(Color(hex: show.accentColor).opacity(0.10), in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color(hex: show.accentColor).opacity(0.16), lineWidth: 0.6)
        )
    }
}

// MARK: - Star log row

private struct ReactionPickerState {
    var selectedActivityID: Int?
    var animatingActivityID: Int?
}

private struct ActivityReaction: Identifiable, Equatable {
    let emoji: String
    let label: String

    var id: String { emoji }

    static let options: [ActivityReaction] = [
        ActivityReaction(emoji: "🔥", label: "Fire"),
        ActivityReaction(emoji: "👀", label: "Watching"),
        ActivityReaction(emoji: "😭", label: "Crying"),
        ActivityReaction(emoji: "😬", label: "Tense"),
        ActivityReaction(emoji: "🙂", label: "Nice"),
        ActivityReaction(emoji: "⭐", label: "Star"),
    ]
}

private struct StarLogRow: View {
    let index: Int
    let activity: Activity
    let friend: Friend
    let show: Show
    let appeared: Bool
    let selectedReaction: String?
    let isReactionPickerPresented: Bool
    let isReactionAnimating: Bool
    let reduceMotion: Bool
    var onTapFriend: () -> Void
    var onTapShow: () -> Void
    var onToggleReactions: () -> Void
    var onSelectReaction: (String) -> Void
    var onMoreReactions: () -> Void

    // Each row floats up from the planet: starts low, rises to position
    private var entranceDelay: Double { Double(index) * 0.075 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // ── Star bullet ───────────────────────────────────────────
                ZStack {
                    // Soft glow halo behind the star
                    Circle()
                        .fill(Color.white.opacity(0.09))
                        .frame(width: 14, height: 14)
                        .blur(radius: 4)

                    StelrFourPointStar(variant: .twinkle)
                        .fill(Color.white.opacity(0.78))
                        .frame(width: 10, height: 10)
                }
                .frame(width: 11, height: 11)
                .padding(.top, 8)

                // ── Log text ──────────────────────────────────────────────
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        // Primary line: name · action · show
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Button(action: onTapFriend) {
                                Text(friend.name)
                                    .font(ActivityTypography.activityName)
                                    .foregroundStyle(.primary)
                            }
                            .buttonStyle(.stelrPress)

                            Text("  \(activity.action)  ")
                                .font(ActivityTypography.activityPrimary)
                                .foregroundStyle(.secondary.opacity(ActivityTypography.Opacity.bodySecondary))

                            Button(action: onTapShow) {
                                Text(show.title)
                                    .font(ActivityTypography.showTitle)
                                    .foregroundStyle(Color(hex: show.accentColor).opacity(0.92))
                                    .lineLimit(1)
                            }
                            .buttonStyle(.stelrPress)
                        }

                        // Secondary line: episode + vibe + selected reaction
                        HStack(spacing: ActivityTypography.Spacing.inlineGap) {
                            Text(show.currentEpisode)
                                .font(ActivityTypography.metadata)
                                .foregroundStyle(.secondary.opacity(ActivityTypography.Opacity.metadata))

                            Text("·")
                                .font(ActivityTypography.metadata)
                                .foregroundStyle(.secondary.opacity(ActivityTypography.Opacity.separator))

                            Text("\(activity.vibe.emoji)  \(activity.vibe.label)")
                                .font(ActivityTypography.metadata)
                                .foregroundStyle(.secondary.opacity(ActivityTypography.Opacity.metadata))

                            if let selectedReaction {
                                Text(selectedReaction)
                                    .font(ActivityTypography.reactionEmoji)
                                    .scaleEffect(isReactionAnimating && !reduceMotion ? 1.08 : 1.0)
                                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                                    .accessibilityLabel("Reaction \(selectedReaction)")
                            } else if isReactionPickerPresented {
                                Text("+")
                                    .font(ActivityTypography.metadataEmphasized)
                                    .foregroundStyle(.secondary.opacity(ActivityTypography.Opacity.metadata))
                                    .transition(.opacity)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(activity.timeAgo)
                        .font(ActivityTypography.metadata)
                        .foregroundStyle(.secondary.opacity(ActivityTypography.Opacity.metadata))
                        .lineLimit(1)
                }
                .padding(.top, ActivityTypography.Spacing.rowVertical)
                .padding(.bottom, isReactionPickerPresented ? ActivityTypography.Spacing.rowVertical : ActivityTypography.Spacing.rowBottom)
            }

            if isReactionPickerPresented {
                ReactionBar(
                    onSelect: onSelectReaction,
                    onMore: onMoreReactions
                )
                .padding(.leading, 38)
                .padding(.bottom, 8)
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: reduceMotion ? 1.0 : 0.92, anchor: .topLeading).combined(with: .opacity),
                        removal: .scale(scale: reduceMotion ? 1.0 : 0.96, anchor: .topLeading).combined(with: .opacity)
                    )
                )
                .zIndex(8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.white.opacity(isReactionPickerPresented ? 0.035 : 0))
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggleReactions)
        .onLongPressGesture(minimumDuration: 0.32) {
            onToggleReactions()
        }
        .accessibilityLabel("React to activity")
        .accessibilityHint("Tap or touch and hold for reactions")
        // Float-up entrance: rows rise from the planet surface one at a time
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 44)
        .animation(
            .spring(response: 0.58, dampingFraction: 0.70)
                .delay(entranceDelay),
            value: appeared
        )
    }
}

private struct ReactionBar: View {
    var onSelect: (String) -> Void
    var onMore: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ActivityReaction.options) { option in
                Button {
                    onSelect(option.emoji)
                } label: {
                    Text(option.emoji)
                        .font(ActivityTypography.reactionEmoji)
                        .frame(width: 24, height: 24)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.label)
            }

            Button(action: onMore) {
                Text("+")
                    .font(ActivityTypography.metadataEmphasized)
                    .foregroundStyle(.secondary.opacity(ActivityTypography.Opacity.bodySecondary))
                    .frame(width: 24, height: 24)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More reactions")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.black.opacity(0.22), in: Capsule(style: .continuous))
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.065), lineWidth: 0.7)
        )
        .clipShape(Capsule(style: .continuous))
        .shadow(color: .black.opacity(0.20), radius: 10, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("React to activity")
    }
}
