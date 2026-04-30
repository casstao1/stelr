import SwiftUI

// MARK: - Private data types

private struct ShowNode {
    let show: Show
    let pos: CGPoint
    let watchers: [Friend]
    var isShared: Bool { watchers.count > 1 }
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

// MARK: - Main view

struct ConstellationView: View {
    var animateEntrance: Bool = true
    var animationToken: Int = 0
    @EnvironmentObject var appState: AppState
    @State private var selShowId:   Int? = nil
    @State private var selFriendId: Int? = nil
    @State private var appeared = false
    @State private var detailShow: Show? = nil

    private let maxVisibleShows = 8

    // Hand-tuned fractional positions matching the mockup (key = show.id in sample data)
    // Based on a 390 × 660 reference canvas
    private let showFracs: [Int: (CGFloat, CGFloat)] = [
        0: (122/390, 162/660),   // Severance    — upper-left
        3: (296/390, 148/660),   // Adolescence  — upper-right
        4: (202/390, 320/660),   // Slow Horses  — center (3 watchers)
        1: ( 82/390, 445/660),   // Last of Us   — lower-left
        2: (308/390, 448/660),   // White Lotus  — lower-right
    ]
    private let dynamicFracs: [(CGFloat, CGFloat)] = [
        (0.31, 0.22), (0.69, 0.20), (0.50, 0.39), (0.22, 0.53),
        (0.78, 0.53), (0.34, 0.72), (0.66, 0.72), (0.50, 0.60)
    ]
    // Orbit radius = 56 pt on 390 wide → fraction
    private let orbitFrac: CGFloat = 56 / 390

    var body: some View {
        GeometryReader { geo in
            let nodes = buildNodes(size: geo.size)
            let instances = focusedOrbitInstances(
                buildInstances(nodes: nodes, size: geo.size),
                nodes: nodes,
                size: geo.size
            )

            ZStack {
                Color(hex: "07060e").ignoresSafeArea()

                // ── Orbital canvas ────────────────────────────────────────
                ZStack {
                    // Star field
                    Canvas { ctx, size in
                        drawStars(ctx: ctx, size: size)
                    }

                    // Spokes — SwiftUI Path views so opacity animates on selection
                    ForEach(instances) { inst in
                        if let node = nodes.first(where: { $0.show.id == inst.showId }) {
                            Path { p in
                                p.move(to: node.pos)
                                p.addLine(to: inst.pos)
                            }
                            .stroke(
                                Color(hex: node.show.accentColor)
                                    .opacity(dimmedInst(inst) ? 0.03 : 0.22),
                                lineWidth: 0.6
                            )
                            .frame(width: geo.size.width, height: geo.size.height)
                            .opacity(appeared ? 1 : 0)
                            .animation(.easeInOut(duration: 0.22).delay(0.24), value: appeared)
                            .animation(.easeInOut(duration: 0.28), value: selShowId)
                            .animation(.easeInOut(duration: 0.28), value: selFriendId)
                        }
                    }

                    // Show nodes
                    ForEach(Array(nodes.enumerated()), id: \.element.show.id) { idx, node in
                        ShowNodeView(
                            node: node,
                            isActive: selShowId == node.show.id,
                            isDimmed: dimmedShow(node.show.id)
                        )
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.2)
                        .offset(y: ShowNodeView.dotAnchorCorrection(isActive: selShowId == node.show.id))
                        .position(node.pos)
                        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: selShowId)
                        .animation(
                            .spring(response: 0.26, dampingFraction: 0.68)
                                .delay(0.02 + Double(idx) * 0.032),
                            value: appeared
                        )
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                                selFriendId = nil
                                selShowId   = selShowId == node.show.id ? nil : node.show.id
                            }
                        }
                    }

                    // Friend instances
                    ForEach(Array(instances.enumerated()), id: \.element.id) { idx, inst in
                        FriendInstanceView(
                            instance: inst,
                            showLabel: (inst.friend.map { selFriendId == $0.id } ?? false) || selShowId == inst.showId,
                            isDimmed: dimmedInst(inst)
                        )
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.15)
                        .position(inst.pos)
                        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: selShowId)
                        .animation(
                            .spring(response: 0.24, dampingFraction: 0.7)
                                .delay(0.07 + Double(idx) * 0.02),
                            value: appeared
                        )
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                                selShowId   = nil
                                guard !inst.isCurrentUser, let friend = inst.friend else { return }
                                selFriendId = selFriendId == friend.id ? nil : friend.id
                            }
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(focusedMapScale)
                .animation(.spring(response: 0.46, dampingFraction: 0.72), value: selShowId)
                .onAppear {
                    runEntranceAnimation(animated: animateEntrance)
                }
                .onChange(of: animationToken) { _, _ in
                    runEntranceAnimation(animated: animateEntrance)
                }

                // ── Header ────────────────────────────────────────────────
                VStack(spacing: 0) {
                    headerRow
                        .padding(.top, 66).padding(.horizontal, 20).padding(.bottom, 6)
                    Spacer()
                }

                // ── Bottom zone: selected show detail pill ────────────────
                if let sid = selShowId, let show = appState.show(for: sid) {
                    VStack(spacing: 0) {
                        Spacer()
                        ZStack {
                            let watchers = appState.friendsWatching(showId: sid)
                            DetailPill(show: show, watchers: watchers, vibe: vibeFor(show: show)) {
                                detailShow = show
                            } onDismiss: {
                                withAnimation(.spring(response: 0.3)) { selShowId = nil }
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal:   .move(edge: .bottom).combined(with: .opacity)
                            ))
                            .padding(.horizontal, 12)
                        }
                        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: selShowId)
                        .padding(.bottom, 94)
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
                            nodes: nodes,
                            instances: instances
                        )
                    }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .sheet(item: $detailShow) { show in
            ShowDetailView(show: show, watchingFriends: appState.friendsWatching(showId: show.id))
        }
    }

    private var focusedMapScale: CGFloat {
        selShowId == nil ? 1 : 1.07
    }

    private func runEntranceAnimation(animated: Bool) {
        if animated {
            appeared = false
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
                    appeared = true
                }
            }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                appeared = true
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

    private func clearSelectionIfBackgroundTap(
        at location: CGPoint,
        nodes: [ShowNode],
        instances: [FriendInstance]
    ) {
        guard selShowId != nil || selFriendId != nil else { return }
        guard !isPoint(location, nearAnyShowNode: nodes) else { return }
        guard !isPoint(location, nearAnyFriendInstance: instances) else { return }
        clearSelection()
    }

    private func isPoint(_ point: CGPoint, nearAnyShowNode nodes: [ShowNode]) -> Bool {
        nodes.contains { node in
            distance(from: point, to: node.pos) <= 48
        }
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
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("constellation")
                    .font(.custom("Georgia", size: 26.9).weight(.semibold))
                    .foregroundColor(.stelrText)
                Text(subtitleText)
                    .font(.system(size: 12.3)).foregroundColor(.stelrMuted)
            }
            Spacer()
            if selShowId != nil || selFriendId != nil {
                Button {
                    withAnimation(.spring(response: 0.28)) {
                        selShowId = nil; selFriendId = nil
                    }
                } label: {
                    Text("✕")
                        .font(.system(size: 12.3)).foregroundColor(.stelrMuted)
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
        return "\(appState.friends.count) friends across \(visible)\(total > visible ? " recent" : "") shows"
    }

    // MARK: - Data builders

    private func buildNodes(size: CGSize) -> [ShowNode] {
        var watcherMap: [Int: [Friend]] = [:]
        for friend in appState.friends {
            for showId in friend.watchedShowIds {
                watcherMap[showId, default: []].append(friend)
            }
        }

        return visibleShows().enumerated().map { index, show in
            let frac = positionFraction(for: show, index: index)
            let pos = CGPoint(x: size.width * frac.0, y: size.height * frac.1)
            return ShowNode(show: show, pos: pos, watchers: watcherMap[show.id] ?? [])
        }
    }

    private func visibleShows() -> [Show] {
        var orderedIds: [Int] = []

        for activity in appState.activities {
            appendUnique(activity.showId, to: &orderedIds)
        }

        for friend in appState.friends where friend.isActive {
            for showId in friend.watchedShowIds {
                appendUnique(showId, to: &orderedIds)
            }
        }

        for friend in appState.friends {
            for showId in friend.watchedShowIds {
                appendUnique(showId, to: &orderedIds)
            }
        }

        for show in appState.shows {
            appendUnique(show.id, to: &orderedIds)
        }

        return orderedIds
            .prefix(maxVisibleShows)
            .compactMap { appState.show(for: $0) }
    }

    private func appendUnique(_ showId: Int, to ids: inout [Int]) {
        guard !ids.contains(showId) else { return }
        ids.append(showId)
    }

    private func positionFraction(for show: Show, index: Int) -> (CGFloat, CGFloat) {
        if appState.shows.count <= showFracs.count, let frac = showFracs[show.id] {
            return frac
        }
        return dynamicFracs[index % dynamicFracs.count]
    }

    private func buildInstances(nodes: [ShowNode], size: CGSize) -> [FriendInstance] {
        var result: [FriendInstance] = []
        for node in nodes {
            let r = orbitRadius(size: size)
            let includesCurrentUser = appState.myShows.contains(where: { $0.showId == node.show.id })
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

    // MARK: - Title collision avoidance

    private func focusedOrbitInstances(
        _ instances: [FriendInstance],
        nodes: [ShowNode],
        size: CGSize
    ) -> [FriendInstance] {
        guard let sid = selShowId,
              let node = nodes.first(where: { $0.show.id == sid }) else {
            return instances
        }

        var adjusted = instances
        let activeIndices = Array(adjusted.indices.filter { adjusted[$0].showId == sid })
        let r = orbitRadius(size: size)
        let titleAngle: CGFloat = -.pi / 2
        let gap = titleAvoidanceAngle(for: node, radius: r)
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

    private func titleAvoidanceAngle(for node: ShowNode, radius: CGFloat) -> CGFloat {
        let titleHalfWidth = max(43, CGFloat(node.show.title.count) * 4.2 + 22)
        let avatarClearance: CGFloat = 22
        return min(1.28, atan2(titleHalfWidth + avatarClearance, radius) + 0.18)
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
        appState.myShows.first(where: { $0.showId == show.id })?.vibe ?? .justOk
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

    // MARK: - Canvas drawing

    private func drawStars(ctx: GraphicsContext, size: CGSize) {
        for i in 0..<55 {
            let x  = CGFloat(Double(i) * 137.5).truncatingRemainder(dividingBy: size.width)
            let y  = CGFloat(Double(i) * 97.3 + 20).truncatingRemainder(dividingBy: size.height)
            let r: CGFloat = i % 4 == 0 ? 1.3 : 0.65
            let o: Double  = 0.06 + Double(i % 6) * 0.035
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)),
                     with: .color(.white.opacity(o)))
        }
    }


}

// MARK: - Show node view

private struct ShowNodeView: View {
    let node: ShowNode
    let isActive: Bool
    let isDimmed: Bool

    private var accent: Color { Color(hex: node.show.accentColor) }
    private var dotSize: CGFloat {
        if isActive { return 20 }
        switch node.watchers.count {
        case 0, 1: return 10
        case 2:    return 13
        default:   return 17
        }
    }

    static func dotAnchorCorrection(isActive: Bool) -> CGFloat {
        isActive ? -15 : -13
    }

    var body: some View {
        VStack(spacing: 0) {
            // Label above dot
            Text(node.show.title)
                .font(Font.custom("Georgia", size: isActive ? 14 : 12).italic())
                .foregroundColor(isActive ? accent : .white.opacity(0.42))
                .shadow(color: accent.opacity(0.5), radius: 6)
                .fixedSize()
                .lineLimit(1)
                .padding(.bottom, 8)
                .animation(.easeInOut(duration: 0.2), value: isActive)

            ZStack {
                // Glow halo
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [accent.opacity(isActive ? 0.33 : 0.17), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: isActive ? 32 : 18
                        )
                    )
                    .frame(width: isActive ? 64 : 36, height: isActive ? 64 : 36)

                // Dashed outer ring for multi-watcher shows
                if node.watchers.count > 1 && !isActive {
                    Circle()
                        .stroke(accent.opacity(0.35), style: StrokeStyle(lineWidth: 0.8, dash: [3, 5]))
                        .frame(width: dotSize + 8, height: dotSize + 8)
                }

                // Core dot
                Circle()
                    .fill(accent)
                    .frame(width: dotSize, height: dotSize)
                    .shadow(color: accent.opacity(isActive ? 0.9 : 0.6),
                            radius: isActive ? 10 : node.watchers.count > 1 ? 6 : 4)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isActive)
        }
        .opacity(isDimmed ? 0.15 : 1)
        .animation(.easeInOut(duration: 0.3), value: isDimmed)
    }
}

// MARK: - Friend instance view

private struct FriendInstanceView: View {
    let instance: FriendInstance
    let showLabel: Bool
    let isDimmed: Bool

    private var initials: String {
        instance.isCurrentUser ? "ME" : instance.friend?.initials ?? "?"
    }

    private var hexColor: String {
        instance.isCurrentUser ? "EDE5D8" : instance.friend?.hexColor ?? "8A8070"
    }

    private var label: String {
        instance.isCurrentUser ? "you" : instance.friend?.name ?? ""
    }

    var body: some View {
        VStack(spacing: 3) {
            AvatarView(initials: initials, hexColor: hexColor,
                       size: showLabel ? 30 : 24, showBorder: showLabel)
            if showLabel {
                Text(label)
                    .font(.system(size: 10.6, weight: .medium))
                    .foregroundColor(Color(hex: hexColor))
                    .fixedSize()
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .opacity(isDimmed ? 0.12 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: showLabel)
        .animation(.easeInOut(duration: 0.3), value: isDimmed)
    }
}

// MARK: - Detail pill (shown when a show node is selected)

private struct DetailPill: View {
    let show: Show
    let watchers: [Friend]
    let vibe: VibeOption
    var onViewDetail: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Show preview
            HStack(alignment: .top, spacing: 10) {
                ShowPosterView(show: show, width: 56, height: 76, radius: 10) {
                    VStack {
                        Spacer()
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.75)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 34)
                        .overlay(
                            Text(show.platform)
                                .font(.system(size: 8.4, weight: .medium))
                                .foregroundColor(.white.opacity(0.72))
                                .lineLimit(1)
                                .padding(.horizontal, 5)
                                .padding(.bottom, 5),
                            alignment: .bottomLeading
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(show.title)
                            .font(.custom("Georgia", size: 16.8).italic())
                            .foregroundColor(.stelrText)
                            .lineLimit(1)

                        if watchers.count > 1 {
                            Text("\(watchers.count) in orbit")
                                .font(.system(size: 10.6))
                                .foregroundColor(Color(hex: show.accentColor))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color(hex: show.accentColor).opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    HStack(spacing: 6) {
                        if let genre = show.genre {
                            Text(genre)
                        }
                        if let year = show.year {
                            Text("·")
                            Text("\(year)")
                        }
                    }
                    .font(.system(size: 10.6))
                    .foregroundColor(.stelrMuted.opacity(0.85))

                    Text(previewSummary)
                        .font(.system(size: 11.8))
                        .foregroundColor(.stelrMuted)
                        .lineSpacing(1)
                        .lineLimit(2)

                    if !watchers.isEmpty {
                        compactWatchersRow
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.bottom, 9)

            // View full details button
            Button(action: onViewDetail) {
                HStack(spacing: 6) {
                    Text("View full details")
                        .font(.system(size: 12.9, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11.2, weight: .medium))
                }
                .foregroundColor(Color(hex: show.accentColor))
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(Color(hex: show.accentColor).opacity(0.13))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: show.accentColor).opacity(0.34), lineWidth: 0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.stelrPress)
        }
        .padding(11)
        .background(Color(hex: "0a080e").opacity(0.96))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(hex: show.accentColor).opacity(0.25), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var previewSummary: String {
        show.summary ?? "No summary available yet."
    }

    private var compactWatchersRow: some View {
        HStack(spacing: 6) {
            ForEach(watchers.prefix(3)) { friend in
                AvatarView(initials: friend.initials, hexColor: friend.hexColor, size: 18)
            }
            Text(watchers.map(\.name).prefix(2).joined(separator: ", "))
                .font(.system(size: 10.6, weight: .medium))
                .foregroundColor(.stelrText.opacity(0.75))
                .lineLimit(1)
            if watchers.count > 2 {
                Text("+\(watchers.count - 2)")
                    .font(.system(size: 10.6, weight: .semibold))
                    .foregroundColor(Color(hex: show.accentColor))
            }
            Spacer(minLength: 0)
        }
    }
}
