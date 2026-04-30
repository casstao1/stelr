import SwiftUI

struct VibeCheckSheet: View {
    let show: Show
    let currentScore: Double
    var onSubmit: (VibeOption) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selected: VibeOption?
    @State private var done = false

    private let orderedOptions: [VibeOption] = [
        .mustWatch,
        .goingGood,
        .justOk,
        .superBoring
    ]

    private func optionTitle(_ option: VibeOption) -> String {
        switch option {
        case .mustWatch:   return "must watch"
        case .goingGood:   return "going to watch more"
        case .justOk:      return "meh"
        case .superBoring: return "kinda boring"
        case .notWatching: return "not watching"
        }
    }

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
                    Text("\(show.title) · vibe score \(String(format: "%.1f", currentScore))")
                        .font(.system(size: 13.4)).foregroundColor(.stelrMuted)
                }
            }
            .padding(.horizontal, 8).padding(.top, 18).padding(.bottom, 20)

            Spacer(minLength: 0)

            // Options
            VStack(spacing: 9) {
                ForEach(orderedOptions) { opt in
                    let active = selected == opt
                    let activeColor = Color(hex: opt.hexColor)
                    let readableActiveColor = opt.isDark ? Color.white.opacity(0.72) : activeColor
                    let selectedBackground = opt.isDark ? Color.black.opacity(0.42) : activeColor.opacity(0.12)
                    let selectedBorder = opt.isDark ? Color.white.opacity(0.28) : activeColor.opacity(0.55)
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.25)) { selected = opt }
                    } label: {
                        HStack(spacing: 12) {
                            Text(opt.emoji)
                                .font(.system(size: 24.0))
                                .frame(width: 34)
                            Text(optionTitle(opt))
                                .font(.system(size: 15.2, weight: .medium))
                                .foregroundColor(active ? readableActiveColor : .stelrText)
                            Spacer()
                            if active {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 17.0, weight: .semibold))
                                    .foregroundColor(readableActiveColor)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 52)
                        .padding(.horizontal, 14)
                        .background(active ? selectedBackground : Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(active ? selectedBorder : Color.stelrBorder, lineWidth: 1.5))
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
        .presentationDetents([.height(440)])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }
}
