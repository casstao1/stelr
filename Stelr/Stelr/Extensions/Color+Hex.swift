import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }

    static func lighterHex(_ hex: String, amount: Double) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 3:
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6, 8:
            (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        let clamped = min(max(amount, 0), 1)
        return Color(
            .sRGB,
            red: Double(r) / 255 + (1 - Double(r) / 255) * clamped,
            green: Double(g) / 255 + (1 - Double(g) / 255) * clamped,
            blue: Double(b) / 255 + (1 - Double(b) / 255) * clamped,
            opacity: 1
        )
    }

    static func vibrantHex(_ hex: String, lift: Double = 0.18, saturation: Double = 1.55) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 3:
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6, 8:
            (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }

        let sourceRed = Double(r) / 255
        let sourceGreen = Double(g) / 255
        let sourceBlue = Double(b) / 255
        let sourceMax = max(sourceRed, sourceGreen, sourceBlue)
        guard sourceMax > 0.001 else {
            return Color(.sRGB, red: 0.72, green: 0.72, blue: 0.72, opacity: 1)
        }

        let targetBrightness = min(1, max(0.72, sourceMax + lift))
        let red = sourceRed / sourceMax * targetBrightness
        let green = sourceGreen / sourceMax * targetBrightness
        let blue = sourceBlue / sourceMax * targetBrightness
        let average = (red + green + blue) / 3

        return Color(
            .sRGB,
            red: min(max(average + (red - average) * saturation, 0), 1),
            green: min(max(average + (green - average) * saturation, 0), 1),
            blue: min(max(average + (blue - average) * saturation, 0), 1),
            opacity: 1
        )
    }
}

// App-wide design tokens
extension Color {
    static let stelrBg      = Color(hex: "0D0B09")
    static let stelrSurface = Color(hex: "1A1612")
    static let stelrCard    = Color(hex: "221E18")
    static let stelrBorder  = Color.white.opacity(0.08)
    static let stelrText    = Color(hex: "EDE5D8")
    static let stelrMuted   = Color(hex: "8A8070")
    static let stelrAccent  = Color(hex: "E5604A")
}

struct StelrPressButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.965
    var pressedOpacity: Double = 0.82

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .animation(.snappy(duration: 0.16, extraBounce: 0), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == StelrPressButtonStyle {
    static var stelrPress: StelrPressButtonStyle {
        StelrPressButtonStyle()
    }
}

struct StelrGlossyPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .brightness(configuration.isPressed ? 0.08 : 0)
            .shadow(
                color: Color.white.opacity(configuration.isPressed ? 0.16 : 0.04),
                radius: configuration.isPressed ? 10 : 4,
                y: configuration.isPressed ? 0 : 2
            )
            .overlay {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(configuration.isPressed ? 0.34 : 0.12),
                                Color.white.opacity(configuration.isPressed ? 0.08 : 0.03),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .allowsHitTesting(false)
            }
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(configuration.isPressed ? 0.34 : 0.08), lineWidth: 0.8)
                    .allowsHitTesting(false)
            }
            .animation(.spring(response: 0.22, dampingFraction: 0.68), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == StelrGlossyPressButtonStyle {
    static var stelrGlossyPress: StelrGlossyPressButtonStyle {
        StelrGlossyPressButtonStyle()
    }
}
