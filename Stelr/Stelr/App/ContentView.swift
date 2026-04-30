import SwiftUI

// MARK: - Splash screen

private struct SplashView: View {
    var onFinished: () -> Void

    @State private var showS      = false
    @State private var showStar   = false
    @State private var burst      = false
    @State private var dismissing = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ZStack(alignment: .center) {
                // "S" wordmark
                Text("S")
                    .font(.custom("Georgia", size: 96).weight(.semibold))
                    .foregroundColor(.white)
                    .opacity(showS ? 1 : 0)
                    .scaleEffect(showS ? 1 : 0.55)
                    .animation(.spring(response: 0.52, dampingFraction: 0.66), value: showS)

                // Star sparkle — top-right of the S
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
            .animation(.easeOut(duration: 0.45), value: dismissing)
        }
        .onAppear {
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

// MARK: - Content

struct ContentView: View {
    @StateObject private var appState = AppState()
    @State private var selectedTab = 0
    @State private var friendView: Friend? = nil  // non-nil -> show one friend's profile
    @State private var splashVisible = true
    @State private var lastTabVisitedAt: [Int: Date] = [:]
    @State private var tabAnimationTokens: [Int: Int] = [:]
    @State private var tabShouldAnimate: [Int: Bool] = [:]

    private let tabAnimationCooldown: TimeInterval = 10

    var body: some View {
        ZStack {
            if splashVisible {
                SplashView {
                    visitTab(selectedTab)
                    splashVisible = false
                }
                .ignoresSafeArea()
            } else {
                mainAppContent
            }
        }
        .background(Color.stelrBg)
        .ignoresSafeArea()
        .environmentObject(appState)
        .buttonStyle(.stelrPress)
        .preferredColorScheme(.dark)
    }

    private var mainAppContent: some View {
        ZStack(alignment: .bottom) {
            if let friend = friendView {
                // ── Single friend profile overlay (Friends -> tap friend) ─────
                ZStack(alignment: .topLeading) {
                    FriendProfileSheet(friend: friend, showsCloseButton: false)
                        .environmentObject(appState)

                    // Back button
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            friendView = nil
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
                    .padding(.top, 86).padding(.leading, 16)
                    .zIndex(100)
                }
            } else {
                selectedTabView
                    .ignoresSafeArea()
            }

            BottomTabBar(selectedTab: $selectedTab) { tab in
                friendView = nil
                markTabVisited(selectedTab)
                visitTab(tab)
                selectedTab = tab
            }
        }
    }

    @ViewBuilder
    private var selectedTabView: some View {
        switch selectedTab {
        case 0:
            ConstellationView(
                animateEntrance: tabShouldAnimate[0] ?? true,
                animationToken: tabAnimationTokens[0, default: 0]
            )
        case 1:
            FeedView(
                animateEntrance: tabShouldAnimate[1] ?? true,
                animationToken: tabAnimationTokens[1, default: 0],
                onFriendTap: { friend in
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    friendView = friend
                }
            })
        case 2:
            RotationView(
                animateEntrance: tabShouldAnimate[2] ?? true,
                animationToken: tabAnimationTokens[2, default: 0]
            )
        default:
            ProfileView()
        }
    }

    private func visitTab(_ tab: Int) {
        let now = Date()
        let shouldAnimate = lastTabVisitedAt[tab].map {
            now.timeIntervalSince($0) >= tabAnimationCooldown
        } ?? true
        lastTabVisitedAt[tab] = now
        tabShouldAnimate[tab] = shouldAnimate
        if shouldAnimate {
            tabAnimationTokens[tab, default: 0] += 1
        }
    }

    private func markTabVisited(_ tab: Int) {
        lastTabVisitedAt[tab] = Date()
    }
}
