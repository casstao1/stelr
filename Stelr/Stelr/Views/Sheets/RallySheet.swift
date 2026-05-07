import SwiftUI

struct RallySheet: View {
    let show: Show
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var sending = false
    @State private var sent = false

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color.white.opacity(0.18)).frame(width: 36, height: 4).padding(.top, 8)

            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: show.gradient1).opacity(0.8))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: show.accentColor).opacity(0.27), lineWidth: 1))
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: show.accentColor))
                }
                .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rally your circle").font(StelrTypography.sectionTitle).italic().foregroundColor(.stelrText)
                    Text("Ping everyone to watch \(show.title) right now")
                        .font(.system(size: 13.4)).foregroundColor(.stelrMuted)
                }
            }
            .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 6)

            // Friends
            VStack(alignment: .leading, spacing: 12) {
                Text("NOTIFYING")
                    .font(.system(size: 11.8)).foregroundColor(.stelrMuted).kerning(0.8)
                HStack(spacing: 0) {
                    ForEach(appState.friends) { friend in
                        VStack(spacing: 5) {
                            ZStack {
                                AvatarView(initials: friend.initials, hexColor: friend.hexColor, imageURL: friend.imageURL, size: 36)
                                if sent {
                                    Circle().stroke(Color.white.opacity(0.18), lineWidth: 1)
                                        .frame(width: 40, height: 40).transition(.scale)
                                }
                            }
                            Text(friend.name).font(.system(size: 11.9)).foregroundColor(.stelrMuted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.stelrBorder, lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 18).padding(.top, 16)

            Spacer()

            Button {
                sending = true
                if appState.isAuthenticated {
                    Task { try? await appState.supabase.sendRally(showId: show.id) }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    StelrHaptics.success()
                    withAnimation { sent = true; sending = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
                }
            } label: {
                HStack(spacing: 8) {
                    if sent {
                        Text("✓  Rally sent!")
                    } else if sending {
                        ProgressView().tint(.white)
                        Text("Sending…")
                    } else {
                        Image(systemName: "dot.radiowaves.left.and.right")
                        Text("Watch together now")
                    }
                }
                .font(.system(size: 16.8, weight: .semibold)).foregroundColor(.white)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(sent ? Color(hex: "72c97e") : sending ? Color.stelrAccent.opacity(0.8) : Color.stelrAccent)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(sent)
            .padding(.horizontal, 18).padding(.bottom, 40)
        }
        .background(Color(hex: "1c1814"))
        .presentationDetents([.height(380)])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }
}
