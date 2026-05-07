import SwiftUI

// MARK: - Splash screen

enum UniverseLaunchPhase: Int {
    case splash
    case background
    case focalShow
    case constellation
    case planet
    case tabBar
    case complete
}

private struct SplashView: View {
    let reduceMotion: Bool
    var onFinished: () -> Void

    @State private var showS      = false
    @State private var showStar   = false
    @State private var burst      = false
    @State private var dismissing = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ZStack(alignment: .center) {
                Text("S")
                    .font(.custom("Georgia", size: 96).weight(.semibold))
                    .foregroundColor(.white)
                    .opacity(showS ? 1 : 0)
                    .scaleEffect(showS ? 1 : 0.55)
                    .animation(.spring(response: 0.52, dampingFraction: 0.66), value: showS)

                Image(systemName: "sparkle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "E5604A"))
                    .opacity(showStar ? 1 : 0)
                    .scaleEffect(burst ? 1.22 : showStar ? 1 : 0)
                    .offset(x: 34, y: -42)
                    .animation(.spring(response: 0.28, dampingFraction: 0.42), value: showStar)
                    .animation(.spring(response: 0.18, dampingFraction: 0.55), value: burst)
            }
            .scaleEffect(dismissing ? 1.18 : 1)
            .opacity(dismissing ? 0 : 1)
            .animation(.easeOut(duration: reduceMotion ? 0.12 : 0.45), value: dismissing)
        }
        .onAppear {
            if reduceMotion {
                showS = true
                showStar = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) { onFinished() }
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { showS = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.56) { showStar = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.70) {
                burst = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { burst = false }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.28) { dismissing = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.70) { onFinished() }
        }
    }
}

// MARK: - Achievement toast

private struct AchievementToastView: View {
    let milestone: Milestone
    let reduceMotion: Bool
    var onFinished: () -> Void

    @State private var appeared = false
    @State private var progress: CGFloat = 0
    @State private var completed = false
    @State private var dismissed = false

    private var accent: Color {
        Color(hex: milestone.accentHex)
    }

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.14))
                    .frame(width: 36, height: 36)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        accent,
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 36, height: 36)

                Image(systemName: completed ? "checkmark" : milestone.systemImage)
                    .font(.system(size: completed ? 13.5 : 12.5, weight: .bold))
                    .foregroundStyle(completed ? .white : accent)
                    .scaleEffect(completed ? 1.04 : 1)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Achievement unlocked")
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(0.7)
                    .foregroundStyle(accent)
                    .textCase(.uppercase)

                Text(milestone.title)
                    .font(.system(size: 14.2, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(milestone.subtitle)
                    .font(.system(size: 11.8, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Text(milestone.badge)
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
                .padding(.horizontal, 8)
                .frame(height: 25)
                .background(accent.opacity(0.12), in: Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: "101119").opacity(0.82))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.34),
                            Color.white.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: accent.opacity(0.18), radius: 18, y: 10)
        .shadow(color: .black.opacity(0.28), radius: 20, y: 12)
        .opacity(dismissed ? 0 : (appeared ? 1 : 0))
        .offset(y: dismissed ? -28 : (appeared ? 0 : -86))
        .scaleEffect(appeared && !dismissed ? 1 : 0.98, anchor: .top)
        .onAppear {
            runSequence()
        }
        .onChange(of: milestone.id) { _, _ in
            runSequence()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Achievement unlocked, \(milestone.title)")
    }

    private func runSequence() {
        appeared = false
        dismissed = false
        progress = 0
        completed = false

        if reduceMotion {
            appeared = true
            progress = 1
            completed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                onFinished()
            }
            return
        }

        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            appeared = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeInOut(duration: 1.35)) {
                progress = 1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.58) {
            StelrHaptics.success()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) {
                completed = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.55) {
            withAnimation(.easeInOut(duration: 0.24)) {
                dismissed = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.86) {
            onFinished()
        }
    }
}

// MARK: - Persistent planet backdrop

struct PlanetBackdropView: View {
    var rotation: CGFloat = 0
    var horizontalOffset: CGFloat = 0
    var scale: CGFloat = 1.50
    var verticalOffset: CGFloat = 0.22
    var opacity: Double = 0.84
    var blurRadius: CGFloat = 0.35
    var warmth: Color = Color(red: 1.00, green: 0.80, blue: 0.74)
    var glareOpacity: Double = 0.075
    var rimOpacity: Double = 0.055
    var shadowFade: Double = 0.76
    var saturation: Double = 0.90
    var contrast: Double = 0.95
    var brightness: Double = -0.035

    var body: some View {
        GeometryReader { geo in
            let planetWidth = geo.size.width * scale
            let planetCenter = CGPoint(
                x: geo.size.width * 0.50 + horizontalOffset,
                y: geo.size.height + planetWidth * verticalOffset
            )

            ZStack {
                planetImage(width: planetWidth)
                    .colorMultiply(warmth)
                    .saturation(saturation)
                    .contrast(contrast)
                    .brightness(brightness)

                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.18),
                        Color.black.opacity(shadowFade)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: planetWidth, height: planetWidth)
                .clipShape(Circle())

                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.18),
                        Color.black.opacity(shadowFade * 0.88)
                    ],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(width: planetWidth, height: planetWidth)
                .clipShape(Circle())

                RadialGradient(
                    colors: [
                        Color(red: 1.00, green: 0.78, blue: 0.68).opacity(glareOpacity),
                        Color(red: 0.90, green: 0.35, blue: 0.25).opacity(glareOpacity * 0.38),
                        .clear
                    ],
                    center: UnitPoint(x: 0.23, y: 0.11),
                    startRadius: planetWidth * 0.03,
                    endRadius: planetWidth * 0.43
                )
                .frame(width: planetWidth, height: planetWidth)
                .blur(radius: planetWidth * 0.018)
                .blendMode(.softLight)
                .mask(terrainLightNoiseMask(width: planetWidth))
                .clipShape(Circle())

                Circle()
                    .stroke(
                        Color(red: 0.88, green: 0.42, blue: 0.31).opacity(rimOpacity),
                        lineWidth: max(1, planetWidth * 0.002)
                    )
                    .blur(radius: planetWidth * 0.006)
                    .mask(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color.white.opacity(0.32),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(planetWidth * 0.006)
            }
            .overlay {
                RadialGradient(
                    colors: [
                        Color(red: 0.54, green: 0.20, blue: 0.16).opacity(0.045),
                        .clear
                    ],
                    center: UnitPoint(x: 0.40, y: 0.28),
                    startRadius: planetWidth * 0.18,
                    endRadius: planetWidth * 0.74
                )
                .blendMode(.overlay)
                .clipShape(Circle())
            }
            .overlay {
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.12),
                        Color.black.opacity(shadowFade)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: planetWidth, height: planetWidth)
                .clipShape(Circle())
            }
            .frame(width: planetWidth, height: planetWidth)
            .rotationEffect(.degrees(Double(rotation)))
            .opacity(opacity)
            .blur(radius: blurRadius)
            .mask(
                LinearGradient(
                    colors: [
                        .white,
                        .white,
                        Color.white.opacity(0.72),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .position(planetCenter)
            .compositingGroup()
            .allowsHitTesting(false)
        }
    }

    private func planetImage(width: CGFloat) -> some View {
        Image("planet_texture")
            .resizable()
            .scaledToFit()
            .frame(width: width, height: width)
    }

    private func terrainLightNoiseMask(width: CGFloat) -> some View {
        Canvas { context, size in
            let columns = 52
            let rows = 52
            let stepX = size.width / CGFloat(columns)
            let stepY = size.height / CGFloat(rows)

            for row in 0..<rows {
                for column in 0..<columns {
                    let px = (CGFloat(column) + 0.5) / CGFloat(columns)
                    let py = (CGFloat(row) + 0.5) / CGFloat(rows)
                    let dx = (px - 0.23) / 0.34
                    let dy = (py - 0.12) / 0.22
                    let distance = dx * dx + dy * dy
                    let falloff = max(0, 1 - distance)
                    guard falloff > 0 else { continue }

                    let noise = stableNoise(column: column, row: row)
                    let variation = 0.74 + (noise - 0.5) * 0.22
                    let alpha = Double(falloff * falloff) * variation
                    guard alpha > 0.018 else { continue }

                    let rect = CGRect(
                        x: CGFloat(column) * stepX,
                        y: CGFloat(row) * stepY,
                        width: stepX * 1.18,
                        height: stepY * 1.18
                    )
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: min(stepX, stepY) * 0.5),
                        with: .color(.white.opacity(alpha))
                    )
                }
            }
        }
        .blur(radius: width * 0.008)
        .clipShape(Circle())
    }

    private func stableNoise(column: Int, row: Int) -> Double {
        var hash = UInt64(column) &* 374_761_393 &+ UInt64(row) &* 668_265_263
        hash = (hash ^ (hash >> 13)) &* 1_274_126_177
        return Double(hash & 1023) / 1023.0
    }
}

// MARK: - Content

struct ContentView: View {
    @StateObject private var appState = AppState()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedTab: AppTab = .universe
    @State private var friendView: Friend? = nil  // non-nil -> show one friend's profile
    @State private var friendProfileShowId: Int? = nil
    @State private var splashVisible = true
    @State private var backgroundRevealed = false
    @State private var contentRevealed = false
    @State private var tabBarRevealed = false
    @State private var universeLaunchPhase: UniverseLaunchPhase = .splash
    @State private var lastTabVisitedAt: [AppTab: Date] = [:]
    @State private var tabAnimationTokens: [AppTab: Int] = [:]
    @State private var tabShouldAnimate: [AppTab: Bool] = [:]
    @State private var universeExitDownToken = 0
    @State private var activityExitDownToken = 0
    @State private var keyboardVisible = false
    @State private var searchFocusToken = 0

    private let tabAnimationCooldown: TimeInterval = 10

    var body: some View {
        GeometryReader { geo in
            ZStack {
                mainAppContent
                    .allowsHitTesting(contentRevealed)

                if splashVisible {
                    SplashView(
                        reduceMotion: reduceMotion,
                        onFinished: {
                            runPostSplashReveal()
                        }
                    )
                    .ignoresSafeArea()
                }
            }
        }
        .environmentObject(appState)
        .font(StelrTypography.body)
        .buttonStyle(.stelrPress)
        .preferredColorScheme(.dark)
    }

    private var mainAppContent: some View {
        ZStack(alignment: .bottom) {
            sharedSpaceBackground
                .zIndex(0)

            if showsSharedGlossyTabBackdrop {
                StelrFrostedBackdrop()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .zIndex(1)
            }

            if let friend = friendView {
                // ── Single friend profile overlay (Friends -> tap friend) ─────
                ZStack(alignment: .topLeading) {
                    FriendProfileSheet(
                        friend: friend,
                        highlightedShowId: friendProfileShowId,
                        showsCloseButton: false
                    )
                        .environmentObject(appState)

                    // Back button
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            friendView = nil
                            friendProfileShowId = nil
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16.8, weight: .medium))
                        .foregroundColor(.stelrText)
                        .frame(width: 34, height: 34)
                        .background(
                            Color.stelrBg.opacity(0.88)
                                .background(Material.ultraThinMaterial)
                        )
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.stelrBorder, lineWidth: 0.5))
                    }
                    .buttonStyle(.stelrPress)
                    .padding(.top, 58).padding(.leading, 16)
                    .zIndex(100)
                }
                .zIndex(10)
            } else {
                selectedTabView
                    .id(selectedTab)
                    .ignoresSafeArea()
                    .opacity(contentRevealed ? 1 : 0)
                    .offset(y: contentRevealed ? 0 : 46)
                    .scaleEffect(contentRevealed ? 1 : 0.965, anchor: .bottom)
                    .blur(radius: contentRevealed ? 0 : 7)
                    .animation(
                        .spring(response: 0.62, dampingFraction: 0.86, blendDuration: 0.12),
                        value: contentRevealed
                    )
                    .zIndex(10)
            }

            FloatingTabBar(selection: $selectedTab) { tab in
                selectTab(tab)
            }
            .opacity(shouldShowFloatingTabBar ? 1 : 0)
            .offset(y: shouldShowFloatingTabBar ? 0 : 44)
            .scaleEffect(shouldShowFloatingTabBar ? 1 : 0.96)
            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: shouldShowFloatingTabBar)
            .zIndex(1000)
            .allowsHitTesting(shouldShowFloatingTabBar)

            if let milestone = appState.activeAchievementToast, contentRevealed {
                AchievementToastView(
                    milestone: milestone,
                    reduceMotion: reduceMotion,
                    onFinished: {
                        appState.completeAchievementToast(id: milestone.id)
                    }
                )
                .padding(.horizontal, 18)
                .padding(.top, 54)
                .frame(maxHeight: .infinity, alignment: .top)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(2200)
            }
        }
        .animation(.spring(response: 0.44, dampingFraction: 0.84), value: appState.activeAchievementToast?.id)
    }

    private var sharedSpaceBackground: some View {
        ZStack {
            StelrStarFieldBackground()
                .scaleEffect(starFieldLaunchVisibility ? 1 : 1.08)
                .opacity(starFieldLaunchVisibility ? 1 : 0)
                .blur(radius: starFieldLaunchVisibility ? 0 : 18)
                .animation(.spring(response: 0.52, dampingFraction: 0.84), value: starFieldLaunchVisibility)
                .ignoresSafeArea()

            PlanetBackdropView(
                rotation: 0,
                horizontalOffset: 0
            )
            .offset(y: planetLaunchVisibility ? 0 : 180)
            .scaleEffect(planetLaunchVisibility ? 1 : 1.12)
            .opacity(planetLaunchVisibility ? (selectedTab == .search ? 0.66 : 1.0) : 0)
            .animation(.spring(response: 0.58, dampingFraction: 0.84), value: planetLaunchVisibility)
            .opacity(selectedTab == .search ? 0.66 : 1.0)
            .animation(.easeInOut(duration: 0.42), value: selectedTab)
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    private var shouldShowFloatingTabBar: Bool {
        tabBarLaunchVisibility && !appState.isShowDetailPresented && !(selectedTab == .search && keyboardVisible)
    }

    @ViewBuilder
    private var selectedTabView: some View {
        switch selectedTab {
        case .universe:
            // Constellation — social home screen
            ConstellationView(
                animateEntrance: (tabShouldAnimate[.universe] ?? true) && !splashVisible,
                animationToken: tabAnimationTokens[.universe, default: 0],
                exitDownToken: universeExitDownToken,
                launchPhase: contentRevealed ? nil : universeLaunchPhase,
                onFriendTap: { friend, showId in
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        friendProfileShowId = showId
                        friendView = friend
                    }
                }
            )
        case .search:
            // Search — find shows and add them to your lists
            SearchTabView(
                animateEntrance: tabShouldAnimate[.search] ?? true,
                animationToken: tabAnimationTokens[.search, default: 0],
                focusToken: searchFocusToken,
                isKeyboardVisible: $keyboardVisible
            )
        case .activity:
            // Activity — chronological friend check-in feed
            FeedView(
                animateEntrance: tabShouldAnimate[.activity] ?? true,
                animationToken: tabAnimationTokens[.activity, default: 0],
                exitDownToken: activityExitDownToken,
                showsBackdrop: false,
                onFriendTap: { friend in
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        friendProfileShowId = nil
                        friendView = friend
                    }
                }
            )
        case .ranking:
            // Rankings — friend leaderboard across influence and seasons watched
            RankingTabView(
                animateEntrance: tabShouldAnimate[.ranking] ?? true,
                animationToken: tabAnimationTokens[.ranking, default: 0]
            )
        case .profile:
            // Me — profile + active shows (My Rotation lives here, not a separate tab)
            YouTabView(
                animateEntrance: tabShouldAnimate[.profile] ?? true,
                animationToken: tabAnimationTokens[.profile, default: 0],
                showsBackdrop: false
            )
        }
    }

    private func selectTab(_ tab: AppTab) {
        guard tab != selectedTab else {
            if tab == .search {
                searchFocusToken += 1
            }
            return
        }

        let previousTab = selectedTab
        friendView = nil
        friendProfileShowId = nil
        keyboardVisible = false
        markTabVisited(previousTab)
        visitTab(tab, forceAnimate: true)
        selectedTab = tab
        if tab == .search {
            searchFocusToken += 1
        }
    }

    private func visitTab(_ tab: AppTab, forceAnimate: Bool = false) {
        let now = Date()
        let shouldAnimate = forceAnimate || (lastTabVisitedAt[tab].map {
            now.timeIntervalSince($0) >= tabAnimationCooldown
        } ?? true)
        lastTabVisitedAt[tab] = now
        tabShouldAnimate[tab] = shouldAnimate
        if shouldAnimate {
            tabAnimationTokens[tab, default: 0] += 1
        }
    }

    private func markTabVisited(_ tab: AppTab) {
        lastTabVisitedAt[tab] = Date()
    }

    private func runPostSplashReveal() {
        if reduceMotion {
            universeLaunchPhase = .complete
            splashVisible = false
            backgroundRevealed = true
            contentRevealed = true
            tabBarRevealed = true
            visitTab(selectedTab, forceAnimate: true)
            return
        }

        universeLaunchPhase = .background

        withAnimation(.easeOut(duration: 0.18)) {
            splashVisible = false
        }

        withAnimation(.spring(response: 0.64, dampingFraction: 0.90, blendDuration: 0.14)) {
            backgroundRevealed = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            // Let ConstellationView settle into its final internal layout while
            // the tab content is still hidden. The outer reveal then does the
            // only visible entrance animation, avoiding a small second snap.
            universeLaunchPhase = .complete
            tabShouldAnimate[selectedTab] = false
            markTabVisited(selectedTab)

            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.66, dampingFraction: 0.82, blendDuration: 0.12)) {
                    contentRevealed = true
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
            withAnimation(.spring(response: 0.54, dampingFraction: 0.84, blendDuration: 0.10)) {
                tabBarRevealed = true
            }
        }
    }

    private var starFieldLaunchVisibility: Bool {
        backgroundRevealed
    }

    private var planetLaunchVisibility: Bool {
        backgroundRevealed
    }

    private var tabBarLaunchVisibility: Bool {
        tabBarRevealed
    }

    private var showsSharedGlossyTabBackdrop: Bool {
        selectedTab == .activity || selectedTab == .ranking || selectedTab == .profile
    }

}
