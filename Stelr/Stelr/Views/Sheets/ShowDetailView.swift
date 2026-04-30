import SwiftUI

struct ShowDetailView: View {
    let show: Show
    let watchingFriends: [Friend]
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showTellEveryone = false

    private var isInRotation: Bool {
        appState.myShows.contains(where: { $0.showId == show.id })
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.stelrBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // ── Hero ─────────────────────────────────────────────────
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(colors: [Color(hex: show.gradient1), Color(hex: show.gradient2)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                            .frame(height: 220)

                        // Fade to bg
                        LinearGradient(colors: [.clear, .stelrBg.opacity(0.95)],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: 220)

                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                ShowPosterView(show: show, width: 88, height: 122, radius: 14)
                                    .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.white.opacity(0.14), lineWidth: 0.7)
                                    )
                                    .padding(.trailing, 18)
                                    .padding(.bottom, 18)
                            }
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Rectangle()
                                .fill(Color(hex: show.accentColor))
                                .frame(width: 20, height: 2).cornerRadius(1)
                            Text(show.title)
                                .font(.custom("Georgia", size: 24.6))
                                .foregroundColor(.white)
                            HStack(spacing: 6) {
                                if let genre = show.genre {
                                    Text(genre).font(.system(size: 13.8)).foregroundColor(.white.opacity(0.55))
                                    Text("·").foregroundColor(.white.opacity(0.25))
                                }
                                if let year = show.year {
                                    Text("\(year)").font(.system(size: 13.8)).foregroundColor(.white.opacity(0.55))
                                }
                                if let s = show.seasons, let e = show.totalEpisodes {
                                    Text("·").foregroundColor(.white.opacity(0.25))
                                    Text("\(s)S · \(e) eps").font(.system(size: 13.8)).foregroundColor(.white.opacity(0.55))
                                }
                                Spacer()
                                if isInRotation {
                                    Button { showTellEveryone = true } label: {
                                        Image(systemName: "megaphone")
                                            .font(.system(size: 13.2, weight: .medium))
                                            .frame(width: 32, height: 32)
                                        .foregroundColor(.white.opacity(0.86))
                                        .background(Color.black.opacity(0.24))
                                        .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 0.7))
                                        .clipShape(Circle())
                                    }
                                } else {
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            appState.addShowToRotation(show)
                                        }
                                    } label: {
                                        Image(systemName: "plus")
                                            .font(.system(size: 14.0, weight: .semibold))
                                            .frame(width: 32, height: 32)
                                        .foregroundColor(.white)
                                        .background(Color.stelrAccent)
                                        .clipShape(Circle())
                                    }
                                }
                            }
                        }
                        .padding(.leading, 18).padding(.trailing, 116).padding(.bottom, 16)
                    }

                    // ── Content ───────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 20) {
                        // Platforms
                        if let platforms = show.platforms, !platforms.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(platforms, id: \.self) { p in
                                        PlatformBadge(name: p)
                                    }
                                }
                            }
                        }

                        // Summary
                        if let summary = show.summary {
                            Text(summary)
                                .font(.system(size: 14.6)).foregroundColor(.stelrMuted)
                                .lineSpacing(4)
                        }

                        // Cast
                        if !castMembers.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionLabel("Cast")
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(Array(castMembers.enumerated()), id: \.offset) { idx, member in
                                            CastBubble(member: member)
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }

                        // Friends watching
                        if !watchingFriends.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionLabel("Your circle")
                                ForEach(watchingFriends) { friend in
                                    HStack(spacing: 10) {
                                        AvatarView(initials: friend.initials, hexColor: friend.hexColor, size: 32)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(friend.name)
                                                .font(.system(size: 14.0, weight: .medium)).foregroundColor(.stelrText)
                                            Text("\(friend.vibe.emoji) \(friend.vibe.label)")
                                                .font(.system(size: 12.3)).foregroundColor(Color(hex: friend.vibe.hexColor))
                                        }
                                        Spacer()
                                        VibeWaveView(vibe: friend.vibe, size: 16, animate: false)
                                    }
                                    .padding(12)
                                    .background(Color.white.opacity(0.04))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.stelrBorder, lineWidth: 0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18).padding(.top, 4).padding(.bottom, 40)
                }
            }

            // Close button
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15.7, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .padding(.top, 26).padding(.trailing, 16)
            }
        }
        .sheet(isPresented: $showTellEveryone) {
            TellEveryoneSheet(show: show)
        }
        .preferredColorScheme(.dark)
    }

    private var castMembers: [CastMember] {
        if let castMembers = show.castMembers, !castMembers.isEmpty {
            return castMembers
        }
        return (show.cast ?? []).map {
            CastMember(name: $0, characterName: nil, imageURL: nil)
        }
    }
}

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11.8)).foregroundColor(.stelrMuted).kerning(0.8)
    }
}
private struct PlatformBadge: View {
    let name: String
    private var style: (bg: Color, fg: Color) {
        switch name {
        case "Apple TV+":  return (.black, .white)
        case "Netflix":    return (Color(hex: "E50914"), .white)
        case "HBO", "Max": return (Color(hex: "8B4FB8"), .white)
        case "Hulu":       return (Color(hex: "1CE783"), .black)
        default:           return (Color(hex: "333333"), .white)
        }
    }
    var body: some View {
        Text(name).font(.system(size: 13.8, weight: .semibold))
            .foregroundColor(style.fg)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(style.bg).clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
private struct CastBubble: View {
    let member: CastMember
    var body: some View {
        VStack(spacing: 5) {
            castImage
                .frame(width: 48, height: 48)
                .clipShape(Circle())
            Text(member.name.split(separator: " ").first.map(String.init) ?? member.name)
                .font(.system(size: 10.1)).foregroundColor(.stelrMuted)
                .multilineTextAlignment(.center).frame(width: 56)
        }
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
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.42))
        }
    }
}
