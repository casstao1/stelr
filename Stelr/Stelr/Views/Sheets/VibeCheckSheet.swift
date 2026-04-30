import SwiftUI

struct VibeCheckSheet: View {
    let show: Show
    let currentVibe: VibeOption?           // replaces currentScore — nil if never checked in
    var onSubmit: (VibeOption) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selected: VibeOption?
    @State private var done = false

    private let orderedOptions: [VibeOption] = [
        .mustWatch, .goingGood, .justOk, .superBoring
    ]

    private var mascotMood: MascotMood {
        switch selected {
        case .mustWatch:   return .excited
        case .goingGood:   return .happy
        case .justOk:      return .meh
        case .superBoring: return .sad
        default:           return .idle
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule().fill(Color.white.opacity(0.18)).frame(width: 36, height: 4).padding(.top, 8)

            // Header
            HStack(spacing: 12) {
                MascotView(mood: mascotMood, size: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text("How's it holding up?")
                        .font(.custom("Georgia", size: 17.9)).italic()
                        .foregroundColor(.stelrText)
                    HStack(spacing: 6) {
                        Text(show.title)
                            .font(.system(size: 13.4)).foregroundColor(.stelrMuted)
                        if let v = currentVibe {
                            Text("·")
                                .font(.system(size: 13.4)).foregroundColor(.stelrMuted.opacity(0.45))
                            Text("\(v.emoji) \(v.label)")
                                .font(.system(size: 13.4))
                                .foregroundColor(Color(hex: v.hexColor))
                        }
                    }
                }
            }
            .padding(.horizontal, 8).padding(.top, 18).padding(.bottom, 20)

            Spacer(minLength: 0)

            // Options
            VStack(spacing: 9) {
                ForEach(orderedOptions) { opt in
                    let active = selected == opt
                    let activeColor = Color(hex: opt.hexColor)
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.25)) { selected = opt }
                    } label: {
                        HStack(spacing: 12) {
                            // Mini orb as selector indicator
                            ZStack {
                                if active {
                                    Circle()
                                        .fill(RadialGradient(
                                            colors: [activeColor.opacity(0.55), .clear],
                                            center: .center, startRadius: 0, endRadius: 14
                                        ))
                                        .frame(width: 28, height: 28)
                                }
                                Circle()
                                    .fill(opt.isCold ? activeColor.opacity(0.5) : activeColor)
                                    .frame(width: active ? 13 : 10, height: active ? 13 : 10)
                            }
                            .frame(width: 28)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(opt.label)
                                    .font(.system(size: 15.2, weight: .medium))
                                    .foregroundColor(active ? activeColor : .stelrText)
                                Text(opt.heatName)
                                    .font(.system(size: 11.5))
                                    .foregroundColor(active ? activeColor.opacity(0.7) : .stelrMuted.opacity(0.55))
                            }
                            Spacer()
                            Text(opt.emoji)
                                .font(.system(size: 22.0))
                            if active {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 17.0, weight: .semibold))
                                    .foregroundColor(activeColor)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 52)
                        .padding(.horizontal, 14)
                        .background(active ? activeColor.opacity(0.10) : Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(
                            active ? activeColor.opacity(0.50) : Color.stelrBorder, lineWidth: 1.5
                        ))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .scaleEffect(active ? 1.025 : 1.0)
                    }
                    .buttonStyle(.stelrPress)
                }
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 12)

            // Submit
            Button {
                guard let sel = selected else { return }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                done = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                        onSubmit(sel)
                    }
                    dismiss()
                }
            } label: {
                Text(done ? "✓  Vibe logged!" : "Log vibe")
                    .font(.system(size: 16.8, weight: .semibold))
                    .foregroundColor(selected != nil ? .white : .stelrMuted)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(done ? Color(hex: "72c97e") : selected != nil ? Color.stelrAccent : Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(selected == nil)
            .padding(.horizontal, 8).padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 10)
        .background(Color(hex: "1c1814").ignoresSafeArea())
        .presentationDetents([.height(460)])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }
}
