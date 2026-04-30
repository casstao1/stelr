import SwiftUI

struct BottomTabBar: View {
    @Binding var selectedTab: Int
    var onSelect: ((Int) -> Void)? = nil
    @Namespace private var bubbleNamespace

    private let items: [(label: String, icon: String)] = [
        ("Stelr",    "sparkles"),
        ("Friends",  "person.2.fill"),
        ("Rotation", "square.grid.2x2.fill"),
        ("Profile",  "person.fill"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                let isSelected = idx == selectedTab

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.72, blendDuration: 0)) {
                        if let onSelect {
                            onSelect(idx)
                        } else {
                            selectedTab = idx
                        }
                    }
                } label: {
                    HStack(spacing: isSelected ? 5 : 0) {
                        Image(systemName: item.icon)
                            .font(.system(size: 17, weight: isSelected ? .semibold : .medium))
                            .frame(width: 20)

                        if isSelected {
                            Text(item.label)
                                .font(.system(size: 12.5, weight: .semibold))
                                .lineLimit(1)
                                .fixedSize()
                                .transition(
                                    .asymmetric(
                                        insertion: .opacity.combined(with: .scale(scale: 0.8, anchor: .leading)),
                                        removal:   .opacity.combined(with: .scale(scale: 0.8, anchor: .leading))
                                    )
                                )
                        }
                    }
                    .foregroundColor(isSelected ? .white : Color.stelrMuted.opacity(0.55))
                    .padding(.horizontal, isSelected ? 15 : 10)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if isSelected {
                                Capsule()
                                    .fill(Color.stelrAccent)
                                    .matchedGeometryEffect(id: "bubble", in: bubbleNamespace)
                            }
                        }
                    )
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.stelrPress)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.stelrCard)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.5), radius: 24, x: 0, y: 10)
        )
        .padding(.horizontal, 22)
        .padding(.bottom, 28)
    }
}
