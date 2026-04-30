import SwiftUI

struct AvatarView: View {
    let initials: String
    let hexColor: String
    var size: CGFloat = 36
    var showBorder: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: hexColor).opacity(0.16))
                .overlay(
                    Circle().stroke(
                        showBorder ? Color(hex: hexColor) : Color(hex: hexColor).opacity(0.33),
                        lineWidth: showBorder ? 2 : 1.5
                    )
                )
            Text(initials)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundColor(Color(hex: hexColor))
        }
        .frame(width: size, height: size)
    }
}
