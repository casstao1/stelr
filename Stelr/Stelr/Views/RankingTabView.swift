import SwiftUI

// MARK: - RankingTabView

struct RankingTabView: View {
    var animateEntrance: Bool = true
    var animationToken: Int = 0

    @EnvironmentObject var appState: AppState
    @State private var selectedDimension: RankingDimension = .seasons
    @State private var contentAppeared = false
    @State private var profileFriend: Friend?

    // Sorted leaderboard for the active dimension
    private var ranked: [FriendRankEntry] {
        appState.friendRankings
            .sorted { $0.score(for: selectedDimension) > $1.score(for: selectedDimension) }
    }

    // Your entry and position in the active dimension
    private var yourEntry: FriendRankEntry? {
        appState.friendRankings.first(where: { $0.isYou })
    }

    private func yourRank(for dimension: RankingDimension) -> Int {
        let sorted = appState.friendRankings
            .sorted { $0.score(for: dimension) > $1.score(for: dimension) }
        return (sorted.firstIndex(where: { $0.isYou }) ?? 0) + 1
    }

    var body: some View {
        ZStack {
            StelrFrostedBackdrop()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.horizontal, 26)
                        .padding(.top, 72)
                        .padding(.bottom, 16)

                    dimensionPicker
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)

                    rankingDescription
                        .padding(.horizontal, 22)
                        .padding(.bottom, 18)

                    leaderboard
                        .padding(.horizontal, 20)

                    Spacer(minLength: 120)
                }
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 60)
                .animation(.spring(response: 0.62, dampingFraction: 0.82), value: contentAppeared)
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear { runEntranceAnimation() }
        .onChange(of: animationToken) { _, _ in runEntranceAnimation() }
        .sheet(item: $profileFriend) { friend in
            FriendProfileSheet(friend: friend)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Rankings")
                .font(StelrTypography.pageTitle)
                .foregroundColor(.stelrText)
            Text("among your crew")
                .font(.system(size: 13.5))
                .foregroundColor(.stelrMuted)
        }
    }

    // MARK: Your rank summary card

    private var yourRankCard: some View {
        HStack(spacing: 0) {
            ForEach(RankingDimension.allCases) { dim in
                let rank = yourRank(for: dim)
                let isSelected = dim == selectedDimension

                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        selectedDimension = dim
                    }
                } label: {
                    VStack(spacing: 5) {
                        Text(rankOrdinal(rank))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(isSelected ? .stelrAccent : .stelrText.opacity(0.6))
                            .monospacedDigit()
                            .contentTransition(.numericText())

                        Text(dim.rawValue)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(isSelected ? .stelrAccent.opacity(0.85) : .stelrMuted)
                            .textCase(.uppercase)
                            .tracking(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 13)
                            .fill(isSelected
                                  ? Color.stelrAccent.opacity(0.12)
                                  : Color.clear)
                    )
                }
                .buttonStyle(.stelrPress)

                if dim != RankingDimension.allCases.last {
                    Rectangle()
                        .fill(Color.stelrBorder)
                        .frame(width: 0.6)
                        .padding(.vertical, 14)
                }
            }
        }
        .padding(.horizontal, 6)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.stelrBorder, lineWidth: 0.6)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Dimension picker

    private var dimensionPicker: some View {
        HStack(spacing: 8) {
            ForEach(RankingDimension.allCases) { dim in
                let isSelected = dim == selectedDimension
                Button {
                    StelrHaptics.lightTap()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        selectedDimension = dim
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: dim.icon)
                            .font(.system(size: 11.5, weight: .semibold))
                        Text(dim.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(isSelected ? .white : .stelrMuted)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(isSelected
                                  ? Color.stelrAccent.opacity(0.88)
                                  : Color.white.opacity(0.07))
                    )
                    .overlay(
                        Capsule()
                            .stroke(isSelected
                                    ? Color.clear
                                    : Color.stelrBorder, lineWidth: 0.6)
                    )
                }
                .buttonStyle(.stelrPress)
            }
            Spacer()
        }
    }

    private var rankingDescription: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: selectedDimension.icon)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Color.stelrAccent.opacity(0.82))
                .frame(width: 14, height: 14)

            Text(selectedDimension.description)
                .font(.system(size: 12.2, weight: .regular))
                .foregroundColor(.stelrMuted.opacity(0.72))
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.065), lineWidth: 0.6)
        )
        .animation(.easeInOut(duration: 0.18), value: selectedDimension)
    }

    // MARK: Leaderboard

    private var leaderboard: some View {
        VStack(spacing: 0) {
            let entries = ranked
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                Button {
                    guard !entry.isYou, let friend = appState.friend(for: entry.id) else { return }
                    StelrHaptics.lightTap()
                    profileFriend = friend
                } label: {
                    LeaderboardRow(
                        rank: index + 1,
                        entry: entry,
                        dimension: selectedDimension
                    )
                }
                .buttonStyle(.plain)
                .disabled(entry.isYou)

                if index < entries.count - 1 {
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 0.6)
                        .padding(.leading, 64)
                }
            }
        }
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.stelrBorder, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: Helpers

    private func rankOrdinal(_ n: Int) -> String {
        switch n {
        case 1:  return "#1"
        case 2:  return "#2"
        case 3:  return "#3"
        default: return "#\(n)"
        }
    }

    private func runEntranceAnimation() {
        contentAppeared = false
        if animateEntrance {
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.62, dampingFraction: 0.82)) {
                    contentAppeared = true
                }
            }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { contentAppeared = true }
        }
    }
}

// MARK: - LeaderboardRow

private struct LeaderboardRow: View {
    let rank: Int
    let entry: FriendRankEntry
    let dimension: RankingDimension

    private var score: Int { entry.score(for: dimension) }

    private var rankColor: Color {
        switch rank {
        case 1:  return Color(hex: "F5C842")   // gold
        case 2:  return Color(hex: "C0C8D8")   // silver
        case 3:  return Color(hex: "C8855A")   // bronze
        default: return .stelrMuted
        }
    }

    private var isTop3: Bool { rank <= 3 }

    var body: some View {
        HStack(spacing: 14) {

            // Rank badge
            ZStack {
                if isTop3 {
                    Circle()
                        .fill(rankColor.opacity(0.14))
                        .frame(width: 32, height: 32)
                }
                Text("\(rank)")
                    .font(.system(size: isTop3 ? 13 : 12.5,
                                  weight: isTop3 ? .bold : .semibold,
                                  design: .rounded))
                    .foregroundColor(isTop3 ? rankColor : .stelrMuted.opacity(0.55))
                    .monospacedDigit()
            }
            .frame(width: 32)

            // Avatar
            AvatarView(initials: entry.initials,
                       hexColor: entry.hexColor,
                       imageURL: entry.imageURL,
                       size: 40)
            .overlay(
                Circle()
                    .stroke(entry.isYou
                            ? Color.stelrAccent.opacity(0.55)
                            : Color.clear,
                            lineWidth: 1.5)
            )

            // Name + username
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(entry.displayName)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundColor(.stelrText)
                        .lineLimit(1)
                    if entry.isYou {
                        Text("you")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(.stelrAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.stelrAccent.opacity(0.14), in: Capsule())
                    }
                }
                Text("@\(entry.username)")
                    .font(.system(size: 12))
                    .foregroundColor(.stelrMuted.opacity(0.7))
                    .lineLimit(1)
            }

            Spacer()

            // Score
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(score)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(score == 0
                                     ? .stelrMuted.opacity(0.4)
                                     : (isTop3 ? rankColor : .stelrText))
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Text(dimension.unitLabel)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(.stelrMuted.opacity(0.6))
                    .textCase(.lowercase)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(
            entry.isYou
                ? Color.stelrAccent.opacity(0.07)
                : Color.clear
        )
    }
}
