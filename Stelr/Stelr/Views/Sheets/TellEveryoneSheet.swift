import SwiftUI

// MARK: - SputnikProbeIcon
// Minimal Sputnik-style probe mark. Inherits foreground color for the body/legs
// while keeping the port dark, matching the filled Apple-native reference.

struct SputnikProbeIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let s  = min(size.width, size.height)
            let ox = (size.width  - s) / 2
            let oy = (size.height - s) / 2
            let k  = s / 64.0
            let lw = max(1.0, s * 0.052)
            let style = StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round)

            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: ox + x * k, y: oy + y * k)
            }

            let bodyRect = CGRect(
                x: ox + 30.0 * k,
                y: oy + 5.0 * k,
                width: 29.0 * k,
                height: 29.0 * k
            )

            // Three trailing antenna legs.
            for (start, end) in [
                (p(31.2, 18.2), p(6.0, 42.0)),
                (p(39.8, 32.2), p(19.5, 57.5)),
                (p(55.4, 32.0), p(47.6, 61.0))
            ] {
                var leg = Path()
                leg.move(to: start)
                leg.addLine(to: end)
                ctx.stroke(leg, with: .foreground, style: style)
            }

            // Small filled mounts where the legs meet the body.
            for (x, y, rotation) in [
                (28.8 as CGFloat, 17.2, -42.0),
                (37.6 as CGFloat, 30.6, -48.0),
                (54.2 as CGFloat, 30.2, -82.0)
            ] {
                var mount = Path(roundedRect: CGRect(
                    x: ox + x * k,
                    y: oy + y * k,
                    width: 4.0 * k,
                    height: 5.8 * k
                ), cornerRadius: 1.1 * k)
                mount = mount.applying(.init(translationX: -(ox + (x + 2.0) * k), y: -(oy + (y + 2.9) * k)))
                mount = mount.applying(.init(rotationAngle: rotation * .pi / 180))
                mount = mount.applying(.init(translationX: ox + (x + 2.0) * k, y: oy + (y + 2.9) * k))
                ctx.fill(mount, with: .foreground)
            }

            // Filled probe body.
            let body = Path(ellipseIn: bodyRect)
            ctx.fill(body, with: .foreground)

            // Small dark circular port.
            let port = Path(ellipseIn: CGRect(
                x: ox + 47.0 * k,
                y: oy + 11.5 * k,
                width: 6.8 * k,
                height: 6.8 * k
            ))
            ctx.fill(port, with: .color(Color(hex: "0A0B10")))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - SendProbeSheet

struct TellEveryoneSheet: View {
    let show: Show
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    var body: some View {
        SendProbeSheet(show: show)
    }
}

struct SendProbeSheet: View {
    let show: Show

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    @State private var selectedFriendIds: Set<Int> = []
    @State private var message = ""
    @State private var phase: ProbePhase = .composing
    @FocusState private var messageFocused: Bool

    private enum ProbePhase: Equatable {
        case composing, launching, sent
    }

    private var canLaunch: Bool { !selectedFriendIds.isEmpty }

    private var selectedFriends: [Friend] {
        appState.friends.filter { selectedFriendIds.contains($0.id) }
    }

    var body: some View {
        ZStack {
            StelrStarFieldBackground()
                .ignoresSafeArea()

            // Subtle show-tinted bloom at top
            RadialGradient(
                colors: [Color(hex: show.accentColor).opacity(0.07), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 340
            )
            .ignoresSafeArea()

            if phase == .sent {
                sentConfirmation
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                composerBody
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.40, dampingFraction: 0.84), value: phase)
        .presentationDetents([.height(composerHeight)])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }

    // MARK: - Composer height

    private var composerHeight: CGFloat {
        let base: CGFloat = 552
        return base + (message.isEmpty ? 0 : 40)
    }

    // MARK: - Composer body

    private var composerBody: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(width: 36, height: 4)
                .padding(.top, 16)
                .padding(.bottom, 20)

            // Header
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(hex: show.accentColor).opacity(0.12))
                    Circle()
                        .stroke(Color(hex: show.accentColor).opacity(0.22), lineWidth: 1)
                    SputnikProbeIcon()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(Color(hex: show.accentColor))
                }
                .frame(width: 44, height: 44)
                .shadow(color: Color(hex: show.accentColor).opacity(0.18), radius: 12)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Send a Probe")
                        .font(StelrTypography.pageTitle)
                        .foregroundStyle(.primary)
                    Text(show.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)

            Text("A probe sends this show to friends as a recommendation so it pops up in their feed and inbox.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.top, 12)

            // Friend selection
            VStack(alignment: .leading, spacing: 10) {
                Text("TARGET")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .tracking(1.2)
                    .padding(.horizontal, 22)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(appState.friends) { friend in
                            FriendProbeChip(
                                friend: friend,
                                isSelected: selectedFriendIds.contains(friend.id),
                                accentHex: show.accentColor
                            ) {
                                withAnimation(.spring(response: 0.26, dampingFraction: 0.74)) {
                                    if selectedFriendIds.contains(friend.id) {
                                        selectedFriendIds.remove(friend.id)
                                    } else {
                                        selectedFriendIds.insert(friend.id)
                                    }
                                }
                                StelrHaptics.selection()
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 3)
                }
            }
            .padding(.top, 22)

            // Message input
            VStack(alignment: .leading, spacing: 10) {
                Text("MESSAGE  (OPTIONAL)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .tracking(1.2)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $message)
                        .focused($messageFocused)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 60, maxHeight: 100)

                    if message.isEmpty {
                        Text("\"You absolutely have to watch this…\"")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.7)
                )
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)

            // Preview strip
            if !selectedFriendIds.isEmpty {
                probePreviewStrip
                    .padding(.horizontal, 22)
                    .padding(.top, 14)
                    .transition(.opacity.combined(with: .offset(y: 6)))
            }

            Spacer(minLength: 0)

            // Launch button
            Button {
                guard canLaunch, phase == .composing else { return }
                launch()
            } label: {
                HStack(spacing: 9) {
                    if phase == .launching {
                        ProgressView()
                            .tint(Color(hex: "0a0a14"))
                            .scaleEffect(0.85)
                    } else {
                        SputnikProbeIcon()
                            .frame(width: 16, height: 16)
                        Text(canLaunch ? "Launch Probe" : "Select someone first")
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(canLaunch ? Color(hex: "0a0a14") : .stelrMuted)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    canLaunch
                        ? Color(hex: show.accentColor)
                        : Color.white.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .shadow(
                    color: canLaunch ? Color(hex: show.accentColor).opacity(0.28) : .clear,
                    radius: 16, y: 8
                )
            }
            .disabled(!canLaunch || phase == .launching)
            .buttonStyle(.stelrPress)
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 18)
            .animation(.easeInOut(duration: 0.18), value: canLaunch)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Preview strip

    private var probePreviewStrip: some View {
        HStack(spacing: 8) {
            SputnikProbeIcon()
                .frame(width: 11, height: 11)
                .foregroundStyle(Color(hex: show.accentColor).opacity(0.70))

            Text("Probe")
                .font(.caption)
                .foregroundStyle(.tertiary)

            ForEach(selectedFriends) { friend in
                HStack(spacing: 5) {
                    AvatarView(initials: friend.initials, hexColor: friend.hexColor, imageURL: friend.imageURL, size: 18)
                    Text(friend.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !message.isEmpty {
                Text("·")
                    .font(.caption)
                    .foregroundStyle(.quaternary)
                Text("\"\(message.prefix(28))\(message.count > 28 ? "…" : "")\"")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.065), lineWidth: 0.6)
        )
    }

    // MARK: - Sent confirmation

    private var sentConfirmation: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                // Probe glow animation
                ZStack {
                    ForEach(0..<3, id: \.self) { ring in
                        Circle()
                            .stroke(Color(hex: show.accentColor).opacity(0.12 - Double(ring) * 0.035), lineWidth: 1)
                            .frame(
                                width: CGFloat(54 + ring * 28),
                                height: CGFloat(54 + ring * 28)
                            )
                    }
                    ZStack {
                        Circle()
                            .fill(Color(hex: show.accentColor).opacity(0.18))
                        SputnikProbeIcon()
                            .frame(width: 21, height: 21)
                            .foregroundStyle(Color(hex: show.accentColor))
                    }
                    .frame(width: 48, height: 48)
                    .shadow(color: Color(hex: show.accentColor).opacity(0.36), radius: 20)
                }

                VStack(spacing: 6) {
                    Text("Probe launched")
                        .font(StelrTypography.sectionTitle)
                        .foregroundStyle(.primary)

                    Text(targetSentLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Friend avatars
                HStack(spacing: -8) {
                    ForEach(selectedFriends) { friend in
                        AvatarView(initials: friend.initials, hexColor: friend.hexColor, imageURL: friend.imageURL, size: 34)
                            .overlay(Circle().stroke(Color(hex: "0a0a14"), lineWidth: 2))
                    }
                }
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .background(Color(hex: "030810").opacity(0.40), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.7)
            )
            .shadow(color: Color(hex: show.accentColor).opacity(0.10), radius: 30, y: 12)
            .padding(.horizontal, 36)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var targetSentLine: String {
        let names = selectedFriends.map(\.name)
        switch names.count {
        case 0: return "Probe sent"
        case 1: return "Heading toward \(names[0])"
        case 2: return "Heading toward \(names[0]) & \(names[1])"
        default:
            let allButLast = names.dropLast().joined(separator: ", ")
            return "Heading toward \(allButLast) & \(names.last!)"
        }
    }

    // MARK: - Actions

    private func launch() {
        StelrHaptics.mediumTap()
        phase = .launching

        let msg = message.trimmingCharacters(in: .whitespacesAndNewlines)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            appState.sendProbe(
                showId: show.id,
                toFriendIds: Array(selectedFriendIds),
                message: msg.isEmpty ? nil : msg
            )
            StelrHaptics.success()
            withAnimation(.spring(response: 0.44, dampingFraction: 0.80)) {
                phase = .sent
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                dismiss()
            }
        }
    }
}

// MARK: - FriendProbeChip

private struct FriendProbeChip: View {
    let friend: Friend
    let isSelected: Bool
    let accentHex: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 7) {
                ZStack {
                    AvatarView(initials: friend.initials, hexColor: friend.hexColor, imageURL: friend.imageURL, size: 40)

                    if isSelected {
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            .frame(width: 44, height: 44)

                        // Check badge
                        ZStack {
                            Circle()
                                .fill(Color(hex: accentHex))
                            Image(systemName: "checkmark")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(Color(hex: "0a0a14"))
                        }
                        .frame(width: 14, height: 14)
                        .offset(x: 14, y: -14)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .shadow(
                    color: isSelected ? Color(hex: accentHex).opacity(0.30) : .black.opacity(0.18),
                    radius: isSelected ? 10 : 6, y: 3
                )

                Text(friend.name)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? Color(hex: accentHex) : Color.secondary)
                    .lineLimit(1)
            }
            .frame(width: 54)
        }
        .buttonStyle(.plain)
    }
}
