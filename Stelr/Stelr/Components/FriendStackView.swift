import SwiftUI

struct FriendStackView: View {
    let friends: [Friend]
    var maxVisible: Int = 3
    var avatarSize: CGFloat = 22
    var showLabel: Bool = false
    var label: String? = nil

    @State private var showingFriends = false
    @State private var profileFriend: Friend?

    private var visibleFriends: [Friend] {
        Array(friends.prefix(maxVisible))
    }

    private var overflowCount: Int {
        max(0, friends.count - visibleFriends.count)
    }

    private var bubbleCount: Int {
        visibleFriends.count + (overflowCount > 0 ? 1 : 0)
    }

    private var overlapOffset: CGFloat {
        avatarSize * 0.62
    }

    private var stackWidth: CGFloat {
        guard bubbleCount > 0 else { return 0 }
        let overflowWidth = overflowCount > 0 ? avatarSize * 0.86 : 0
        let visibleWidth = visibleFriends.isEmpty
            ? 0
            : avatarSize + CGFloat(max(0, visibleFriends.count - 1)) * overlapOffset
        return visibleWidth + overflowWidth
    }

    private var resolvedLabel: String {
        if let label { return label }
        if friends.count == 1 {
            return "\(friends[0].name) watching"
        }
        return "friends watching"
    }

    var body: some View {
        Group {
            if !friends.isEmpty {
                HStack(spacing: 8) {
                    avatarStack

                    if showLabel {
                        Text(resolvedLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
                .popover(isPresented: $showingFriends, attachmentAnchor: .point(.center), arrowEdge: .bottom) {
                    FriendStackPopover(friends: friends) { friend in
                        showingFriends = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            profileFriend = friend
                        }
                    }
                    .presentationCompactAdaptation(.popover)
                }
                .sheet(item: $profileFriend) { friend in
                    FriendProfileSheet(friend: friend)
                }
                .accessibilityLabel("\(friends.count) friends watching")
            }
        }
    }

    private var avatarStack: some View {
        ZStack(alignment: .leading) {
            ForEach(Array(visibleFriends.enumerated()), id: \.element.id) { index, friend in
                Button {
                    StelrHaptics.lightTap()
                    profileFriend = friend
                } label: {
                    AvatarView(initials: friend.initials, hexColor: friend.hexColor, imageURL: friend.imageURL, size: avatarSize, showBorder: true)
                        .background(Circle().fill(Color.stelrBg))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .offset(x: CGFloat(index) * overlapOffset)
                .zIndex(Double(visibleFriends.count - index))
            }

            if overflowCount > 0 {
                Button {
                    StelrHaptics.lightTap()
                    showingFriends = true
                } label: {
                    Text("+\(overflowCount)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .minimumScaleFactor(0.78)
                        .frame(width: avatarSize * 0.82, height: avatarSize, alignment: .leading)
                }
                .buttonStyle(.plain)
                .offset(x: avatarSize + CGFloat(max(0, visibleFriends.count - 1)) * overlapOffset + 3)
                .zIndex(0)
            }
        }
        .frame(width: stackWidth, height: avatarSize, alignment: .leading)
    }
}

private struct FriendStackPopover: View {
    let friends: [Friend]
    var onFriendTap: (Friend) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Watching")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.0)
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                ForEach(friends) { friend in
                    Button {
                        StelrHaptics.lightTap()
                        onFriendTap(friend)
                    } label: {
                        HStack(spacing: 10) {
                            AvatarView(initials: friend.initials, hexColor: friend.hexColor, imageURL: friend.imageURL, size: 28, showBorder: true)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(friend.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                Text("@\(friend.username) · \(friend.vibe.label)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 8)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 230)
        .background(Color(hex: "11121E").opacity(0.94))
        .background(.ultraThinMaterial)
        .preferredColorScheme(.dark)
    }
}
