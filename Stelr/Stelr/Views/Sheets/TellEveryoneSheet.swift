import SwiftUI

struct TellEveryoneSheet: View {
    let show: Show
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var message = ""
    @State private var sending = false
    @State private var sent = false

    var body: some View {
        ZStack {
            Color(hex: "1c1814").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Capsule().fill(Color.white.opacity(0.18)).frame(width: 36, height: 4).padding(.top, 8)

                    // ── Header ────────────────────────────────────────────────
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: show.gradient1).opacity(0.8))
                                .overlay(RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: show.accentColor).opacity(0.27), lineWidth: 1))
                            Image(systemName: "megaphone.fill")
                                .font(.system(size: 24.6))
                                .foregroundColor(Color(hex: show.accentColor))
                        }
                        .frame(width: 42, height: 42)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tell everyone")
                                .font(.custom("Georgia", size: 19.0)).italic().foregroundColor(.stelrText)
                            Group {
                                Text("Recommend ") + Text(show.title).foregroundColor(.stelrText) + Text(" to your circle")
                            }
                            .font(.system(size: 13.4)).foregroundColor(.stelrMuted)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 16)

                    // ── Message input ─────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ADD A MESSAGE (OPTIONAL)")
                            .font(.system(size: 11.8)).foregroundColor(.stelrMuted).kerning(0.8)
                        HStack(alignment: .top, spacing: 8) {
                            Text("💬").font(.system(size: 20.0))
                            TextField("\"You need to watch this…\"", text: $message, axis: .vertical)
                                .font(.system(size: 14.6)).foregroundColor(.stelrText)
                                .lineLimit(2...4)
                                .tint(.stelrAccent)
                        }
                        .padding(13)
                        .background(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.stelrBorder, lineWidth: 0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 18)

                    // ── Recipients ────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SENDING TO")
                            .font(.system(size: 11.8)).foregroundColor(.stelrMuted).kerning(0.8)
                        HStack(spacing: 0) {
                            ForEach(appState.friends) { friend in
                                VStack(spacing: 5) {
                                    ZStack {
                                        AvatarView(initials: friend.initials, hexColor: friend.hexColor, size: 36)
                                        if sent {
                                            Circle().stroke(Color(hex: "72c97e"), lineWidth: 1.5)
                                                .frame(width: 40, height: 40)
                                                .transition(.scale.combined(with: .opacity))
                                        }
                                    }
                                    .animation(.spring(response: 0.3), value: sent)
                                    Text(friend.name).font(.system(size: 11.9)).foregroundColor(.stelrMuted)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.03))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.stelrBorder, lineWidth: 0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 18).padding(.top, 14)

                    // ── Message preview (appears when text entered) ────────────
                    if !message.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("PREVIEW")
                                    .font(.system(size: 11.8)).foregroundColor(.stelrMuted).kerning(0.8)
                                Group {
                                    Text("You").foregroundColor(.stelrAccent)
                                    + Text(" recommends ")
                                    + Text(show.title).italic()
                                    + Text(" · \"\(message)\"").foregroundColor(.stelrMuted)
                                }
                                .font(.system(size: 14.0)).foregroundColor(.stelrText).lineSpacing(3)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.03))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.stelrBorder, lineWidth: 0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 18).padding(.top, 12)
                        .transition(.opacity.combined(with: .offset(y: 6)))
                        .animation(.spring(response: 0.3), value: message.isEmpty)
                    }

                    // ── Send button ────────────────────────────────────────────
                    Button {
                        sending = true
                        if appState.isAuthenticated {
                            let friendIds = appState.friends.map { $0.hexColor }
                            Task { try? await appState.supabase.sendRecommendation(showId: show.id, toUserIds: friendIds, message: message) }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                            withAnimation { sent = true; sending = false }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if sent {
                                Text("✓  Recommendation sent!")
                            } else if sending {
                                ProgressView().tint(.white)
                                Text("Sending…")
                            } else {
                                Image(systemName: "megaphone").font(.system(size: 15.7, weight: .semibold))
                                Text("Tell everyone")
                            }
                        }
                        .font(.system(size: 16.8, weight: .semibold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(sent ? Color(hex: "72c97e") : sending ? Color.stelrAccent.opacity(0.8) : Color.stelrAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .animation(.easeInOut(duration: 0.25), value: sent)
                    }
                    .disabled(sent)
                    .padding(.horizontal, 18).padding(.top, 16)

                    Text("Each friend will receive a push notification with your recommendation.")
                        .font(.system(size: 12.3)).foregroundColor(.stelrMuted).multilineTextAlignment(.center)
                        .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 12)
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }
}
