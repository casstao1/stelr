import PhotosUI
import SwiftUI

// "Me" tab — your profile identity + active shows (My Shows) in one place.
// My Shows is not a separate tab; it lives here per the product handoff spec.

private enum MeSkySection: String, CaseIterable, Identifiable {
    case tonight = "All shows"
    case lists = "My Lists"
    case watchlist = "Watch Later"

    var id: String { rawValue }
}

struct YouTabView: View {
    var animateEntrance: Bool = true
    var animationToken: Int = 0
    var showsBackdrop: Bool = true

    @EnvironmentObject var appState: AppState
    @AppStorage("meProfileBio") private var profileBio = ""
    @AppStorage("meProfileImageData") private var profileImageData = Data()

    @State private var showAuthSheet   = false
    @State private var showSignInSheet = false
    @State private var showProfileEditor = false
    @State private var checkInShow: Show?
    @State private var actionShow: Show?
    @State private var detailShow: Show?
    @State private var mustWatchShow: Show?
    @State private var showSearch      = false
    @State private var showCreateList  = false
    @State private var editingList: ShowList? = nil
    @State private var selectedSection: MeSkySection = .tonight
    @State private var contentAppeared = false

    var body: some View {
        ZStack {
            if showsBackdrop {
                StelrFrostedBackdrop()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    meProfileHeader
                        .padding(.horizontal, 26)
                        .padding(.top, 78)
                        .padding(.bottom, 16)

                    meSectionPicker
                        .padding(.horizontal, 18)
                        .padding(.bottom, 24)

                    meSelectedSectionContent
                        .padding(.horizontal, 24)

                    Spacer(minLength: 118)
                }
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 76)
                .animation(.spring(response: 0.62, dampingFraction: 0.82), value: contentAppeared)
            }
            .ignoresSafeArea(edges: .top)

        }
        .sheet(item: $actionShow) { show in
            ShowActionSheet(
                show: show,
                onViewShow: { detailShow = show },
                onCheckIn: { checkInShow = show }
            )
        }
        .sheet(item: $checkInShow) { show in
            VibeCheckSheet(show: show, currentMyShow: appState.myShow(for: show.id)) { season, episode, score in
                appState.submitCheckIn(show: show, season: season, episode: episode, score: score)
            } onSeasonRating: { season, rating in
                appState.submitSeasonRating(showId: show.id, season: season, score: rating)
            }
        }
        .sheet(item: $detailShow) { show in
            ShowDetailView(show: show, watchingFriends: appState.friendsWatching(showId: show.id))
        }
        .sheet(item: $mustWatchShow) { show in
            MustWatchAlertSheet(show: show)
        }
        .sheet(isPresented: $showSearch) {
            ShowSearchSheet()
        }
        .sheet(isPresented: $showCreateList, onDismiss: { editingList = nil }) {
            CreateListSheet(editingList: editingList)
                .environmentObject(appState)
        }
        .sheet(isPresented: $showAuthSheet) {
            ProfileSettingsSheet(
                onSignIn: {
                    showAuthSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                        showSignInSheet = true
                    }
                },
                onEditProfile: {
                    showAuthSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                        showProfileEditor = true
                    }
                }
            )
            .environmentObject(appState)
        }
        .sheet(isPresented: $showSignInSheet) {
            AuthSheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showProfileEditor) {
            ProfileEditProfileSheet(bio: $profileBio, imageData: $profileImageData)
        }
        .onAppear { runEntranceAnimation() }
        .onChange(of: animationToken) { _, _ in runEntranceAnimation() }
    }

    private var meProfileHeader: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .center, spacing: 10) {
                ProfilePhotoAvatar(imageData: profileImageData, size: 92)
                    .accessibilityLabel("Profile picture")

                VStack(spacing: 3) {
                    Text("Alex Reeves")
                        .font(StelrTypography.sectionTitle)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text("@alexreeves")
                        .font(StelrTypography.metadata)
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .center, spacing: 30) {
                    meProfileStat(value: "\(max(127, watchedEpisodeCount))", label: "eps")
                    meProfileStat(value: "\(max(42, appState.shows.count))", label: "shows")
                    meProfileStat(value: "\(min(6, appState.friends.count))", label: "friends")
                }
                .padding(.top, 2)

                Text(profileBio.isEmpty ? "No bio yet" : profileBio)
                    .font(StelrTypography.metadata)
                    .foregroundStyle(profileBio.isEmpty ? .tertiary : .secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 310)
                    .padding(.top, 1)
            }
            .frame(maxWidth: .infinity)

            Button { showAuthSheet = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14.4, weight: .medium))
                    .foregroundColor(.stelrMuted)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.07), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 0.8))
            }
            .buttonStyle(.stelrPress)
            .accessibilityLabel("Profile settings")
        }
    }

    private var meSectionPicker: some View {
        HStack(spacing: 0) {
            ForEach(MeSkySection.allCases) { section in
                Button {
                    StelrHaptics.lightTap()
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        selectedSection = section
                    }
                } label: {
                    VStack(spacing: 5) {
                        Text(section.rawValue)
                            .font(StelrTypography.microLabel)
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
    private var meSelectedSectionContent: some View {
        switch selectedSection {
        case .tonight:
            MeTonightSection(
                myShows: appState.myShows,
                shows: appState.shows,
                onOpen: { show in detailShow = show },
                onCheckIn: { show in checkInShow = show }
            )
        case .watchlist:
            MeWatchlistSection(shows: watchlistShows) { show in
                detailShow = show
            }
        case .lists:
            MeListsSection(
                lists: appState.myLists,
                onEdit: { list in
                    editingList = list
                    showCreateList = true
                }
            )
        }
    }

    private var watchedEpisodeCount: Int {
        appState.myShows.reduce(0) { $0 + $1.currentEpisode }
    }

    private var watchlistShows: [Show] {
        appState.watchlistShows
    }

    private func meProfileStat(value: String, label: String) -> some View {
        VStack(alignment: .center, spacing: 1) {
            Text(value)
                .font(StelrTypography.statValue)
                .foregroundStyle(.primary)
            Text(label)
                .font(StelrTypography.statLabel)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 52)
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
            withTransaction(transaction) {
                contentAppeared = true
            }
        }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(StelrTypography.statValue)
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var softDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.12), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 0.7, height: 38)
    }
}


private struct MeTonightSection: View {
    let myShows: [MyShow]
    let shows: [Show]
    var onOpen: (Show) -> Void
    var onCheckIn: (Show) -> Void

    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(myShows) { myShow in
                if let show = shows.first(where: { $0.id == myShow.showId }) {
                    MeTonightRow(
                        myShow: myShow,
                        show: show,
                        watchingFriends: appState.friendsWatching(showId: show.id),
                        onOpen: { onOpen(show) },
                        onCheckIn: { onCheckIn(show) }
                    )
                    if myShow.id != myShows.last?.id {
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 0.6)
                    }
                }
            }
        }
    }
}

private struct MeTonightRow: View {
    let myShow: MyShow
    let show: Show
    let watchingFriends: [Friend]
    var onOpen: () -> Void
    var onCheckIn: () -> Void

    private var progress: CGFloat {
        min(1, max(0, CGFloat(myShow.currentEpisode) / CGFloat(max(1, myShow.totalEpisodes))))
    }

    private var ratingColor: Color {
        H7bStarVisualStyle.ratingColor(appScore: myShow.score)
    }

    private var scoreText: String {
        String(format: "%.1f", CheckInStep.from(myShow.score).score)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: onOpen) {
                ShowPosterView(show: show, width: 58, height: 86, radius: 10) {
                    VStack {
                        Spacer()
                        Text(show.platform)
                            .font(.system(size: 9.4, weight: .medium))
                            .foregroundColor(.white.opacity(0.72))
                            .padding(.bottom, 7)
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(
                                    colors: [.clear, .black.opacity(0.62)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 0.7)
                )
            }
            .buttonStyle(.stelrPress)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    Button(action: onOpen) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(show.title)
                                .font(StelrTypography.cardTitle)
                                .foregroundColor(.stelrText)
                                .lineLimit(1)

                            HStack(spacing: 6) {
                                Text("S\(myShow.currentSeason)")
                                Text("·")
                                Text("Ep \(myShow.currentEpisode) / \(myShow.totalEpisodes)")
                            }
                            .font(StelrTypography.metadataStrong)
                            .foregroundColor(.stelrMuted.opacity(0.84))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)

                    FriendStackView(friends: watchingFriends, avatarSize: 18)
                        .padding(.top, 1)
                        .fixedSize()
                }
                .padding(.bottom, 8)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.10))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.vibrantHex(show.gradient1, lift: 0.36, saturation: 1.18),
                                        Color.vibrantHex(show.gradient2, lift: 0.42, saturation: 1.18),
                                        Color(hex: show.accentColor)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 3.2)
                .clipShape(Capsule())
                .padding(.bottom, 9)

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text(myShow.vibe.emoji)
                            .font(.system(size: 10.8))
                        Text(myShow.vibe.label)
                            .font(StelrTypography.microLabel)
                            .foregroundColor(ratingColor)
                    }
                    .padding(.horizontal, 7)
                    .frame(height: 22)
                    .background(Color.white.opacity(0.10), in: Capsule(style: .continuous))

                    StarGlowView(score: myShow.score, maxCoreSize: 17, animate: true)
                        .frame(width: 24, height: 24)

                    Text(scoreText)
                        .font(StelrTypography.numericBadge)
                        .foregroundColor(ratingColor)
                        .monospacedDigit()
                }
                .padding(.bottom, 7)

                Button(action: onCheckIn) {
                    HStack(spacing: 7) {
                        StelrFourPointStar(variant: .twinkle)
                            .fill(.white)
                            .frame(width: 11, height: 11)
                        Text("Check in")
                            .font(StelrTypography.buttonSmall)
                        Spacer(minLength: 0)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(Color.stelrAccent, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .shadow(color: Color.stelrAccent.opacity(0.24), radius: 8, y: 4)
                }
                .buttonStyle(.stelrPress)
            }
        }
        .padding(.vertical, 0)
    }
}

private struct MeCrewSection: View {
    let friends: [Friend]
    let shows: [Show]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CREW · \(friends.count) WATCHING ALONGSIDE")
                .font(StelrTypography.microLabel)
                .tracking(2.4)
                .foregroundColor(.stelrMuted)

            VStack(spacing: 0) {
                ForEach(Array(friends.enumerated()), id: \.element.id) { index, friend in
                    HStack(spacing: 13) {
                        AvatarView(initials: friend.initials, hexColor: friend.hexColor, imageURL: friend.imageURL, size: 42)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(friend.name)
                                .font(StelrTypography.calloutStrong)
                                .foregroundColor(.stelrText)
                            Text("\(shows.first(where: { $0.id == friend.currentShowId })?.title ?? "Watching") · \(index == 0 ? "2h ago" : index == 1 ? "today" : "5h")")
                                .font(StelrTypography.metadata)
                                .foregroundColor(.stelrMuted.opacity(0.72))
                        }

                        Spacer()

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(max(3, 7 - index))")
                                .font(StelrTypography.sectionTitle)
                                .foregroundColor(.stelrAccent)
                            Text("shared")
                                .font(StelrTypography.metadataStrong)
                                .foregroundColor(.stelrMuted.opacity(0.72))
                        }
                    }
                    .padding(.vertical, 12)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.6)
                    }
                }
            }
        }
    }
}

private struct MeListsSection: View {
    let lists: [ShowList]
    var onEdit: (ShowList) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("LISTS · \(lists.count)")
                    .font(StelrTypography.microLabel)
                    .tracking(2.4)
                    .foregroundColor(.stelrMuted)
                Spacer()
            }

            if lists.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "list.star")
                        .font(.system(size: 30))
                        .foregroundColor(.stelrMuted.opacity(0.45))
                    Text("No lists yet")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.stelrMuted)
                    Text("Ranked lists will appear here.")
                        .font(.system(size: 13))
                        .foregroundColor(.stelrMuted.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 12) {
                    ForEach(lists) { list in
                        Button { onEdit(list) } label: {
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(list.title)
                                        .font(StelrTypography.calloutStrong)
                                        .foregroundColor(.stelrText)
                                        .lineLimit(1)
                                    Text("\(list.entries.count) show\(list.entries.count == 1 ? "" : "s")")
                                        .font(.system(size: 12))
                                        .foregroundColor(.stelrMuted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.stelrMuted.opacity(0.5))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                            .background(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.stelrBorder, lineWidth: 0.5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.stelrPress)
                    }
                }
            }
        }
    }
}

private struct MeWatchlistSection: View {
    let shows: [Show]
    var onOpen: (Show) -> Void

    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("QUEUED · \(shows.count)")
                .font(StelrTypography.microLabel)
                .tracking(2.4)
                .foregroundColor(.stelrMuted)

            VStack(spacing: 0) {
                ForEach(Array(shows.enumerated()), id: \.element.id) { index, show in
                    Button {
                        StelrHaptics.lightTap()
                        onOpen(show)
                    } label: {
                        WatchLaterRow(
                            show: show,
                            fallbackScore: 3.5 + Double(index % 3) * 0.5,
                            friendRating: appState.communityScore(for: show.id),
                            probeFriend: incomingProbeFriend(for: show.id),
                            isLast: index == shows.count - 1
                        )
                    }
                    .buttonStyle(.stelrPress)
                }
            }
        }
    }

    private func incomingProbeFriend(for showId: Int) -> Friend? {
        guard let probe = appState.probeRequests.first(where: { $0.isIncoming && $0.showId == showId }) else {
            return nil
        }
        return appState.friend(for: probe.fromFriendId)
    }
}

private struct WatchLaterRow: View {
    let show: Show
    let fallbackScore: Double
    let friendRating: Double?
    let probeFriend: Friend?
    let isLast: Bool

    private var displayScore: Double {
        friendRating ?? fallbackScore
    }

    private var scoreColor: Color {
        H7bStarVisualStyle.ratingColor(appScore: displayScore)
    }

    private var seasonsText: String {
        guard let seasons = show.seasons, seasons > 0 else { return "season info soon" }
        return "\(seasons) season\(seasons == 1 ? "" : "s")"
    }

    private var friendRatingValueText: String {
        guard let friendRating else { return "--" }
        return String(format: "%.1f", CheckInStep.from(friendRating).score)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.055))
                        .frame(width: 38, height: 38)
                    StarGlowView(score: displayScore, maxCoreSize: 17, animate: true)
                        .frame(width: 26, height: 26)
                }

                Text(friendRatingValueText)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundColor(friendRating == nil ? .stelrMuted.opacity(0.42) : scoreColor)
                    .monospacedDigit()
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .center, spacing: 7) {
                    Text(show.title)
                        .font(StelrTypography.calloutStrong)
                        .foregroundColor(.stelrText)
                        .lineLimit(1)
                        .layoutPriority(1)

                    if let probeFriend {
                        HStack(spacing: 5) {
                            AvatarView(
                                initials: probeFriend.initials,
                                hexColor: probeFriend.hexColor,
                                imageURL: probeFriend.imageURL,
                                size: 16
                            )
                            Text("Probed by \(probeFriend.name)")
                                .font(.system(size: 10.6, weight: .medium))
                                .foregroundColor(Color(hex: probeFriend.hexColor))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .frame(height: 22)
                        .background(Color(hex: probeFriend.hexColor).opacity(0.12), in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color(hex: probeFriend.hexColor).opacity(0.18), lineWidth: 0.6)
                        )
                        .fixedSize(horizontal: true, vertical: false)
                    }
                }

                HStack(spacing: 7) {
                    WatchLaterMetadataPill(systemName: "rectangle.stack", text: seasonsText)
                    WatchLaterMetadataPill(
                        systemName: "sparkle",
                        text: friendRating == nil ? "no friend score yet" : "friend rating",
                        tint: scoreColor,
                        tintOpacity: friendRating == nil ? 0.52 : 0.95
                    )
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.stelrMuted.opacity(0.55))
        }
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.6)
            }
        }
    }
}

private struct WatchLaterMetadataPill: View {
    let systemName: String
    let text: String
    var tint: Color = .stelrMuted
    var tintOpacity: Double = 0.72

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemName)
                .font(.system(size: 9.2, weight: .semibold))
            Text(text)
                .font(.system(size: 11.4, weight: .medium))
                .lineLimit(1)
        }
        .foregroundColor(tint.opacity(tintOpacity))
        .padding(.horizontal, 7)
        .frame(height: 23)
        .background(Color.white.opacity(0.06), in: Capsule())
    }
}

private struct ProfilePhotoAvatar: View {
    let imageData: Data
    let size: CGFloat
    var showsCameraBadge: Bool = false
    private var cameraSize: CGFloat { max(16, size * 0.27) }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            avatarContent
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 0.8))
                .shadow(color: Color(hex: "F4E6BE").opacity(imageData.isEmpty ? 0.38 : 0.18), radius: 14)

            if showsCameraBadge {
                Image(systemName: "camera.fill")
                    .font(.system(size: cameraSize * 0.54, weight: .semibold))
                    .foregroundStyle(Color(hex: "130B05"))
                    .frame(width: cameraSize, height: cameraSize)
                    .background(Color(hex: "F4E6BE"), in: Circle())
                    .offset(x: 2, y: 2)
            }
        }
        .frame(width: size + 4, height: size + 4)
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Circle()
                    .fill(Color(hex: "F4E6BE"))
                Text("A")
                    .font(.system(size: size * 0.40, weight: .medium))
                    .foregroundColor(Color(hex: "130B05"))
            }
        }
    }
}

private struct ProfileEditProfileSheet: View {
    @Binding var bio: String
    @Binding var imageData: Data
    @Environment(\.dismiss) private var dismiss
    @State private var draftBio: String
    @State private var selectedProfilePhoto: PhotosPickerItem?
    @State private var isLoadingPhoto = false

    private let characterLimit = 160

    init(bio: Binding<String>, imageData: Binding<Data>) {
        self._bio = bio
        self._imageData = imageData
        _draftBio = State(initialValue: bio.wrappedValue)
    }

    private var characterCount: Int {
        draftBio.count
    }

    private var remainingCharacters: Int {
        max(0, characterLimit - characterCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 18)

            HStack {
                Text("Edit profile")
                    .font(StelrTypography.pageTitle)
                    .foregroundColor(.stelrText)

                Spacer()

                Button("Done") {
                    bio = normalizedBio(draftBio)
                    dismiss()
                }
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.stelrAccent)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)

            VStack(spacing: 10) {
                PhotosPicker(selection: $selectedProfilePhoto, matching: .images) {
                    ZStack {
                        ProfilePhotoAvatar(imageData: imageData, size: 92, showsCameraBadge: true)

                        if isLoadingPhoto {
                            Circle()
                                .fill(Color.black.opacity(0.32))
                                .frame(width: 92, height: 92)
                            ProgressView()
                                .tint(.white)
                        }
                    }
                }
                .buttonStyle(.stelrPress)
                .accessibilityLabel("Change profile picture")

                Text("Change profile picture")
                    .font(StelrTypography.metadataStrong)
                    .foregroundColor(.stelrAccent)

                if !imageData.isEmpty {
                    Button {
                        StelrHaptics.lightTap()
                        imageData = Data()
                    } label: {
                        Text("Remove photo")
                            .font(StelrTypography.metadata)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)
            .onChange(of: selectedProfilePhoto) { _, newItem in
                guard let newItem else { return }
                isLoadingPhoto = true
                Task {
                    let data = try? await newItem.loadTransferable(type: Data.self)
                    await MainActor.run {
                        if let data {
                            imageData = Self.optimizedProfileImageData(from: data)
                        }
                        isLoadingPhoto = false
                    }
                }
            }

            Text("Bio")
                .font(StelrTypography.microLabel)
                .tracking(1.8)
                .foregroundStyle(.secondary.opacity(0.64))
                .textCase(.uppercase)
                .padding(.horizontal, 18)
                .padding(.bottom, 8)

            TextEditor(text: $draftBio)
                .font(.body)
                .foregroundStyle(.primary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 118)
                .padding(12)
                .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.7)
                )
                .padding(.horizontal, 18)
                .onChange(of: draftBio) { _, newValue in
                    let capped = cappedBio(newValue)
                    if capped != newValue {
                        draftBio = capped
                    }
                }

            HStack {
                Spacer()

                Text("\(remainingCharacters) characters left")
                    .font(.caption)
                    .foregroundStyle(remainingCharacters == 0 ? AnyShapeStyle(Color.stelrAccent) : AnyShapeStyle(.tertiary))
                    .monospacedDigit()
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)

            Button {
                draftBio = ""
            } label: {
                Text("Clear bio")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)
            .padding(.top, 18)

            Spacer(minLength: 0)
        }
        .background(Color(hex: "1c1814").ignoresSafeArea())
        .presentationDetents([.height(540)])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }

    private func cappedBio(_ value: String) -> String {
        guard value.count > characterLimit else { return value }
        return String(value.prefix(characterLimit))
    }

    private func normalizedBio(_ value: String) -> String {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return cappedBio(normalized)
    }

    private static func optimizedProfileImageData(from data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let targetSide: CGFloat = 512
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > targetSide else {
            return image.jpegData(compressionQuality: 0.82) ?? data
        }

        let scale = targetSide / longestSide
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.82) ?? data
    }
}

// ── Inline profile settings (accessed when authenticated) ─────────────────────

private struct ProfileSettingsSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showPasswordNotice = false

    var onSignIn: () -> Void
    var onEditProfile: () -> Void

    private let profileURL = URL(string: "https://stelr.app/@alexreeves")!
    private let inviteText = "Join me on Stelr: https://stelr.app/invite/alexreeves"

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 36, height: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Settings")
                            .font(StelrTypography.pageTitle)
                            .foregroundColor(.stelrText)

                        Text(accountSubtitle)
                            .font(StelrTypography.metadata)
                            .foregroundColor(.stelrMuted.opacity(0.72))
                            .lineLimit(1)
                    }

                    Spacer()

                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundColor(.stelrMuted)
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.07), in: Circle())
                    }
                    .buttonStyle(.stelrPress)
                    .accessibilityLabel("Close settings")
                }

                settingsSection("Account") {
                    if appState.isAuthenticated {
                        settingsButton(
                            icon: "rectangle.portrait.and.arrow.right",
                            title: "Log out",
                            subtitle: "Sign out of this device",
                            tint: .stelrMuted,
                            action: signOut
                        )
                    } else {
                        settingsButton(
                            icon: "person.crop.circle.badge.plus",
                            title: "Sign in",
                            subtitle: "Sync shows, lists, and profile data",
                            tint: .stelrAccent,
                            action: {
                                StelrHaptics.lightTap()
                                dismiss()
                                onSignIn()
                            }
                        )
                    }

                    settingsButton(
                        icon: "key",
                        title: "Change password",
                        subtitle: appState.isAuthenticated ? "Send yourself a reset link" : "Sign in first to update your password",
                        tint: Color(hex: "F0DDAF"),
                        action: {
                            StelrHaptics.lightTap()
                            showPasswordNotice = true
                        }
                    )
                }

                settingsSection("Profile") {
                    settingsButton(
                        icon: "person.crop.circle",
                        title: "Edit profile",
                        subtitle: "Update your bio and profile details",
                        tint: .stelrAccent,
                        action: {
                            StelrHaptics.lightTap()
                            dismiss()
                            onEditProfile()
                        }
                    )

                    ShareLink(item: profileURL) {
                        SettingsActionRow(
                            icon: "square.and.arrow.up",
                            title: "Share profile",
                            subtitle: "Send your Stelr profile link",
                            tint: Color(hex: "75B8FF")
                        )
                    }
                    .buttonStyle(.stelrPress)

                    ShareLink(item: inviteText) {
                        SettingsActionRow(
                            icon: "person.2.badge.plus",
                            title: "Invite friends",
                            subtitle: "Bring friends into your watch orbit",
                            tint: Color(hex: "8FD28A")
                        )
                    }
                    .buttonStyle(.stelrPress)
                }

                faqSection

                Spacer(minLength: 18)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 34)
        }
        .background(Color(hex: "1c1814").ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
        .alert("Change password", isPresented: $showPasswordNotice) {
            Button("OK", role: .cancel) { }
        } message: {
            if appState.isAuthenticated {
                Text("Password reset email support is not wired yet. This option is here for the signed-in account flow.")
            } else {
                Text("Sign in first, then come back here to change your password.")
            }
        }
    }

    private var accountSubtitle: String {
        if let email = appState.supabase.currentUser?.email {
            return email
        }
        return appState.isAuthenticated ? "Signed in" : "Not signed in"
    }

    private func signOut() {
        StelrHaptics.lightTap()
        Task {
            try? await appState.supabase.signOut()
            appState.isAuthenticated = false
            dismiss()
        }
    }

    private func settingsButton(
        icon: String,
        title: String,
        subtitle: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            SettingsActionRow(icon: icon, title: title, subtitle: subtitle, tint: tint)
        }
        .buttonStyle(.stelrPress)
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(StelrTypography.microLabel)
                .tracking(1.8)
                .foregroundColor(.stelrMuted.opacity(0.64))
                .textCase(.uppercase)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 0.7)
            )
        }
    }

    private var faqSection: some View {
        settingsSection("FAQ") {
            VStack(spacing: 0) {
                FAQRow(title: "What is a check in?", answer: "A check in logs where you are in a show and updates your current vibe.")
                SettingsDivider()
                FAQRow(title: "What is a vibe check?", answer: "A quick 1-5 rating that turns into the show’s star color and friend score.")
                SettingsDivider()
                FAQRow(title: "What is a probe?", answer: "A probe is a lightweight recommendation from a friend asking you to watch something.")
                SettingsDivider()
                FAQRow(title: "What is Watch Later?", answer: "Watch Later is your queue for shows you are interested in but have not started yet.")
                SettingsDivider()
                FAQRow(title: "How do rankings work?", answer: "Seasons ranks depth, Shows ranks distinct shows watched or watching, and Influence combines invites with shows friends actually pick up.")
                SettingsDivider()
                FAQRow(title: "What are milestones?", answer: "Milestones reward streaks, first vibe checks, co-watch moments, and other progress loops.")
            }
        }
    }
}

private struct SettingsActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(StelrTypography.calloutStrong)
                    .foregroundColor(.stelrText)
                    .lineLimit(1)

                Text(subtitle)
                    .font(StelrTypography.metadata)
                    .foregroundColor(.stelrMuted.opacity(0.68))
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundColor(.stelrMuted.opacity(0.45))
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 58)
        .contentShape(Rectangle())
    }
}

private struct FAQRow: View {
    let title: String
    let answer: String
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Text(answer)
                .font(StelrTypography.metadata)
                .foregroundColor(.stelrMuted.opacity(0.74))
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 42)
                .padding(.trailing, 12)
                .padding(.bottom, 12)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "questionmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: "F0DDAF"))
                    .frame(width: 30, height: 30)
                    .background(Color(hex: "F0DDAF").opacity(0.10), in: Circle())

                Text(title)
                    .font(StelrTypography.calloutStrong)
                    .foregroundColor(.stelrText)
                    .lineLimit(2)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 54)
            .contentShape(Rectangle())
        }
        .tint(.stelrMuted)
        .onChange(of: isExpanded) { _, _ in
            StelrHaptics.lightTap()
        }
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.055))
            .frame(height: 0.6)
            .padding(.leading, 54)
    }
}

// ── MustWatchAlertSheet forwarded from RotationView ───────────────────────────
// (defined in RotationView.swift — accessed here via type reference)

private struct MustWatchAlertSheet: View {
    let show: Show
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var sending = false
    @State private var sent = false

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color.white.opacity(0.18)).frame(width: 36, height: 4).padding(.top, 8).padding(.bottom, 18)
            ZStack {
                Circle().fill(Color(hex: show.accentColor).opacity(0.14))
                    .overlay(Circle().stroke(Color(hex: show.accentColor).opacity(0.35), lineWidth: 1))
                    .frame(width: 48, height: 48)
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(Color(hex: show.accentColor))
            }
            .padding(.bottom, 12)
            Text("Tell everyone?")
                .font(.body).foregroundColor(.stelrText).padding(.bottom, 8)
            Text("This will send an alert to all your friends that \(show.title) is a must watch.")
                .font(StelrTypography.callout).foregroundColor(.stelrMuted).multilineTextAlignment(.center)
                .lineSpacing(3).padding(.horizontal, 28).padding(.bottom, 18)
            Button {
                sending = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation { sending = false; sent = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { dismiss() }
                }
            } label: {
                HStack(spacing: 8) {
                    if sent { Text("✓ sent!") }
                    else if sending { ProgressView().tint(.white); Text("sending…") }
                    else { Image(systemName: "paperplane.fill"); Text("send it!") }
                }
                .font(StelrTypography.button).foregroundColor(.white)
                .frame(maxWidth: .infinity).frame(height: 46)
                .background(sent ? Color(hex: "72c97e") : Color.stelrAccent)
                .clipShape(RoundedRectangle(cornerRadius: 15))
            }
            .disabled(sending || sent).padding(.horizontal, 18)
            Button { dismiss() } label: {
                Text("not now").font(.system(size: 14.6, weight: .medium)).foregroundColor(.stelrMuted)
                    .padding(.top, 13).padding(.bottom, 18)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(hex: "1c1814").ignoresSafeArea())
        .safeAreaPadding(.bottom)
        .presentationDetents([.height(330)])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }
}

// ── YouShowRow — compact show row for You tab ─────────────────────────────────
// Mirrors MyShowRow from RotationView but with slightly tighter spacing.

private struct YouShowRow: View {
    let myShow: MyShow
	let show: Show
	let watchingFriends: [Friend]
	var onOpenActions: () -> Void
	var onCheckIn: () -> Void

	private var vOpt: VibeOption { myShow.vibe }
	private var ratingColor: Color { H7bStarVisualStyle.ratingColor(appScore: myShow.score) }
	private var progress: Double { Double(myShow.currentEpisode) / Double(max(1, myShow.totalEpisodes)) }
	private var hasScore: Bool { myShow.score >= 1 && myShow.score <= 5 }
	private var scoreText: String { String(format: "%.1f", CheckInStep.from(myShow.score).score) }

	var body: some View {
	    HStack(alignment: .top, spacing: 14) {
	        Button {
	            StelrHaptics.lightTap()
	            onOpenActions()
	        } label: {
	            ShowPosterView(show: show, width: 86, height: 120, radius: 13) {
	                VStack {
	                    Spacer()
                        LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
                            .frame(height: 40)
                            .overlay(
                                Text(show.platform)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.bottom, 7), alignment: .bottom
	                        )
	                }
	            }
	        }
	        .buttonStyle(.stelrPress)

	        VStack(alignment: .leading, spacing: 0) {
	            HStack(alignment: .firstTextBaseline, spacing: 8) {
	                Text(show.title)
	                    .font(StelrTypography.sectionTitle)
	                    .foregroundStyle(.primary)
	                    .lineLimit(1)

	                if myShow.currentEpisode >= myShow.totalEpisodes {
	                    Image(systemName: "checkmark.circle.fill")
	                        .font(.system(size: 12.2, weight: .medium))
	                        .foregroundColor(Color(hex: "72c97e"))
	                }
	            }
	            .contentShape(Rectangle())
	            .onTapGesture {
	                StelrHaptics.lightTap()
	                onOpenActions()
	            }
	            .padding(.bottom, 7)

	            HStack(spacing: 7) {
	                Text("S\(myShow.currentSeason)")
	                Text("·")
	                Text("Ep \(myShow.currentEpisode)")
	                if myShow.totalEpisodes > 1 {
	                    Text("/ \(myShow.totalEpisodes)")
	                }
	            }
	            .font(.subheadline)
	            .foregroundStyle(.secondary)
	            .padding(.bottom, 10)

	            GeometryReader { geo in
	                ZStack(alignment: .leading) {
	                    RoundedRectangle(cornerRadius: 2)
	                        .fill(Color.white.opacity(0.08))
	                        .frame(height: 4)
	                    RoundedRectangle(cornerRadius: 2)
	                        .fill(
	                            LinearGradient(
	                                colors: [
	                                    Color.vibrantHex(show.gradient1, lift: 0.36, saturation: 1.2),
	                                    Color.vibrantHex(show.gradient2, lift: 0.4, saturation: 1.22)
	                                ],
	                                startPoint: .leading,
	                                endPoint: .trailing
	                            )
	                        )
	                        .frame(width: geo.size.width * progress, height: 4)
	                        .animation(.spring(response: 0.45, dampingFraction: 0.62), value: progress)
	                }
	            }
	            .frame(height: 4)
	            .padding(.bottom, 9)

	            HStack(alignment: .center, spacing: 8) {
	                Text("\(vOpt.emoji) \(vOpt.label)")
	                    .font(.subheadline)
	                    .fontWeight(.regular)
	                    .foregroundColor(ratingColor)
	                    .padding(.horizontal, 8)
	                    .padding(.vertical, 3)
	                    .background(ratingColor.opacity(0.12))
	                    .clipShape(Capsule())
	                VibeWaveView(vibe: vOpt, score: myShow.score, size: 30, animate: true)
	                if hasScore {
	                    Text(scoreText)
	                        .font(.subheadline)
	                        .fontWeight(.regular)
	                        .foregroundColor(ratingColor)
	                        .monospacedDigit()
	                }
	            }
	            .padding(.bottom, 8)

	            if !watchingFriends.isEmpty {
	                FriendStackView(friends: watchingFriends, avatarSize: 22)
	            }

	            Button {
	                StelrHaptics.mediumTap()
	                onCheckIn()
	            } label: {
	                HStack(spacing: 7) {
	                    StelrFourPointStar(variant: .twinkle)
	                        .fill(.white)
	                        .frame(width: 13, height: 13)
	                    Text("Check in")
	                        .font(StelrTypography.buttonSmall)
	                    Spacer(minLength: 0)
	                }
	                .foregroundColor(.white)
	                .padding(.horizontal, 11)
	                .frame(height: 36)
	                .background(Color.stelrAccent)
	                .clipShape(RoundedRectangle(cornerRadius: 13))
	                .shadow(color: Color.stelrAccent.opacity(0.24), radius: 10, y: 5)
	            }
	            .buttonStyle(.stelrPress)
	            .padding(.top, watchingFriends.isEmpty ? 8 : 10)
	        }
	    }
	    .padding(.vertical, 22)
	}
}
