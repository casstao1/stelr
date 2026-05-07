import SwiftUI

// MARK: - Private data types

private struct ShowNode {
    let show: Show
    let pos: CGPoint
    let watchers: [Friend]
    let audienceCount: Int
    let starStep: CheckInStep
    let myShow: MyShow?
    var isShared: Bool { audienceCount > 1 }
}

private struct FriendInstance: Identifiable {
    let id: String          // "\(friendId)-\(showId)"
    let friend: Friend?
    let showId: Int
    let pos: CGPoint
    let isCurrentUser: Bool

    func withPosition(_ pos: CGPoint) -> FriendInstance {
        FriendInstance(id: id, friend: friend, showId: showId, pos: pos, isCurrentUser: isCurrentUser)
    }
}

private struct PendingConstellationCheckIn {
    let show: Show
    let season: Int?
    let episode: Int?
    let score: Double
}

private struct ShowStreakConnection: Identifiable {
    let fromShowId: Int
    let toShowId: Int

    var id: String { "\(fromShowId)-\(toShowId)" }
}

// MARK: - Main view

struct ConstellationView: View {
    var animateEntrance: Bool = true
    var animationToken: Int = 0
    var exitDownToken: Int = 0
    var launchPhase: UniverseLaunchPhase? = nil
    var onFriendTap: (Friend, Int) -> Void = { _, _ in }

    @EnvironmentObject var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selShowId:   Int? = nil
    @State private var selFriendId: Int? = nil
    @State private var appeared = false
    @State private var detailShow: Show? = nil
    @State private var checkInShow: Show? = nil
    @State private var pendingCheckIn: PendingConstellationCheckIn? = nil
    @State private var freshCheckInShowId: Int? = nil
    @State private var pulsingFriendInstanceId: String? = nil
    @State private var starMotionEnabled = false
    @State private var spaceZoomPhase: ElegantSpaceZoomPhase = .idle
    @State private var spaceZoomSeed = 0
    @State private var spaceZoomOrigin: CGPoint? = nil
    @State private var spaceZoomShow: Show? = nil
    @State private var detailRevealVisible = false
    @State private var isExitingDown = false
    @State private var activeShootingStar: ShootingStarEvent? = nil
    @State private var shootingStarFrozen = false

    private let maxVisibleShows = 12

    // Ranked top-to-bottom slots. Higher glow/rating/activity shows are assigned to
    // the upper half; lower-ranked shows naturally settle closer to the planet.
    private let rankedFracs: [(CGFloat, CGFloat)] = [
        (0.50, 0.12),
        (0.18, 0.25),
        (0.86, 0.27),
        (0.38, 0.44),
        (0.78, 0.51),
        (0.12, 0.66),
        (0.91, 0.73),
        (0.52, 0.84),
    ]
    // Max jitter radius per slot (fraction of safe area). Outer slots get less horizontal
    // room so they don't drift into the clipping inset; center has the most freedom.
    private let slotJitter: [(x: CGFloat, y: CGFloat)] = [
        (0.17, 0.18),  // center
        (0.10, 0.10),  // top-left
        (0.10, 0.12),  // top-right
        (0.11, 0.11),  // bottom-left
        (0.10, 0.13),  // bottom-right
        (0.08, 0.14),  // mid-left
        (0.08, 0.15),  // mid-right
        (0.14, 0.13),  // mid-center
    ]
    // Safe insets keep every node (and its orbit bubbles) inside the visible canvas.
    private let topSafeInset:    CGFloat = 108
    private let bottomSafeInset: CGFloat = 318
    private let sideSafeInset:   CGFloat = 34
    private let constellationYOffset: CGFloat = 26
    private let minLayoutFractionX: CGFloat = 0.08
    private let maxLayoutFractionX: CGFloat = 0.92
    private let minLayoutFractionY: CGFloat = 0.10
    private let maxLayoutFractionY: CGFloat = 0.84
    // Orbit radius = 56 pt on 390 wide → fraction
    private let orbitFrac: CGFloat = 56 / 390
    private let preferredStreakConnections: [ShowStreakConnection] = [
        ShowStreakConnection(fromShowId: 0, toShowId: 4),
        ShowStreakConnection(fromShowId: 4, toShowId: 3),
        ShowStreakConnection(fromShowId: 3, toShowId: 1),
        ShowStreakConnection(fromShowId: 2, toShowId: 1),
        ShowStreakConnection(fromShowId: 0, toShowId: 2),
    ]

    var body: some View {
        GeometryReader { geo in
            let nodes = buildNodes(size: geo.size)
            let instances: [FriendInstance] = []
            let nodeByShowId: [Int: ShowNode] = [:]

            ZStack {
                orbitalCanvas(size: geo.size, nodes: nodes, instances: instances, nodeByShowId: nodeByShowId)
                    .scaleEffect(selectionFocusScale, anchor: selectionZoomAnchor(size: geo.size, nodes: nodes))
                    .scaleEffect(sceneScale(for: spaceZoomPhase))
                    .opacity(spaceZoomPhase == .idle ? 1 : 0.70)
                    .animation(.spring(response: 0.46, dampingFraction: 0.86), value: selShowId)
                    .animation(.easeInOut(duration: spaceZoomPhase == .travel ? ElegantSpaceZoomTuning.default.cameraPushDuration : ElegantSpaceZoomTuning.default.focusDuration), value: spaceZoomPhase)
                headerOverlay
                    .opacity(isExitingDown ? 0 : headerLaunchOpacity * (spaceZoomPhase == .idle ? 1 : 0.42))
                    .animation(.easeOut(duration: 0.18), value: spaceZoomPhase)
                    .animation(.easeOut(duration: 0.22), value: isExitingDown)
                if detailShow == nil && spaceZoomPhase == .idle {
                    selectedShowDetailOverlay(size: geo.size, nodes: nodes, instances: instances)
                }
                if detailShow == nil,
                   !isExitingDown,
                   spaceZoomPhase == .idle,
                   let star = activeShootingStar {
                    SeasonCompletionShootingStarOverlay(
                        event: star,
                        isFrozen: shootingStarFrozen
                    ) {
                        handleShootingStarTap(show: star.show)
                    }
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(34)
                }
                if let show = detailShow {
                    ShowDetailView(show: show, watchingFriends: appState.friendsWatching(showId: show.id)) {
                        closeInlineDetail()
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(detailRevealVisible ? 1 : 0)
                    .offset(y: detailRevealVisible ? 0 : SpaceGlideTuning.default.uiRevealOffset)
                    .animation(.spring(response: 0.40, dampingFraction: 0.84), value: detailRevealVisible)
                    .zIndex(40)
                }
                if spaceZoomPhase != .idle {
                    ElegantSpaceZoomTransition(
                        phase: spaceZoomPhase,
                        seed: spaceZoomSeed,
                        origin: spaceZoomOrigin
                    )
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .zIndex(50)
                    if let show = spaceZoomShow {
                        SpaceGlideTransitionView(
                            show: show,
                            phase: spaceZoomPhase,
                            origin: spaceZoomOrigin,
                            detailVisible: detailRevealVisible,
                            watchers: appState.friendsWatching(showId: show.id)
                        )
                        .ignoresSafeArea()
                        .zIndex(60)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        clearSelectionIfBackgroundTap(
                            at: value.location,
                            size: geo.size,
                            nodes: nodes,
                            instances: instances
                        )
                    }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .sheet(item: $checkInShow) { show in
            VibeCheckSheet(show: show, currentMyShow: appState.myShow(for: show.id)) { season, episode, score in
                pendingCheckIn = PendingConstellationCheckIn(show: show, season: season, episode: episode, score: score)
                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                    selShowId = nil
                    selFriendId = nil
                }
            } onSeasonRating: { season, rating in
                appState.submitSeasonRating(showId: show.id, season: season, score: rating)
            }
        }
        .onChange(of: checkInShow?.id) { _, newValue in
            if newValue == nil {
                commitPendingCheckIn()
            }
        }
        .onChange(of: appState.constellationPulseEvent?.id) { _, _ in
            handleConstellationPulseEvent()
        }
        .onAppear {
            dequeueNextShootingStar(delay: 1.05)
        }
        .onChange(of: animationToken) { _, _ in
            dequeueNextShootingStar(delay: 1.05)
        }
        .onChange(of: detailShow) { _, newValue in
            // After closing a show that was opened via shooting-star tap, try the next one
            if newValue == nil {
                dequeueNextShootingStar(delay: 1.4)
            }
        }
        .onChange(of: launchPhase) { _, newPhase in
            handleLaunchPhaseChange(newPhase)
        }
    }

    private func orbitalCanvas(
        size: CGSize,
        nodes: [ShowNode],
        instances: [FriendInstance],
        nodeByShowId: [Int: ShowNode]
    ) -> some View {
        ZStack {
            showNodeLayer(nodes: nodes, size: size)
        }
        .frame(width: size.width, height: size.height)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: selShowId)
        .onAppear {
            runEntranceAnimation(animated: animateEntrance)
        }
        .onDisappear {
            starMotionEnabled = false
        }
        .onChange(of: animationToken) { _, _ in
            runEntranceAnimation(animated: animateEntrance)
        }
        .onChange(of: exitDownToken) { _, _ in
            runExitDownAnimation()
        }
    }

    private func showStreakLayer(size: CGSize, nodes: [ShowNode]) -> some View {
        let nodeById = nodes.reduce(into: [Int: ShowNode]()) { $0[$1.show.id] = $1 }
        let visibleConnections = preferredStreakConnections.filter {
            nodeById[$0.fromShowId] != nil && nodeById[$0.toShowId] != nil
        }

        return ZStack {
            ForEach(visibleConnections) { connection in
                if let start = nodeById[connection.fromShowId]?.pos,
                   let end = nodeById[connection.toShowId]?.pos {
                    Path { path in
                        path.move(to: start)
                        path.addLine(to: end)
                    }
                    .stroke(
                        showStreakColor(for: connection),
                        style: StrokeStyle(lineWidth: 0.55, lineCap: .round)
                    )
                    .frame(width: size.width, height: size.height)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeInOut(duration: 0.25), value: selShowId)
                    .animation(.easeInOut(duration: 0.22).delay(0.1), value: appeared)
                }
            }
        }
    }

    private func showStreakColor(for connection: ShowStreakConnection) -> Color {
        guard let selectedShowId = selShowId else {
            return Color(hex: "BECDFF").opacity(0.18)
        }

        let isAdjacent = connection.fromShowId == selectedShowId || connection.toShowId == selectedShowId
        return isAdjacent
            ? Color(hex: "FFFCD7").opacity(0.45)
            : Color(hex: "BECDFF").opacity(0.04)
    }

    private func mePlanetLayer(size: CGSize) -> some View {
        MePlanetView(isDimmed: selShowId != nil || selFriendId != nil)
            .position(x: size.width / 2, y: (topSafeInset + size.height - bottomSafeInset) / 2)
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.7)
            .animation(.spring(response: 0.36, dampingFraction: 0.72).delay(0.06), value: appeared)
            .animation(.easeInOut(duration: 0.25), value: selShowId != nil || selFriendId != nil)
    }

    private func connectorLayer(
        size: CGSize,
        instances: [FriendInstance],
        nodeByShowId: [Int: ShowNode]
    ) -> some View {
        ForEach(instances) { inst in
            if let node = nodeByShowId[inst.showId] {
                ConnectorLineView(
                    node: node,
                    instance: inst,
                    size: size,
                    isDimmed: dimmedInst(inst),
                    lineEnd: connectorEndPoint(from: node.pos, to: inst.pos, friendInstance: inst)
                )
                .opacity(appeared ? 1 : 0)
                .animation(.easeInOut(duration: 0.2).delay(0.18), value: appeared)
                .animation(.easeInOut(duration: 0.28), value: selShowId)
                .animation(.easeInOut(duration: 0.28), value: selFriendId)
            }
        }
    }

    private func showNodeLayer(nodes: [ShowNode], size: CGSize) -> some View {
        ForEach(Array(nodes.enumerated()), id: \.element.show.id) { idx, node in
            let nodeVisible = launchNodeVisibility(forIndex: idx)
            let isActive = selShowId == node.show.id
            let displayPosition = focusedDisplayPosition(for: node, in: size)
            ShowNodeView(
                node: node,
                isActive: isActive,
                isDimmed: dimmedShow(node.show.id),
                animateStar: starMotionEnabled
            )
            .opacity(nodeVisible ? 1 : 0)
            .scaleEffect(nodeVisible ? 1 : (idx == 0 ? 0.42 : 0.2))
            .offset(
                y: ShowNodeView.dotAnchorCorrection(isActive: isActive)
            )
            .position(displayPosition)
            .zIndex(isActive ? 2 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: selShowId)
            .animation(
                .spring(response: 0.26, dampingFraction: 0.68)
                    .delay(launchPhase == nil ? 0.02 + Double(idx) * 0.032 : idx == 0 ? 0.0 : 0.03 + Double(max(0, idx - 1)) * 0.045),
                value: nodeVisible
            )
            .onTapGesture {
                selectShowNode(node)
            }
        }
    }

    private func focusedDisplayPosition(for node: ShowNode, in size: CGSize) -> CGPoint {
        guard selShowId == node.show.id else { return node.pos }

        let popupTop = focusedPreviewPopupTop(in: size)
        let nodeBottom = node.pos.y + focusedNodeBottomExtent
        guard nodeBottom > popupTop - 12 else { return node.pos }

        var adjusted = node.pos
        adjusted.y = min(node.pos.y, popupTop - focusedNodeBottomExtent - 6)
        adjusted.y = max(adjusted.y, topSafeInset + focusedNodeTopExtent)
        return adjusted
    }

    private func focusedPreviewPopupTop(in size: CGSize) -> CGFloat {
        size.height - focusedPreviewEstimatedHeight(in: size) - focusedPreviewBottomPadding
    }

    private func focusedPreviewEstimatedHeight(in size: CGSize) -> CGFloat {
        min(282, max(228, size.height * 0.30))
    }

    private var focusedPreviewBottomPadding: CGFloat { 118 }
    private var focusedNodeTopExtent: CGFloat { 58 }
    private var focusedNodeBottomExtent: CGFloat { 76 }

    private func friendInstanceLayer(instances: [FriendInstance]) -> some View {
        ForEach(Array(instances.enumerated()), id: \.element.id) { idx, inst in
            let isFreshCheckIn = freshCheckInShowId == inst.showId && inst.isCurrentUser
            let isFriendPulse = pulsingFriendInstanceId == inst.id
            FriendInstanceView(
                instance: inst,
                showLabel: shouldShowFriendLabel(inst, isFreshCheckIn: isFreshCheckIn, isFriendPulse: isFriendPulse),
                isDimmed: dimmedInst(inst),
                isPulsing: isFriendPulse
            )
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? (isFreshCheckIn || isFriendPulse ? 1.22 : 1) : 0.15)
            .position(inst.pos)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.18).combined(with: .opacity),
                removal: .opacity
            ))
            .animation(.spring(response: 0.35, dampingFraction: 0.72), value: selShowId)
            .animation(.spring(response: 0.42, dampingFraction: 0.56), value: freshCheckInShowId)
            .animation(.spring(response: 0.36, dampingFraction: 0.5), value: pulsingFriendInstanceId)
            .animation(
                .spring(response: 0.24, dampingFraction: 0.7)
                    .delay(0.07 + Double(idx) * 0.02),
                value: appeared
            )
            .onTapGesture {
                selectFriendInstance(inst)
            }
        }
    }

    private var headerOverlay: some View {
        VStack(spacing: 0) {
            headerRow
                .padding(.top, 86)
                .padding(.horizontal, 34)
                .padding(.bottom, 6)
            Spacer()
        }
    }

    private func sceneScale(for phase: ElegantSpaceZoomPhase) -> CGFloat {
        let t = SpaceGlideTuning.default
        switch phase {
        case .idle:   return 1
        case .lockOn: return t.sceneScaleLockOn
        case .travel: return t.sceneScaleTravel
        case .arrive: return t.sceneScaleArrive
        }
    }

    private var selectionFocusScale: CGFloat {
        selShowId == nil || spaceZoomPhase != .idle ? 1 : 1.075
    }

    private func selectionZoomAnchor(size: CGSize, nodes: [ShowNode]) -> UnitPoint {
        guard
            let selectedShowId = selShowId,
            let node = nodes.first(where: { $0.show.id == selectedShowId }),
            size.width > 0,
            size.height > 0
        else {
            return .center
        }

        let position = focusedDisplayPosition(for: node, in: size)
        return UnitPoint(
            x: min(1, max(0, position.x / size.width)),
            y: min(1, max(0, position.y / size.height))
        )
    }

    @ViewBuilder
    private func selectedShowDetailOverlay(
        size: CGSize,
        nodes: [ShowNode],
        instances: [FriendInstance]
    ) -> some View {
        if let sid = selShowId, let show = appState.show(for: sid) {
            ZStack(alignment: .bottom) {
                Color.clear
                    .frame(width: size.width, height: size.height)
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                handleFocusedOverlayTap(
                                    at: value.location,
                                    size: size,
                                    nodes: nodes,
                                    instances: instances
                                )
                            }
                    )

                VStack(spacing: 0) {
                    Spacer()
                    let watchers = appState.friendsWatching(showId: sid)
                    DetailPill(show: show, myShow: appState.myShow(for: sid), watchers: watchers, vibe: vibeFor(show: show)) {
                        openShowDetailWithSpaceZoom(show)
                    } onCheckIn: {
                        checkInShow = show
                    } onDismiss: {
                        withAnimation(.spring(response: 0.3)) {
                            selShowId = nil
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                    .padding(.horizontal, 16)
                    .animation(.spring(response: 0.32, dampingFraction: 0.78), value: selShowId)
                    .padding(.bottom, 118)
                }
            }
        }
    }

    private func openShowDetailWithSpaceZoom(_ show: Show) {
        guard spaceZoomPhase == .idle, detailShow == nil else { return }
        StelrHaptics.lightTap()
        detailRevealVisible = false
        spaceZoomShow = nil

        withAnimation(.easeOut(duration: 0.16)) {
            selShowId = nil
            selFriendId = nil
            detailShow = show
        }

        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                detailRevealVisible = true
            }
        }
    }

    private func beginSpaceZoom(to show: Show, origin: CGPoint?) {
        guard spaceZoomPhase == .idle, detailShow == nil else { return }
        StelrHaptics.mediumTap()
        spaceZoomSeed += 1
        spaceZoomOrigin = origin
        spaceZoomShow = show
        detailRevealVisible = false

        let g = SpaceGlideTuning.default

        // Reduce-motion: collapse to a very short cross-fade
        let lockDur    = reduceMotion ? 0.08  : g.lockDuration
        let glideDelay = reduceMotion ? 0.08  : g.lockDuration
        let revealDelay  = reduceMotion ? 0.14  : g.lockDuration + g.glideDuration * 0.55
        let arriveDelay  = reduceMotion ? 0.22  : g.lockDuration + g.glideDuration * 0.88
        let finishDelay  = reduceMotion ? 0.36  : g.totalDuration + 0.06

        withAnimation(.easeOut(duration: lockDur)) {
            selFriendId = nil
            spaceZoomPhase = .lockOn
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + glideDelay) {
            guard self.spaceZoomShow?.id == show.id else { return }
            withAnimation(.easeInOut(duration: reduceMotion ? 0.10 : 0.18)) {
                self.spaceZoomPhase = reduceMotion ? .arrive : .travel
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + revealDelay) {
            guard self.spaceZoomShow?.id == show.id else { return }
            self.detailShow = show
            withAnimation(.spring(response: 0.40, dampingFraction: 0.84)) {
                self.detailRevealVisible = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + arriveDelay) {
            guard self.spaceZoomShow?.id == show.id else { return }
            withAnimation(.easeOut(duration: reduceMotion ? 0.14 : g.arriveDuration)) {
                self.spaceZoomPhase = .arrive
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + finishDelay) {
            guard self.spaceZoomShow?.id == show.id else { return }
            withAnimation(.easeOut(duration: reduceMotion ? 0.12 : 0.18)) {
                self.spaceZoomPhase = .idle
                self.selShowId = nil
                self.selFriendId = nil
            }
            self.spaceZoomShow = nil
        }
    }

    private func closeInlineDetail() {
        withAnimation(.easeInOut(duration: 0.22)) {
            detailRevealVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            detailShow = nil
        }
    }

    private func selectShowNode(_ node: ShowNode) {
        guard spaceZoomPhase == .idle else { return }
        StelrHaptics.lightTap()
        spaceZoomOrigin = node.pos
        withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
            selFriendId = nil
            selShowId = node.show.id
        }
    }

    private func selectFriendInstance(_ inst: FriendInstance) {
        StelrHaptics.lightTap()
        guard !inst.isCurrentUser, let friend = inst.friend else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
            selShowId = nil
            selFriendId = friend.id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            onFriendTap(friend, inst.showId)
        }
    }

    private func shouldShowFriendLabel(_ inst: FriendInstance, isFreshCheckIn: Bool, isFriendPulse: Bool) -> Bool {
        (inst.friend.map { selFriendId == $0.id } ?? false)
            || selShowId == inst.showId
            || isFreshCheckIn
            || isFriendPulse
    }

    private func runEntranceAnimation(animated: Bool) {
        guard launchPhase == nil else { return }
        isExitingDown = false
        starMotionEnabled = false
        if animated {
            appeared = false
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
                    appeared = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) {
                guard appeared else { return }
                withAnimation(.easeInOut(duration: 0.18)) {
                    starMotionEnabled = true
                }
            }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                guard appeared else { return }
                starMotionEnabled = true
            }
        }
    }

    private var headerLaunchOpacity: Double {
        guard let launchPhase else { return 1 }
        return launchPhase.rawValue >= UniverseLaunchPhase.constellation.rawValue ? 1 : 0
    }

    private func launchNodeVisibility(forIndex index: Int) -> Bool {
        guard let launchPhase else { return appeared }
        if index == 0 {
            return launchPhase.rawValue >= UniverseLaunchPhase.focalShow.rawValue
        }
        return launchPhase.rawValue >= UniverseLaunchPhase.constellation.rawValue
    }

    private func handleLaunchPhaseChange(_ phase: UniverseLaunchPhase?) {
        guard let phase else { return }

        if phase.rawValue < UniverseLaunchPhase.focalShow.rawValue {
            appeared = false
            starMotionEnabled = false
            return
        }

        if phase == .constellation || phase == .planet || phase == .tabBar || phase == .complete {
            starMotionEnabled = true
        }

        if phase == .complete {
            appeared = true
        }
    }

    private func runExitDownAnimation() {
        guard spaceZoomPhase == .idle else { return }
        starMotionEnabled = false
        withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
            selShowId = nil
            selFriendId = nil
            isExitingDown = true
            appeared = false
        }
    }

    // MARK: - Shooting star queue

    /// Dequeues the next `ShootingStarEvent` and shows it after `delay` seconds.
    /// Fires a push notification before displaying the overlay.
    /// Auto-dismisses after the 30-second pass if the user doesn't tap; then tries the next one.
    private func dequeueNextShootingStar(delay: Double = 1.05) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard detailShow == nil, spaceZoomPhase == .idle, activeShootingStar == nil else { return }
            guard let next = appState.dequeueNextShootingStar() else { return }

            // Fire push notification first
            Task { await ShootingStarNotificationManager.shared.scheduleNotification(for: next) }

            shootingStarFrozen = false
            let capturedId = next.id

            withAnimation(.easeOut(duration: 0.22)) {
                activeShootingStar = next
            }

            // Auto-dismiss just after the 30 s travel completes if the user has not tapped to freeze.
            DispatchQueue.main.asyncAfter(deadline: .now() + 31.5) {
                guard activeShootingStar?.id == capturedId, !shootingStarFrozen else { return }
                withAnimation(.easeOut(duration: 0.55)) { activeShootingStar = nil }
                dequeueNextShootingStar(delay: 1.4)
            }
        }
    }

    /// Called when the user taps the streaking star.
    /// Freezes the overlay for a beat, then dismisses it and zooms into the show.
    private func handleShootingStarTap(show: Show) {
        guard !shootingStarFrozen else { return }
        shootingStarFrozen = true
        StelrHaptics.mediumTap()

        // Give the freeze burst ~0.45 s to register before dismissing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeOut(duration: 0.22)) {
                activeShootingStar = nil
                shootingStarFrozen = false
            }
            // Kick off the space zoom after the overlay fades
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                beginSpaceZoom(to: show, origin: nil)
            }
        }
    }

    private func clearSelection() {
        guard selShowId != nil || selFriendId != nil else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            selShowId = nil
            selFriendId = nil
        }
    }

    private func commitPendingCheckIn() {
        guard let pendingCheckIn else { return }
        self.pendingCheckIn = nil

        let showId = pendingCheckIn.show.id
        appState.submitCheckIn(
            show: pendingCheckIn.show,
            season: pendingCheckIn.season,
            episode: pendingCheckIn.episode,
            score: pendingCheckIn.score
        )

        withAnimation(.spring(response: 0.42, dampingFraction: 0.56)) {
            freshCheckInShowId = showId
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            guard freshCheckInShowId == showId else { return }
            withAnimation(.easeOut(duration: 0.24)) {
                freshCheckInShowId = nil
            }
        }
    }

    private func handleConstellationPulseEvent() {
        guard let event = appState.constellationPulseEvent else { return }
        let instanceId = "\(event.friendId)-\(event.showId)"
        withAnimation(.spring(response: 0.34, dampingFraction: 0.5)) {
            pulsingFriendInstanceId = instanceId
            selShowId = event.showId
            selFriendId = nil
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            guard pulsingFriendInstanceId == instanceId else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                pulsingFriendInstanceId = nil
            }
        }
    }

    private func handleFocusedOverlayTap(
        at location: CGPoint,
        size: CGSize,
        nodes: [ShowNode],
        instances: [FriendInstance]
    ) {
        guard spaceZoomPhase == .idle else { return }
        if let node = showNode(at: location, nodes: nodes) {
            selectShowNode(node)
            return
        }
        guard !isPoint(location, nearAnyFriendInstance: instances) else { return }
        clearSelection()
    }

    private func clearSelectionIfBackgroundTap(
        at location: CGPoint,
        size: CGSize,
        nodes: [ShowNode],
        instances: [FriendInstance]
    ) {
        guard spaceZoomPhase == .idle else { return }
        guard selShowId != nil || selFriendId != nil else { return }
        guard !isPoint(location, nearAnyShowNode: nodes) else { return }
        guard !isPoint(location, nearAnyFriendInstance: instances) else { return }
        guard !isPointInSelectedCard(location, size: size) else { return }
        clearSelection()
    }

    private func isPointInSelectedCard(_ point: CGPoint, size: CGSize) -> Bool {
        guard selShowId != nil else { return false }
        return point.y >= size.height - 330
    }

    private func isPoint(_ point: CGPoint, nearAnyShowNode nodes: [ShowNode]) -> Bool {
        nodes.contains { node in
            distance(from: point, to: node.pos) <= 74
        }
    }

    private func showNode(at point: CGPoint, nodes: [ShowNode]) -> ShowNode? {
        nodes
            .map { node in (node: node, distance: distance(from: point, to: node.pos)) }
            .filter { $0.distance <= 74 }
            .min { $0.distance < $1.distance }?
            .node
    }

    private func isPoint(_ point: CGPoint, nearAnyFriendInstance instances: [FriendInstance]) -> Bool {
        instances.contains { inst in
            distance(from: point, to: inst.pos) <= 42
        }
    }

    private func distance(from a: CGPoint, to b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }

    // MARK: - Header

    private var headerRow: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 2) {
                Text(weekdayText)
                    .font(StelrTypography.metadataStrong)
                    .foregroundColor(.stelrAccent)
                Text("Tonight's sky")
                    .font(StelrTypography.sectionTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if selShowId != nil || selFriendId != nil {
                Button {
                    withAnimation(.spring(response: 0.28)) {
                        selShowId = nil; selFriendId = nil
                    }
                } label: {
                    Text("✕")
                        .font(StelrTypography.metadata)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Color.white.opacity(0.05))
                        .overlay(Capsule().stroke(Color.stelrBorder, lineWidth: 0.5))
                        .clipShape(Capsule())
                }
                .buttonStyle(.stelrPress)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selShowId == nil && selFriendId == nil)
    }

    private var weekdayText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }

    private var subtitleText: String {
        if let sid = selShowId, let show = appState.show(for: sid) {
            let n = appState.friendsWatching(showId: sid).count
            return "\(n) friend\(n == 1 ? "" : "s") orbiting \(show.title)"
        }
        if let fid = selFriendId, let f = appState.friend(for: fid) {
            return "\(f.name)'s orbit"
        }
        let total = appState.shows.count
        let visible = min(total, maxVisibleShows)
        return "\(appState.myShows.count) watching · \(visible)\(total > visible ? " recent" : "") stars"
    }

    // MARK: - Data builders

    private func buildNodes(size: CGSize) -> [ShowNode] {
        // Map ranked fractions through the safe content area so nodes and their orbit
        // bubbles stay fully on-screen regardless of device size.
        let safeW = size.width  - 2 * sideSafeInset
        let safeH = size.height - topSafeInset - bottomSafeInset

        var watcherMap: [Int: [Friend]] = [:]
        for friend in appState.friends {
            for showId in friend.watchedShowIds {
                watcherMap[showId, default: []].append(friend)
            }
        }

        return rankedVisibleShows().enumerated().map { index, show in
            let frac = layoutFraction(forRank: index)
            let fx = min(maxLayoutFractionX, max(minLayoutFractionX, frac.0))
            let fy = min(maxLayoutFractionY, max(minLayoutFractionY, frac.1))

            let pos  = CGPoint(
                x: sideSafeInset + safeW * fx,
                y: topSafeInset + safeH * fy + constellationYOffset
            )
            let watchers = watcherMap[show.id] ?? []
            let myShow = appState.myShow(for: show.id)
            let isInMyRotation = myShow != nil
            return ShowNode(
                show: show,
                pos: pos,
                watchers: watchers,
                audienceCount: watchers.count + (isInMyRotation ? 1 : 0),
                starStep: aggregateStarStep(for: show.id, watchers: watchers),
                myShow: myShow
            )
        }
    }

    private func layoutFraction(forRank index: Int) -> (CGFloat, CGFloat) {
        rankedFracs[index % rankedFracs.count]
    }

    private func rankedVisibleShows() -> [Show] {
        // Build the full candidate pool: my rotation + anything friends are watching
        var candidateIds: [Int] = []
        for myShow in appState.myShows {
            appendUnique(myShow.showId, to: &candidateIds)
        }
        for friend in appState.friends {
            for showId in friend.watchedShowIds {
                appendUnique(showId, to: &candidateIds)
            }
        }
        for activity in appState.activities {
            appendUnique(activity.showId, to: &candidateIds)
        }

        return candidateIds
            .compactMap { appState.show(for: $0) }
            .sorted { constellationPriority(for: $0) > constellationPriority(for: $1) }
            .prefix(maxVisibleShows)
            .map { $0 }
    }

    private func appendUnique(_ showId: Int, to ids: inout [Int]) {
        guard !ids.contains(showId) else { return }
        ids.append(showId)
    }

    private func hasRated(_ myShow: MyShow) -> Bool {
        myShow.score >= 1 && myShow.score <= 5 && myShow.vibe != .notWatching
    }

    private func constellationPriority(for show: Show) -> Double {
        let watchers = appState.friendsWatching(showId: show.id)
        let myShow = appState.myShow(for: show.id)
        let audienceCount = watchers.count + (myShow != nil ? 1 : 0)
        let averageScore = aggregateStarStep(for: show.id, watchers: watchers).score

        // Activity recency score: earlier position in feed = more recently talked about
        let activityScore = appState.activities.enumerated().reduce(0.0) { partial, item in
            guard item.element.showId == show.id else { return partial }
            return partial + max(0.35, 1.45 - Double(item.offset) * 0.16)
        }

        let glowScore = H7bStarVisualStyle.score10(appScore: averageScore, audienceCount: audienceCount)

        var score = glowScore * 3.0
            + activityScore * 1.4
            + Double(audienceCount) * 0.35

        // ── Active-watching bonus ──────────────────────────────────────────
        // Show is in my rotation, not dropped, and not yet finished
        if let myShow {
            if myShow.vibe != .notWatching && myShow.currentEpisode < myShow.totalEpisodes {
                score += 5.0
            }
            // Recency of my last personal check-in
            score += constellationRecencyScore(myShow.lastChecked) * 3.0
        }

        // ── Social heat bonus ─────────────────────────────────────────────
        // Any activity in the top-10 feed = currently being talked about
        let hasRecentActivity = appState.activities.prefix(10).contains { $0.showId == show.id }
        if hasRecentActivity { score += 2.5 }

        // Active (online) friends watching right now carry extra weight
        let activeWatcherCount = watchers.filter { w in
            appState.friends.first(where: { $0.id == w.id })?.isActive == true
        }.count
        score += Double(activeWatcherCount) * 1.5

        // ── Dormancy penalty ──────────────────────────────────────────────
        // Dropped shows with no social activity sink to the bottom of the pool
        if myShow?.vibe == .notWatching && !hasRecentActivity && activityScore < 0.5 {
            score -= 8.0
        }

        return score
    }

    /// Converts a human-readable lastChecked string into a 0–1 recency weight.
    private func constellationRecencyScore(_ lastChecked: String) -> Double {
        let s = lastChecked.lowercased()
        if s.contains("just") || s.contains("now") || s.hasSuffix("m ago") || s.hasSuffix("h ago") {
            return 1.0
        }
        if s == "yesterday" || s.contains("1d ago") { return 0.75 }
        if s.contains("2d") || s.contains("3d") || s.contains("4d") { return 0.45 }
        if s.contains("5d") || s.contains("6d") { return 0.25 }
        if s.contains("week") || s.contains("1w") || s.contains("2w") { return 0.12 }
        if s.contains("eps ago") || s.contains("ep ago") { return 0.35 }
        return 0.05
    }

    private func buildInstances(nodes: [ShowNode], size: CGSize) -> [FriendInstance] {
        var result: [FriendInstance] = []
        for node in nodes {
            let r = orbitRadius(size: size)
            let includesCurrentUser = appState.myShow(for: node.show.id) != nil
            let n = node.watchers.count
            let totalCount = n + (includesCurrentUser ? 1 : 0)
            for (idx, friend) in node.watchers.enumerated() {
                let angle = orbitAngle(index: idx, count: totalCount, friendId: friend.id, showId: node.show.id)
                let radius = r
                let pos = CGPoint(
                    x: node.pos.x + radius * cos(angle),
                    y: node.pos.y + radius * sin(angle)
                )
                result.append(FriendInstance(
                    id: "\(friend.id)-\(node.show.id)",
                    friend: friend, showId: node.show.id, pos: pos, isCurrentUser: false
                ))
            }
            if includesCurrentUser {
                let angle = orbitAngle(index: n, count: totalCount, friendId: -1, showId: node.show.id)
                let pos = CGPoint(
                    x: node.pos.x + r * cos(angle),
                    y: node.pos.y + r * sin(angle)
                )
                result.append(FriendInstance(
                    id: "me-\(node.show.id)",
                    friend: nil,
                    showId: node.show.id,
                    pos: pos,
                    isCurrentUser: true
                ))
            }
        }
        return separateCurrentUserInstances(result, nodes: nodes, size: size)
    }

    private func separateCurrentUserInstances(
        _ instances: [FriendInstance],
        nodes: [ShowNode],
        size: CGSize
    ) -> [FriendInstance] {
        var adjusted = instances
        let r = orbitRadius(size: size)
        let minInstanceDistance: CGFloat = 34
        let minShowDistance: CGFloat = 42

        for index in adjusted.indices where adjusted[index].isCurrentUser {
            guard let node = nodes.first(where: { $0.show.id == adjusted[index].showId }) else { continue }
            let otherInstances = adjusted.enumerated().compactMap { offset, inst -> CGPoint? in
                offset == index ? nil : inst.pos
            }
            let otherShowNodes = nodes.compactMap { other -> CGPoint? in
                other.show.id == node.show.id ? nil : other.pos
            }
            let currentPos = adjusted[index].pos
            let overlapsInstance = otherInstances.contains {
                distance(from: currentPos, to: $0) < minInstanceDistance
            }
            let overlapsShow = otherShowNodes.contains {
                distance(from: currentPos, to: $0) < minShowDistance
            }
            guard overlapsInstance || overlapsShow else { continue }

            let startAngle = orbitAngle(for: currentPos, around: node.pos)
            let angle = nearestClearCurrentUserAngle(
                start: startAngle,
                center: node.pos,
                radius: r,
                otherInstances: otherInstances,
                otherShowNodes: otherShowNodes,
                minInstanceDistance: minInstanceDistance,
                minShowDistance: minShowDistance
            )
            adjusted[index] = adjusted[index].withPosition(
                CGPoint(x: node.pos.x + r * cos(angle), y: node.pos.y + r * sin(angle))
            )
        }

        return adjusted
    }

    private func nearestClearCurrentUserAngle(
        start: CGFloat,
        center: CGPoint,
        radius: CGFloat,
        otherInstances: [CGPoint],
        otherShowNodes: [CGPoint],
        minInstanceDistance: CGFloat,
        minShowDistance: CGFloat
    ) -> CGFloat {
        let step: CGFloat = .pi / 14
        var candidates = [start]
        for i in 1...28 {
            let delta = CGFloat(i) * step
            candidates.append(start + delta)
            candidates.append(start - delta)
        }

        return candidates.first { angle in
            let pos = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            let clearsInstances = otherInstances.allSatisfy {
                distance(from: pos, to: $0) >= minInstanceDistance
            }
            let clearsShows = otherShowNodes.allSatisfy {
                distance(from: pos, to: $0) >= minShowDistance
            }
            return clearsInstances && clearsShows
        } ?? start
    }

    private func orbitRadius(size: CGSize) -> CGFloat {
        size.width * orbitFrac
    }

    private func orbitAngle(index: Int, count: Int, friendId: Int, showId: Int) -> CGFloat {
        let seed = showId * 137 + friendId * 41 + index * 23
        if count == 1 {
            return deterministicUnit(seed) * 2 * .pi
        }

        let segment = 2 * .pi / CGFloat(count)
        let rotation = (deterministicUnit(showId * 211 + count * 43) - 0.5) * .pi
        let jitterLimit = min(0.72, segment * 0.32)
        let jitter = (deterministicUnit(seed) - 0.5) * 2 * jitterLimit
        return -.pi / 2 + rotation + CGFloat(index) * segment + jitter
    }

    private func deterministicUnit(_ seed: Int) -> CGFloat {
        let mixed = seed &* 1_103_515_245 &+ 12_345
        let positive = mixed & 0x7fffffff
        return CGFloat(positive % 1_000) / 1_000
    }

    private func alternatingVerticalDrift(for index: Int) -> CGFloat {
        let pattern: [CGFloat] = [-0.055, 0.035, -0.025, 0.06, -0.045, 0.025, -0.035, 0.05]
        return pattern[index % pattern.count]
    }

    // MARK: - Title collision avoidance

    private func focusedOrbitInstances(
        _ instances: [FriendInstance],
        nodes: [ShowNode],
        size: CGSize
    ) -> [FriendInstance] {
        let titleSafeInstances = avoidTitleTextOverlap(instances, nodes: nodes, size: size)

        guard let sid = selShowId,
              let node = nodes.first(where: { $0.show.id == sid }) else {
            return titleSafeInstances
        }

        var adjusted = titleSafeInstances
        let activeIndices = Array(adjusted.indices.filter { adjusted[$0].showId == sid })
        let r = orbitRadius(size: size)
        let titleAngle: CGFloat = -.pi / 2
        let gap = titleTextAvoidanceAngle(for: node, radius: r, isActive: true)
        let minSeparation: CGFloat = 0.42
        var occupiedAngles: [CGFloat] = []
        var leftCollisions: [(index: Int, closeness: CGFloat)] = []
        var rightCollisions: [(index: Int, closeness: CGFloat)] = []

        for index in activeIndices {
            let inst = adjusted[index]
            let angle = orbitAngle(for: inst.pos, around: node.pos)
            let diff = normalizedAngleDelta(angle, from: titleAngle)
            let collidesWithTitle = abs(diff) < gap

            if collidesWithTitle {
                let isLeft = diff < 0 || (abs(diff) < 0.001 && inst.pos.x < node.pos.x)
                let item = (index: index, closeness: abs(diff))
                if isLeft {
                    leftCollisions.append(item)
                } else {
                    rightCollisions.append(item)
                }
            } else {
                occupiedAngles.append(angle)
            }
        }

        leftCollisions.sort { $0.closeness < $1.closeness }
        rightCollisions.sort { $0.closeness < $1.closeness }

        for item in leftCollisions {
            let angle = nearestClearAngle(
                start: titleAngle - gap - 0.16,
                direction: -1,
                occupied: occupiedAngles,
                minSeparation: minSeparation,
                titleAngle: titleAngle,
                titleGap: gap
            )
            occupiedAngles.append(angle)
            adjusted[item.index] = adjusted[item.index].withPosition(
                CGPoint(x: node.pos.x + r * cos(angle), y: node.pos.y + r * sin(angle))
            )
        }

        for item in rightCollisions {
            let angle = nearestClearAngle(
                start: titleAngle + gap + 0.16,
                direction: 1,
                occupied: occupiedAngles,
                minSeparation: minSeparation,
                titleAngle: titleAngle,
                titleGap: gap
            )
            occupiedAngles.append(angle)
            adjusted[item.index] = adjusted[item.index].withPosition(
                CGPoint(x: node.pos.x + r * cos(angle), y: node.pos.y + r * sin(angle))
            )
        }

        return adjusted
    }

    private func avoidTitleTextOverlap(
        _ instances: [FriendInstance],
        nodes: [ShowNode],
        size: CGSize
    ) -> [FriendInstance] {
        var adjusted = instances
        let r = orbitRadius(size: size)
        let titleAngle: CGFloat = -.pi / 2
        let minSeparation: CGFloat = 0.36

        for node in nodes {
            let indices = Array(adjusted.indices.filter { adjusted[$0].showId == node.show.id })
            guard !indices.isEmpty else { continue }

            let gap = titleTextAvoidanceAngle(for: node, radius: r, isActive: selShowId == node.show.id)
            var occupiedAngles: [CGFloat] = []
            var leftCollisions: [(index: Int, closeness: CGFloat)] = []
            var rightCollisions: [(index: Int, closeness: CGFloat)] = []

            for index in indices {
                let angle = orbitAngle(for: adjusted[index].pos, around: node.pos)
                let diff = normalizedAngleDelta(angle, from: titleAngle)
                if abs(diff) < gap {
                    let isLeft = diff < 0 || (abs(diff) < 0.001 && adjusted[index].pos.x < node.pos.x)
                    let item = (index: index, closeness: abs(diff))
                    if isLeft {
                        leftCollisions.append(item)
                    } else {
                        rightCollisions.append(item)
                    }
                } else {
                    occupiedAngles.append(angle)
                }
            }

            leftCollisions.sort { $0.closeness < $1.closeness }
            rightCollisions.sort { $0.closeness < $1.closeness }

            for item in leftCollisions {
                let angle = nearestClearAngle(
                    start: titleAngle - gap - 0.1,
                    direction: -1,
                    occupied: occupiedAngles,
                    minSeparation: minSeparation,
                    titleAngle: titleAngle,
                    titleGap: gap
                )
                occupiedAngles.append(angle)
                adjusted[item.index] = adjusted[item.index].withPosition(
                    CGPoint(x: node.pos.x + r * cos(angle), y: node.pos.y + r * sin(angle))
                )
            }

            for item in rightCollisions {
                let angle = nearestClearAngle(
                    start: titleAngle + gap + 0.1,
                    direction: 1,
                    occupied: occupiedAngles,
                    minSeparation: minSeparation,
                    titleAngle: titleAngle,
                    titleGap: gap
                )
                occupiedAngles.append(angle)
                adjusted[item.index] = adjusted[item.index].withPosition(
                    CGPoint(x: node.pos.x + r * cos(angle), y: node.pos.y + r * sin(angle))
                )
            }
        }

        return adjusted
    }

    private func titleTextAvoidanceAngle(for node: ShowNode, radius: CGFloat, isActive: Bool) -> CGFloat {
        let fontSize: CGFloat = isActive ? 12.8 : 11.3
        // This is intentionally text-width based, not pill-width based, so avatars can sit under the capsule edges.
        let textHalfWidth = max(22, CGFloat(node.show.title.count) * fontSize * 0.24)
        let avatarClearance: CGFloat = isActive ? 16 : 13
        return min(0.96, atan2(textHalfWidth + avatarClearance, radius) + 0.08)
    }

    private func orbitAngle(for point: CGPoint, around center: CGPoint) -> CGFloat {
        atan2(point.y - center.y, point.x - center.x)
    }

    private func nearestClearAngle(
        start: CGFloat,
        direction: CGFloat,
        occupied: [CGFloat],
        minSeparation: CGFloat,
        titleAngle: CGFloat,
        titleGap: CGFloat
    ) -> CGFloat {
        var angle = start
        for _ in 0..<18 {
            let titleDelta = normalizedAngleDelta(angle, from: titleAngle)
            let clearsTitle = abs(titleDelta) >= titleGap
            let clearsFriends = occupied.allSatisfy {
                abs(normalizedAngleDelta(angle, from: $0)) >= minSeparation
            }
            if clearsTitle && clearsFriends {
                return angle
            }
            angle += direction * minSeparation
        }
        return angle
    }

    private func normalizedAngleDelta(_ angle: CGFloat, from reference: CGFloat) -> CGFloat {
        var diff = angle - reference
        while diff > .pi { diff -= 2 * .pi }
        while diff < -.pi { diff += 2 * .pi }
        return diff
    }

    private func vibeFor(show: Show) -> VibeOption {
        VibeOption.from(score: aggregateStarStep(for: show.id, watchers: appState.friendsWatching(showId: show.id)).score)
    }

    private func aggregateStarStep(for showId: Int, watchers: [Friend]) -> CheckInStep {
        var scores = watchers.map(\.score).filter { $0 >= 1 && $0 <= 5 }
        if let myShow = appState.myShow(for: showId), myShow.score >= 1, myShow.score <= 5 {
            scores.append(myShow.score)
        }
        guard !scores.isEmpty else {
            return CheckInStep.from(3.0)
        }
        return CheckInStep.from(scores.reduce(0, +) / Double(scores.count))
    }

    // MARK: - Selection helpers

    private func dimmedShow(_ id: Int) -> Bool {
        guard selShowId != nil || selFriendId != nil else { return false }
        if let sid = selShowId { return sid != id }
        if let fid = selFriendId {
            return !appState.friends.contains(where: { $0.id == fid && $0.watchedShowIds.contains(id) })
        }
        return false
    }

    private func dimmedInst(_ inst: FriendInstance) -> Bool {
        guard selShowId != nil || selFriendId != nil else { return false }
        if let sid = selShowId   { return inst.showId != sid }
        if let fid = selFriendId { return inst.friend?.id != fid }
        return false
    }

    private func lineOpacity(for inst: FriendInstance) -> Double {
        if freshCheckInShowId == inst.showId && inst.isCurrentUser {
            return 0.62
        }
        if selShowId == inst.showId {
            return 0.36
        }
        if let fid = selFriendId, inst.friend?.id == fid {
            return 0.34
        }
        return 0.18
    }

    private func connectorEndPoint(from start: CGPoint, to end: CGPoint, friendInstance: FriendInstance) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(1, sqrt(dx * dx + dy * dy))
        let avatarRadius: CGFloat = (selShowId == friendInstance.showId || pulsingFriendInstanceId == friendInstance.id) ? 15 : 12
        let inset = avatarRadius + 1.5
        return CGPoint(
            x: end.x - dx / length * inset,
            y: end.y - dy / length * inset
        )
    }

}

// MARK: - Connector line view

private struct ConnectorLineView: View {
    let node: ShowNode
    let instance: FriendInstance
    let size: CGSize
    let isDimmed: Bool
    let lineEnd: CGPoint

    var body: some View {
        Path { path in
            path.move(to: node.pos)
            path.addLine(to: lineEnd)
        }
        .stroke(connectorColor, lineWidth: 0.6)
        .frame(width: size.width, height: size.height)
    }

    private var connectorColor: Color {
        H7bStarVisualStyle(
            appScore: node.starStep.score,
            audienceCount: node.audienceCount
        )
        .color
        .opacity(isDimmed ? 0.03 : 0.22)
    }
}

// MARK: - ME planet

struct BottomPlanetHorizonView: View {
    /// Extra rotation added to the planet's base tilt — animate this for the "planet spinning" entrance effect.
    var rotationOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.stelrAccent.opacity(0.026),
                        Color(hex: "120804").opacity(0.42)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: size.height * 0.26)
                .frame(maxHeight: .infinity, alignment: .bottom)

                MarsLikePlanetSurface()
                    .frame(width: size.width * 1.22, height: size.height * 0.34)
                    .rotationEffect(.degrees(-7 + rotationOffset))
                    .position(x: size.width * 0.47, y: size.height + size.height * 0.075)

                Ellipse()
                    .stroke(Color.white.opacity(0.14), lineWidth: 1.1)
                    .frame(width: size.width * 1.18, height: size.height * 0.30)
                    .rotationEffect(.degrees(-7 + rotationOffset))
                    .blur(radius: 4.5)
                    .position(x: size.width * 0.47, y: size.height + size.height * 0.065)

                Ellipse()
                    .stroke(Color.white.opacity(0.09), lineWidth: 0.85)
                    .frame(width: size.width * 1.08, height: size.height * 0.20)
                    .rotationEffect(.degrees(-7 + rotationOffset))
                    .blur(radius: 0.25)
                    .position(x: size.width * 0.47, y: size.height - size.height * 0.055)
            }
            .allowsHitTesting(false)
        }
    }
}

private struct MarsLikePlanetSurface: View {
    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                // Base surface: vivid rust-red lit from upper right (matching photo)
                Ellipse()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: Color(hex: "CC5C2A").opacity(0.98), location: 0.0),
                                .init(color: Color(hex: "B04828").opacity(0.98), location: 0.16),
                                .init(color: Color(hex: "903A1C").opacity(0.99), location: 0.34),
                                .init(color: Color(hex: "5C1E0C").opacity(0.99), location: 0.56),
                                .init(color: Color(hex: "200804").opacity(1.0), location: 0.78),
                                .init(color: Color(hex: "080100").opacity(1.0), location: 1.0)
                            ],
                            center: UnitPoint(x: 0.68, y: 0.12),
                            startRadius: 0,
                            endRadius: size.width * 0.78
                        )
                    )

                // Surface texture — dark maria regions
                MarsSurfaceTexture()
                    .opacity(0.90)
                    .blendMode(.multiply)

                // Highland brightness highlights
                MarsSurfaceTexture(isHighlights: true)
                    .opacity(0.34)
                    .blendMode(.screen)

                // Large dark equatorial band (Syrtis Major / Valles Marineris analog)
                darkEquatorialRegion(size: size)

                // Terminator: light from right → shadow on left
                terminatorShadow

                // Two specular bright dots near the terminator (visible in photo)
                specularHighlights(size: size)

                // Limb darkening overlay
                Ellipse()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.08), location: 0.0),
                                .init(color: Color.clear, location: 0.42),
                                .init(color: Color.black.opacity(0.28), location: 0.78),
                                .init(color: Color.black.opacity(0.70), location: 1.0)
                            ],
                            center: UnitPoint(x: 0.70, y: 0.15),
                            startRadius: size.width * 0.04,
                            endRadius: size.width * 0.82
                        )
                    )

                topAtmosphereRim
            }
            .clipShape(Ellipse())
            .overlay {
                Ellipse()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "F0A060").opacity(0.22),
                                Color.white.opacity(0.16),
                                Color.clear,
                                Color.black.opacity(0.18)
                            ],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        ),
                        lineWidth: 1.0
                    )
                    .blur(radius: 0.3)
            }
            .shadow(color: Color.white.opacity(0.08), radius: 8, y: -5)
            .shadow(color: Color(hex: "B04820").opacity(0.22), radius: 22, y: -8)
            .shadow(color: Color.black.opacity(0.84), radius: 28, y: 18)
        }
    }

    // Prominent dark region covering the lower/mid surface — like the photo's dark maria
    private func darkEquatorialRegion(size: CGSize) -> some View {
        Canvas { ctx, sz in
            // Primary large dark band (Syrtis Major analog)
            var band = Path()
            band.move(to: CGPoint(x: sz.width * 0.08, y: sz.height * 0.28))
            band.addCurve(
                to: CGPoint(x: sz.width * 0.86, y: sz.height * 0.36),
                control1: CGPoint(x: sz.width * 0.26, y: sz.height * 0.18),
                control2: CGPoint(x: sz.width * 0.60, y: sz.height * 0.44)
            )
            band.addLine(to: CGPoint(x: sz.width * 0.90, y: sz.height * 0.82))
            band.addCurve(
                to: CGPoint(x: sz.width * 0.06, y: sz.height * 0.76),
                control1: CGPoint(x: sz.width * 0.64, y: sz.height * 0.92),
                control2: CGPoint(x: sz.width * 0.28, y: sz.height * 0.70)
            )
            band.closeSubpath()
            ctx.fill(band, with: .color(Color(hex: "160402").opacity(0.68)))

            // Secondary dark patch upper-left (like the photo's left-side darker region)
            var leftPatch = Path()
            leftPatch.move(to: CGPoint(x: sz.width * 0.04, y: sz.height * 0.18))
            leftPatch.addCurve(
                to: CGPoint(x: sz.width * 0.42, y: sz.height * 0.24),
                control1: CGPoint(x: sz.width * 0.16, y: sz.height * 0.10),
                control2: CGPoint(x: sz.width * 0.30, y: sz.height * 0.32)
            )
            leftPatch.addCurve(
                to: CGPoint(x: sz.width * 0.06, y: sz.height * 0.50),
                control1: CGPoint(x: sz.width * 0.20, y: sz.height * 0.20),
                control2: CGPoint(x: sz.width * 0.02, y: sz.height * 0.38)
            )
            leftPatch.closeSubpath()
            ctx.fill(leftPatch, with: .color(Color(hex: "200604").opacity(0.54)))

            // Canyon-like slash (Valles Marineris analog) — diagonal streak
            var canyon = Path()
            canyon.move(to: CGPoint(x: sz.width * 0.18, y: sz.height * 0.36))
            canyon.addCurve(
                to: CGPoint(x: sz.width * 0.78, y: sz.height * 0.46),
                control1: CGPoint(x: sz.width * 0.36, y: sz.height * 0.28),
                control2: CGPoint(x: sz.width * 0.60, y: sz.height * 0.52)
            )
            ctx.stroke(canyon, with: .color(Color.black.opacity(0.50)), lineWidth: sz.height * 0.048)

            // Tertiary dark smudge lower-right
            var smudge = Path()
            let sr = CGRect(x: sz.width * 0.56, y: sz.height * 0.54, width: sz.width * 0.28, height: sz.height * 0.22)
            smudge.addEllipse(in: sr)
            ctx.fill(smudge, with: .color(Color(hex: "0E0302").opacity(0.44)))
        }
        .blendMode(.multiply)
    }

    // Two glowing specular dots near the terminator (as seen in the photo)
    private func specularHighlights(size: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.90), Color.white.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: size.width * 0.024
                    )
                )
                .frame(width: size.width * 0.048, height: size.width * 0.048)
                .blur(radius: 1.4)
                .position(x: size.width * 0.44, y: size.height * 0.50)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.68), Color.white.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: size.width * 0.014
                    )
                )
                .frame(width: size.width * 0.028, height: size.width * 0.028)
                .blur(radius: 1.8)
                .position(x: size.width * 0.54, y: size.height * 0.70)
        }
    }

    // Terminator: shadow on the left, bright on the right (matches photo lighting)
    private var terminatorShadow: some View {
        LinearGradient(
            stops: [
                .init(color: Color.black.opacity(0.97), location: 0.0),
                .init(color: Color.black.opacity(0.78), location: 0.12),
                .init(color: Color.black.opacity(0.40), location: 0.24),
                .init(color: Color.black.opacity(0.12), location: 0.36),
                .init(color: Color.black.opacity(0.02), location: 0.46),
                .init(color: Color.clear, location: 0.56)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .blur(radius: 2.4)
    }

    private var topAtmosphereRim: some View {
        GeometryReader { geo in
            Ellipse()
                .trim(from: 0.02, to: 0.54)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "F0A060").opacity(0.12),
                            Color.white.opacity(0.22),
                            Color(hex: "E88040").opacity(0.14),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .topTrailing
                    ),
                    lineWidth: 1.6
                )
                .frame(
                    width: geo.size.width * 0.96,
                    height: geo.size.height * 0.91
                )
                .position(x: geo.size.width * 0.50, y: geo.size.height * 0.50)
                .blur(radius: 0.45)
        }
    }
}

private struct MarsSurfaceTexture: View {
    var isHighlights = false

    var body: some View {
        Canvas { ctx, size in
            drawDarkRegions(ctx: ctx, size: size)
            drawCraters(ctx: ctx, size: size)
            drawRidges(ctx: ctx, size: size)
        }
    }

    // Organic dark patches scattered across the surface
    private func drawDarkRegions(ctx: GraphicsContext, size: CGSize) {
        for index in 0..<28 {
            let cx = size.width  * (0.05 + deterministicUnit(index * 73) * 0.84)
            let cy = size.height * (0.06 + deterministicUnit(index * 127) * 0.80)
            let w  = size.width  * (0.05 + deterministicUnit(index * 41) * 0.24)
            let h  = size.height * (0.04 + deterministicUnit(index * 79) * 0.20)
            let rect = CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
            let opacity = isHighlights
                ? deterministicUnit(index * 89) * 0.055
                : 0.07 + deterministicUnit(index * 53) * 0.22
            let color = isHighlights
                ? Color(hex: "F0A060").opacity(opacity)
                : Color(hex: "180402").opacity(opacity)
            ctx.fill(Path(ellipseIn: rect), with: .color(color))
        }
    }

    private func drawCraters(ctx: GraphicsContext, size: CGSize) {
        for index in 0..<80 {
            let x = size.width  * (0.05 + deterministicUnit(index * 97)  * 0.76)
            let y = size.height * (0.05 + deterministicUnit(index * 151) * 0.84)
            let diameter = size.width * (0.004 + deterministicUnit(index * 211) * 0.030)
            let rect = CGRect(x: x, y: y, width: diameter, height: diameter * 0.70)
            if isHighlights {
                ctx.stroke(
                    Path(ellipseIn: rect.offsetBy(dx: -diameter * 0.12, dy: -diameter * 0.10)),
                    with: .color(Color(hex: "F3B07A").opacity(0.09)),
                    lineWidth: max(0.20, diameter * 0.028)
                )
            } else {
                ctx.fill(Path(ellipseIn: rect), with: .color(Color.black.opacity(0.20)))
                ctx.stroke(
                    Path(ellipseIn: rect),
                    with: .color(Color(hex: "6A2E18").opacity(0.30)),
                    lineWidth: max(0.28, diameter * 0.042)
                )
            }
        }
    }

    private func drawRidges(ctx: GraphicsContext, size: CGSize) {
        for index in 0..<14 {
            var path = Path()
            let startX = size.width  * (0.04 + deterministicUnit(index * 313) * 0.36)
            let startY = size.height * (0.08 + deterministicUnit(index * 419) * 0.76)
            path.move(to: CGPoint(x: startX, y: startY))
            let segments = 5 + index % 4
            for segment in 1...segments {
                let x = startX + size.width * CGFloat(segment) * 0.070
                let y = startY + sin(CGFloat(segment) * 0.88 + CGFloat(index) * 1.4) * size.height * 0.020
                path.addLine(to: CGPoint(x: x, y: y))
            }
            let ridgeOpacity = isHighlights
                ? 0.055
                : 0.12 + deterministicUnit(index * 71) * 0.12
            ctx.stroke(
                path,
                with: .color((isHighlights ? Color(hex: "F2B07F") : Color.black).opacity(ridgeOpacity)),
                lineWidth: isHighlights ? 0.48 : max(0.75, 1.5 - deterministicUnit(index * 53) * 0.7)
            )
        }
    }

    private func deterministicUnit(_ seed: Int) -> CGFloat {
        let mixed = seed &* 1_103_515_245 &+ 12_345
        let positive = mixed & 0x7fffffff
        return CGFloat(positive % 1_000) / 1_000
    }
}

private struct MePlanetView: View {
    let isDimmed: Bool

    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.stelrAccent.opacity(0.08))
                .frame(width: 76, height: 76)
                .scaleEffect(pulse ? 1.08 : 0.94)
                .opacity(pulse ? 1 : 0.62)

            Circle()
                .fill(Color.stelrAccent.opacity(0.18))
                .frame(width: 44, height: 44)

            Circle()
                .fill(Color.stelrAccent)
                .frame(width: 20, height: 20)

            Circle()
                .stroke(Color.white.opacity(0.50), lineWidth: 0.55)
                .frame(width: 20, height: 20)

            Text("ME")
                .font(.system(size: 8.2, weight: .bold))
                .tracking(0.2)
                .foregroundColor(Color(hex: "1a0e02"))
        }
        .opacity(isDimmed ? 0.30 : 1)
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Shooting star overlay
// Uses TimelineView so progress can be frozen mid-animation on tap.

private struct SeasonCompletionShootingStarOverlay: View {
    let event: ShootingStarEvent
    let isFrozen: Bool
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animationStart: Date? = nil
    @State private var frozenProgress: CGFloat? = nil
    @State private var freezeBurstScale: CGFloat = 1
    @State private var freezeBurstOpacity: Double = 0

    private let duration: Double = 30.0

    var body: some View {
        GeometryReader { geo in
            if reduceMotion {
                TimelineView(.animation(minimumInterval: 1 / 60)) { ctx in
                    reducedMotionCard(size: geo.size, progress: liveProgress(at: ctx.date))
                }
            } else {
                TimelineView(.animation(minimumInterval: 1 / 60)) { ctx in
                    let p = liveProgress(at: ctx.date)
                    shootingStar(size: geo.size, progress: p)
                        // Tap anywhere on the full-screen canvas while the star is visible
                        .onTapGesture { handleTap(progress: p) }
                }
            }
        }
        .onAppear {
            animationStart = Date()
            frozenProgress = nil
            freezeBurstScale = 1
            freezeBurstOpacity = 0
        }
        .onChange(of: isFrozen) { _, frozen in
            if frozen, let start = animationStart, frozenProgress == nil {
                // Snapshot current progress and play the freeze burst
                let elapsed = CGFloat(Date().timeIntervalSince(start))
                frozenProgress = min(1, elapsed / CGFloat(duration))
                playFreezeBurst()
            }
        }
    }

    // MARK: Progress

    private func liveProgress(at date: Date) -> CGFloat {
        if let fp = frozenProgress { return fp }
        guard let start = animationStart else { return 0 }
        return min(1, CGFloat(date.timeIntervalSince(start)) / CGFloat(duration))
    }

    private func handleTap(progress: CGFloat) {
        guard frozenProgress == nil, !isFrozen else { return }
        frozenProgress = progress
        playFreezeBurst()
        onTap()
    }

    // MARK: Freeze burst

    private func playFreezeBurst() {
        freezeBurstScale   = 1
        freezeBurstOpacity = 1
        withAnimation(.easeOut(duration: 0.55)) {
            freezeBurstScale   = 3.2
            freezeBurstOpacity = 0
        }
    }

    // MARK: Card layout

    private func reducedMotionCard(size: CGSize, progress: CGFloat) -> some View {
        metadataCard
            .position(x: size.width / 2, y: size.height * 0.76)
            .opacity(Double(progress))
            .scaleEffect(0.98 + progress * 0.02)
    }

    private func shootingStar(size: CGSize, progress: CGFloat) -> some View {
        // Travel through the empty strip just above the tab bar (~78–82 % down)
        let start  = CGPoint(x: -190,             y: size.height * 0.81)
        let end    = CGPoint(x: size.width + 178,  y: size.height * 0.75)
        let eased  = Self.easeInOutSine(progress)
        let point  = Self.interpolate(from: start, to: end, progress: eased)
        let cardW  = min(size.width - 64, 220)
        let cardX  = Self.clamp(point.x, min: cardW / 2 + 16, max: size.width - cardW / 2 - 16)
        let cardY  = point.y - 38
        let frozen = frozenProgress != nil

        return ZStack {
            shootingTrail(from: start, to: end, point: point, progress: eased)
                .opacity(trailOpacity(progress, frozen: frozen))

            // Freeze burst ring — expands and fades on tap
            Circle()
                .stroke(Color.white.opacity(0.62), lineWidth: 1.5)
                .frame(width: 32, height: 32)
                .scaleEffect(freezeBurstScale)
                .opacity(freezeBurstOpacity)
                .position(point)

            StelrFourPointStar(variant: .twinkle)
                .fill(Color.white.opacity(frozen ? 1.0 : 0.96))
                .frame(width: frozen ? 22 : 18, height: frozen ? 22 : 18)
                .shadow(color: Color.white.opacity(frozen ? 0.95 : 0.78), radius: frozen ? 22 : 13)
                .shadow(color: Color.stelrAccent.opacity(frozen ? 0.55 : 0.34), radius: frozen ? 38 : 24)
                .scaleEffect(frozen ? 1.18 : (0.82 + eased * 0.22))
                .opacity(starOpacity(progress, frozen: frozen))
                .animation(.spring(response: 0.28, dampingFraction: 0.68), value: frozen)
                .position(point)

            metadataCard
                .frame(width: cardW)
                .position(x: cardX, y: cardY)
                .opacity(cardOpacity(progress, frozen: frozen))
                .offset(y: cardOpacity(progress, frozen: frozen) < 0.9 ? 8 : 0)
        }
        .frame(width: size.width, height: size.height)
    }

    private func shootingTrail(from start: CGPoint, to end: CGPoint, point: CGPoint, progress: CGFloat) -> some View {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(1, sqrt(dx * dx + dy * dy))
        let unitX = dx / length
        let unitY = dy / length
        let normalX = -unitY
        let normalY = unitX
        let tailLength = 150 + 126 * Self.easeOutQuart(progress)
        let tail = CGPoint(x: point.x - unitX * tailLength, y: point.y - unitY * tailLength)
        let midTail = CGPoint(x: point.x - unitX * tailLength * 0.62, y: point.y - unitY * tailLength * 0.62)
        let nearTail = CGPoint(x: point.x - unitX * tailLength * 0.28, y: point.y - unitY * tailLength * 0.28)
        let arcControl = CGPoint(
            x: point.x - unitX * tailLength * 0.54 + normalX * 9,
            y: point.y - unitY * tailLength * 0.54 + normalY * 9
        )

        return ZStack {
            Path { path in
                path.move(to: tail)
                path.addQuadCurve(to: point, control: arcControl)
            }
            .stroke(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.stelrAccent.opacity(0.06),
                        Color.white.opacity(0.12),
                        Color.stelrAccent.opacity(0.18)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 14, lineCap: .round)
            )
            .blur(radius: 16)

            Path { path in
                path.move(to: tail)
                path.addQuadCurve(to: point, control: arcControl)
            }
            .stroke(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(0.04),
                        Color.white.opacity(0.22),
                        Color(hex: "FFEAC5").opacity(0.46)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 3.2, lineCap: .round)
            )
            .blur(radius: 1.1)

            Path { path in
                path.move(to: midTail)
                path.addQuadCurve(
                    to: point,
                    control: CGPoint(
                        x: point.x - unitX * tailLength * 0.36 + normalX * 4,
                        y: point.y - unitY * tailLength * 0.36 + normalY * 4
                    )
                )
            }
            .stroke(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(0.30),
                        Color.white.opacity(0.92)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 1.15, lineCap: .round)
            )
            .blur(radius: 0.12)

            Path { path in
                path.move(to: CGPoint(x: nearTail.x + normalX * 5.0, y: nearTail.y + normalY * 5.0))
                path.addLine(to: CGPoint(x: point.x + normalX * 2.2, y: point.y + normalY * 2.2))
            }
            .stroke(Color.stelrAccent.opacity(0.18), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            .blur(radius: 5.2)

            Path { path in
                path.move(to: CGPoint(x: midTail.x - normalX * 4.5, y: midTail.y - normalY * 4.5))
                path.addLine(to: CGPoint(x: point.x - normalX * 1.7, y: point.y - normalY * 1.7))
            }
            .stroke(Color.white.opacity(0.10), style: StrokeStyle(lineWidth: 1.15, lineCap: .round))
            .blur(radius: 3.8)

            ForEach(0..<8, id: \.self) { index in
                let fraction = CGFloat(index + 1) / 9
                let drift = Self.trailDustDrift(index)
                let dustPoint = CGPoint(
                    x: point.x - unitX * tailLength * fraction + normalX * drift * (1.18 - fraction),
                    y: point.y - unitY * tailLength * fraction + normalY * drift * (1.18 - fraction)
                )
                let dotSize = CGFloat(index.isMultiple(of: 3) ? 2.2 : 1.35)

                Circle()
                    .fill(Color(hex: "FFEAC5").opacity(Double(0.24 * (1 - fraction))))
                    .frame(width: dotSize, height: dotSize)
                    .blur(radius: 0.6)
                    .position(dustPoint)
            }
        }
    }

    private var metadataCard: some View {
        // Compact pill: "Maya · finished S3"
        Text("\(event.friend.name) · finished S\(event.season)")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(Color.white.opacity(0.78))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(hex: "0d0d18").opacity(0.72))
            .background(.ultraThinMaterial, in: Capsule())
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
            .shadow(color: Color.black.opacity(0.35), radius: 8, y: 4)
    }

    // MARK: Opacity helpers (progress-aware, freeze-aware)

    private func starOpacity(_ p: CGFloat, frozen: Bool) -> Double {
        if frozen { return 1 }
        let d = Double(p)
        if d < 0.04 { return d / 0.04 }
        if d > 0.985 { return max(0, 1 - (d - 0.985) / 0.015) }
        return 1
    }

    private func trailOpacity(_ p: CGFloat, frozen: Bool) -> Double {
        if frozen { return 0 }        // hide trail while frozen — looks cleaner
        let d = Double(p)
        if d < 0.08 { return d / 0.08 }
        if d > 0.985 { return max(0, 1 - (d - 0.985) / 0.015) }
        return 0.96
    }

    private func cardOpacity(_ p: CGFloat, frozen: Bool) -> Double {
        if frozen { return 1 }
        let d = Double(p)
        if d < 0.12 { return 0 }
        if d < 0.26 { return (d - 0.12) / 0.14 }
        if d > 0.94 { return max(0, 1 - (d - 0.94) / 0.06) }
        return 1
    }

    // MARK: Math helpers

    private static func interpolate(from start: CGPoint, to end: CGPoint, progress: CGFloat) -> CGPoint {
        CGPoint(
            x: start.x + (end.x - start.x) * progress,
            y: start.y + (end.y - start.y) * progress
        )
    }

    private static func easeInOutSine(_ value: CGFloat) -> CGFloat {
        let t = clamp(value, min: 0, max: 1)
        return -(cos(.pi * t) - 1) / 2
    }

    private static func easeOutQuart(_ value: CGFloat) -> CGFloat {
        let t = clamp(value, min: 0, max: 1)
        return 1 - pow(1 - t, 4)
    }

    private static func trailDustDrift(_ index: Int) -> CGFloat {
        let offsets: [CGFloat] = [-4.5, 3.0, -1.4, 5.8, -6.2, 1.9, -3.3, 4.4]
        return offsets[index % offsets.count]
    }

    private static func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, min), max)
    }
}

// MARK: - Show node view

private struct ShowNodeView: View {
    let node: ShowNode
    let isActive: Bool
    let isDimmed: Bool
    let animateStar: Bool

    private var starSize: CGFloat {
        isActive ? 38.5 : 37
    }

    static func dotAnchorCorrection(isActive: Bool) -> CGFloat {
        0
    }

    private var episodeText: String? {
        guard let ms = node.myShow, ms.totalEpisodes > 0 else { return nil }
        return "E\(ms.currentEpisode)/\(ms.totalEpisodes)"
    }

	var body: some View {
        ZStack {
            StarGlowView(
                score: node.starStep.score,
                maxCoreSize: starSize,
                animate: animateStar,
                audienceCount: node.audienceCount,
                phaseOffset: Self.starPhaseOffset(for: node.show.id),
                timingJitter: Self.starTimingJitter(for: node.show.id)
            )

            ActiveStarWatchingBubble(friends: node.watchers)
                .offset(y: friendBubbleOffset)
                .opacity(isActive && !node.watchers.isEmpty ? 1 : 0)
                .scaleEffect(isActive && !node.watchers.isEmpty ? 1 : 0.86, anchor: .bottom)

            StarLabelView(
                title: node.show.title,
                episodeText: episodeText,
                audienceCount: node.audienceCount,
                isActive: isActive,
                isDimmed: isDimmed
            )
            .offset(y: labelStackOffset)
        }
        .frame(width: 212, height: 208)
        .scaleEffect(isActive ? 1.018 : 1)
        .opacity(isDimmed ? 0.28 : 1)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: isActive)
        .animation(.easeInOut(duration: 0.22), value: isDimmed)
    }

    private var labelStackOffset: CGFloat {
        let style = H7bStarVisualStyle(appScore: node.starStep.score, audienceCount: node.audienceCount)
        let scale = H7bStarVisualStyle.visualScale(
            maxCoreSize: starSize,
            appScore: node.starStep.score,
            audienceCount: node.audienceCount
        )
        let glowRadius = style.haloRadius * 0.82 * scale
        let extraClearance = starSize * (isActive ? 0.68 : 0.62)
        let baseOffset = glowRadius + extraClearance + (isActive ? 16 : 13)
        let missingEpisodeCompensation: CGFloat = episodeText == nil ? (isActive ? 18 : 16) : 0
        return (baseOffset - missingEpisodeCompensation) * 0.70
    }

    private var friendBubbleOffset: CGFloat {
        let style = H7bStarVisualStyle(appScore: node.starStep.score, audienceCount: node.audienceCount)
        let scale = H7bStarVisualStyle.visualScale(
            maxCoreSize: starSize,
            appScore: node.starStep.score,
            audienceCount: node.audienceCount
        )
        let glowRadius = style.haloRadius * 0.62 * scale
        return -(glowRadius + starSize * 0.54 + 30)
    }

    private static func starPhaseOffset(for showId: Int) -> Double {
        deterministicUnit(showId * 137 + 31) * 5.2
    }

    private static func starTimingJitter(for showId: Int) -> Double {
        0.88 + deterministicUnit(showId * 193 + 17) * 0.28
    }

    private static func deterministicUnit(_ seed: Int) -> Double {
        let value = sin(Double(seed) * 12.9898) * 43758.5453
        return value - floor(value)
    }
}

private struct ActiveStarWatchingBubble: View {
    let friends: [Friend]

    var body: some View {
        Group {
            if !friends.isEmpty {
                VStack(spacing: 0) {
                    // Bubble pill
                    FriendStackView(friends: friends, maxVisible: 4, avatarSize: 20)
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.black.opacity(0.55))
                                .background(.regularMaterial, in: Capsule(style: .continuous))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                        )
                        .shadow(color: .black.opacity(0.60), radius: 10, y: 4)

                    // Callout arrow pointing down toward the star
                    CalloutArrow()
                        .fill(Color.black.opacity(0.55))
                        .frame(width: 12, height: 7)
                        .overlay(
                            // Matching border on the arrow edges
                            CalloutArrow()
                                .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                        )
                        .padding(.top, -1)
                }
                .transition(.scale(scale: 0.82, anchor: .bottom).combined(with: .opacity))
            }
        }
        .allowsHitTesting(true)
        .accessibilityLabel("\(friends.count) friends watching")
    }
}

/// Smooth callout arrow — slightly rounded tip, like the Apple Maps location bubble pointer.
private struct CalloutArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tipX = rect.midX
        let tipY = rect.maxY
        let baseY = rect.minY
        let baseLeft = rect.minX
        let baseRight = rect.maxX
        let corner: CGFloat = 2.0

        path.move(to: CGPoint(x: baseLeft + corner, y: baseY))
        path.addLine(to: CGPoint(x: baseRight - corner, y: baseY))
        path.addQuadCurve(
            to: CGPoint(x: tipX, y: tipY),
            control: CGPoint(x: baseRight * 0.72, y: baseY + (tipY - baseY) * 0.4)
        )
        path.addQuadCurve(
            to: CGPoint(x: baseLeft + corner, y: baseY),
            control: CGPoint(x: baseLeft * 0.28 + tipX * 0.72, y: baseY + (tipY - baseY) * 0.4)
        )
        path.closeSubpath()
        return path
    }
}

private struct StarLabelView: View {
    let title: String
    let episodeText: String?
    let audienceCount: Int
    let isActive: Bool
    let isDimmed: Bool

    private var labelOpacity: Double {
        if isDimmed { return 0.54 }
        return isActive ? 1.0 : 0.92
    }

    private var titleForeground: Color {
        isActive ? Color.white.opacity(0.98) : Color.white.opacity(0.92)
    }

    private var progressForeground: Color {
        isActive ? Color(hex: "FFF2D8") : Color.white.opacity(0.84)
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(isActive ? StelrTypography.metadataStrong : StelrTypography.metadata)
                .foregroundStyle(titleForeground)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, isActive ? 10 : 8)
                .padding(.vertical, isActive ? 6 : 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(isActive ? 0.66 : 0.58))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(isActive ? 0.18 : 0.10), lineWidth: 0.7)
                )
                .shadow(color: .black.opacity(0.88), radius: 12, x: 0, y: 5)
                .shadow(color: .white.opacity(isActive ? 0.10 : 0.04), radius: 4, x: 0, y: 0)

            if let episodeText {
                Text(episodeText)
                    .font(StelrTypography.episodeMeta)
                    .monospacedDigit()
                    .foregroundStyle(progressForeground)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.black.opacity(isActive ? 0.58 : 0.48))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(isActive ? 0.12 : 0.08), lineWidth: 0.6)
                    )
                    .shadow(color: .black.opacity(0.82), radius: 8, x: 0, y: 3)
                    .opacity(isDimmed ? 0 : (isActive ? 0.92 : 0.76))
                    .animation(.easeInOut(duration: 0.18), value: isActive)
            }
        }
        .opacity(labelOpacity)
        .scaleEffect(isActive ? 1.015 : 1)
        .allowsHitTesting(false)
    }
}

// MARK: - Friend instance view

private struct FriendInstanceView: View {
    let instance: FriendInstance
    let showLabel: Bool
    let isDimmed: Bool
    let isPulsing: Bool

    private var initials: String {
        instance.isCurrentUser ? "ME" : instance.friend?.initials ?? "?"
    }

    private var hexColor: String {
        instance.isCurrentUser ? "EDE5D8" : instance.friend?.hexColor ?? "8A8070"
    }

    private var imageURL: String? {
        instance.isCurrentUser ? nil : instance.friend?.imageURL
    }

    private var label: String {
        instance.isCurrentUser ? "you" : instance.friend?.name ?? ""
    }

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                if isPulsing {
                    Circle()
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        .frame(width: 42, height: 42)
                        .scaleEffect(1.45)
                        .opacity(0.28)
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 48, height: 48)
                        .blur(radius: 5)
                }
                AvatarView(initials: initials, hexColor: hexColor, imageURL: imageURL,
                           size: showLabel ? 30 : 24, showBorder: showLabel || isPulsing)
            }
            if showLabel {
                Text(label)
                    .font(StelrTypography.microLabel)
                    .foregroundColor(Color(hex: hexColor))
                    .fixedSize()
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .opacity(isDimmed ? 0.12 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: showLabel)
        .animation(.spring(response: 0.36, dampingFraction: 0.5), value: isPulsing)
        .animation(.easeInOut(duration: 0.3), value: isDimmed)
    }
}

// MARK: - Detail pill (shown when a show node is selected)

private struct DetailPill: View {
    let show: Show
    let myShow: MyShow?
    let watchers: [Friend]
    let vibe: VibeOption
    var onViewDetail: () -> Void
    var onCheckIn: () -> Void
    var onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            pullHandle

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    DetailPillPreviewArtwork(show: show)
                        .frame(width: 82, height: 118)
                        .shadow(color: .black.opacity(0.32), radius: 10, y: 6)

                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top, spacing: 8) {
                            Text(show.title)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.76)

                            Spacer(minLength: 6)

                            Button(action: onDismiss) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white.opacity(0.65))
                                    .frame(width: 28, height: 28)
                                    .background(Color.white.opacity(0.10))
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 0.6))
                            }
                            .padding(.top, 2)
                        }
                        .padding(.bottom, 5)

                        Text(metaLineText)
                            .font(.system(size: 13.5, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .padding(.bottom, 7)

                        Text(previewSummary)
                            .font(StelrTypography.callout)
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.bottom, 20)

                HStack(spacing: 8) {
                    Button(action: onViewDetail) {
                        Text("View")
                            .font(StelrTypography.button)
                            .tracking(0.2)
                            .foregroundColor(.white.opacity(0.92))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.white.opacity(0.09))
                            .background(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.13), lineWidth: 0.7)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.stelrPress)

                    Button(action: onCheckIn) {
                        HStack(spacing: 7) {
                            StelrFourPointStar(variant: .twinkle)
                                .fill(Color.white.opacity(0.88))
                                .frame(width: 11, height: 11)
                            Text("Vibe check")
                                .font(StelrTypography.button)
                        }
                        .foregroundColor(.white.opacity(0.92))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.white.opacity(0.13))
                        .background(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.16), lineWidth: 0.7)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.stelrPress)
                    .accessibilityLabel("Vibe check")
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 9)
        .padding(.bottom, 16)
        .background(frostedCardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.105),
                            Color.white.opacity(0.040),
                            Color(hex: show.accentColor).opacity(0.055)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.34), radius: 24, y: 14)
        .offset(y: dragOffset)
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    dragOffset = max(0, value.translation.height)
                }
                .onEnded { value in
                    if value.translation.height > 80 {
                        onDismiss()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }

    private var pullHandle: some View {
        HStack {
            Spacer()
            Capsule()
                .fill(Color.white.opacity(0.24))
                .frame(width: 34, height: 4)
            .accessibilityLabel("Swipe down to dismiss")
            Spacer()
        }
        .frame(height: 8)
    }

    private var previewSummary: String {
        show.summary ?? "No summary available yet."
    }

    private var frostedCardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.045),
                                Color(hex: "121421").opacity(0.30),
                                Color(hex: "080A13").opacity(0.45)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.10),
                                Color.white.opacity(0.032),
                                .clear
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 240
                        )
                    )
                    .blendMode(.screen)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: show.accentColor).opacity(0.08),
                                Color(hex: show.accentColor).opacity(0.025),
                                .clear
                            ],
                            center: .bottomLeading,
                            startRadius: 12,
                            endRadius: 300
                        )
                    )
                    .blendMode(.screen)
            )
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(hex: "11121E").opacity(0.38))
                    .blur(radius: 14)
            )
    }

    private var metaLineText: String {
        var chips: [String] = []
        if let genre = show.genre, !genre.isEmpty {
            chips.append(genre)
        }
        if let year = show.year {
            chips.append("\(year)")
        }
        return chips.isEmpty ? "TV series" : chips.joined(separator: "  ·  ")
    }

}

private struct DetailPillPreviewArtwork: View {
    let show: Show

    private var primaryImageURL: URL? {
        (show.imageURL ?? show.previewImageURL).flatMap(URL.init(string:))
    }

    private var fallbackImageURL: URL? {
        guard let previewImageURL = show.previewImageURL,
              previewImageURL != show.imageURL else { return nil }
        return URL(string: previewImageURL)
    }

    var body: some View {
        ZStack {
            fallbackBackground

            if let primaryImageURL {
                AsyncImage(url: primaryImageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                    case .failure:
                        if let fallbackImageURL {
                            AsyncImage(url: fallbackImageURL) { fallbackPhase in
                                switch fallbackPhase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .clipped()
                                case .failure:
                                    fallbackBackground
                                default:
                                    fallbackBackground
                                        .overlay(Color.white.opacity(0.05))
                                }
                            }
                        } else {
                            fallbackBackground
                        }
                    default:
                        fallbackBackground
                            .overlay(Color.white.opacity(0.05))
                    }
                }
            }

            LinearGradient(
                colors: [
                    .clear,
                    Color.black.opacity(0.10),
                    Color.black.opacity(0.34)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 0.7)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var fallbackBackground: some View {
        LinearGradient(
            colors: [
                Color(hex: show.gradient1),
                Color(hex: show.gradient2),
                Color.black.opacity(0.78)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
