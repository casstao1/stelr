import SwiftUI
import UIKit

enum StelrHaptics {
    static func lightTap() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    static func softTap() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred()
    }

    static func mediumTap() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    static func firmTap() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred()
    }

    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
}

enum StelrTypography {
    static let pageTitle: Font = .system(size: 19, weight: .semibold, design: .default)
    static let sectionTitle: Font = .system(size: 16.5, weight: .semibold, design: .default)
    static let cardTitle: Font = .system(size: 15.5, weight: .bold, design: .default)
    static let body: Font = .system(size: 14.5, weight: .regular, design: .default)
    static let bodyStrong: Font = .system(size: 14.5, weight: .semibold, design: .default)
    static let callout: Font = .system(size: 13.5, weight: .regular, design: .default)
    static let calloutStrong: Font = .system(size: 13.5, weight: .semibold, design: .default)
    static let metadata: Font = .system(size: 12, weight: .regular, design: .default)
    static let metadataStrong: Font = .system(size: 11.5, weight: .medium, design: .default)
    static let microLabel: Font = .system(size: 10, weight: .semibold, design: .default)
    static let tabLabel: Font = .system(size: 11.5, weight: .medium, design: .default)
    static let statValue: Font = .system(size: 18, weight: .semibold, design: .default)
    static let statLabel: Font = .system(size: 12.5, weight: .regular, design: .default)
    static let button: Font = .system(size: 13.5, weight: .semibold, design: .default)
    static let buttonSmall: Font = .system(size: 11.5, weight: .semibold, design: .default)
    static let numericBadge: Font = .system(size: 11, weight: .semibold, design: .default)
    static let episodeMeta: Font = .system(size: 9.5, weight: .medium, design: .default)
}

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
    static let stelrBg      = Color(hex: "03040B")
    static let stelrSurface = Color(hex: "080A14")
    static let stelrSurface2 = Color(hex: "10121C").opacity(0.48)
    static let stelrCard    = Color(hex: "10121C").opacity(0.48)
    static let stelrBorder  = Color.white.opacity(0.08)
    static let stelrText    = Color.white.opacity(0.90)
    static let stelrMuted   = Color.white.opacity(0.50)
    static let stelrDim     = Color.white.opacity(0.24)
    static let stelrAccent  = Color(hex: "E5604A")
    static let stelrAccentSoft = Color(hex: "E5604A").opacity(0.60)
    static let stelrSilver  = Color(hex: "EBEEFF").opacity(0.55)
    static let stelrHotGlow = Color(hex: "FFFCD7").opacity(0.35)
    static let stelrCoolGlow = Color(hex: "BECDFF").opacity(0.16)
    static let stelrDormant = Color(hex: "AAB2DC").opacity(0.10)
}

enum StelrStarVariant {
    case classic, sharp, twinkle
}

struct StelrFourPointStar: Shape {
    var variant: StelrStarVariant = .twinkle

    func path(in rect: CGRect) -> Path {
        let points = normalizedPoints.map {
            CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height)
        }

        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)

        switch variant {
        case .twinkle:
            path.addCurve(to: points[1], control1: CGPoint(x: rect.midX + rect.width * 0.01, y: rect.minY + rect.height * 0.24), control2: CGPoint(x: rect.midX + rect.width * 0.06, y: rect.minY + rect.height * 0.34))
            path.addCurve(to: points[2], control1: CGPoint(x: rect.midX + rect.width * 0.16, y: rect.midY - rect.height * 0.055), control2: CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.midY - rect.height * 0.015))
            path.addCurve(to: points[3], control1: CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.midY + rect.height * 0.015), control2: CGPoint(x: rect.midX + rect.width * 0.16, y: rect.midY + rect.height * 0.055))
            path.addCurve(to: points[4], control1: CGPoint(x: rect.midX + rect.width * 0.06, y: rect.maxY - rect.height * 0.34), control2: CGPoint(x: rect.midX + rect.width * 0.01, y: rect.maxY - rect.height * 0.24))
            path.addCurve(to: points[5], control1: CGPoint(x: rect.midX - rect.width * 0.01, y: rect.maxY - rect.height * 0.24), control2: CGPoint(x: rect.midX - rect.width * 0.06, y: rect.maxY - rect.height * 0.34))
            path.addCurve(to: points[6], control1: CGPoint(x: rect.midX - rect.width * 0.16, y: rect.midY + rect.height * 0.055), control2: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.midY + rect.height * 0.015))
            path.addCurve(to: points[7], control1: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.midY - rect.height * 0.015), control2: CGPoint(x: rect.midX - rect.width * 0.16, y: rect.midY - rect.height * 0.055))
            path.addCurve(to: first, control1: CGPoint(x: rect.midX - rect.width * 0.06, y: rect.minY + rect.height * 0.34), control2: CGPoint(x: rect.midX - rect.width * 0.01, y: rect.minY + rect.height * 0.24))
            path.closeSubpath()
        case .classic, .sharp:
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()
        }

        return path
    }

    private var normalizedPoints: [CGPoint] {
        switch variant {
        case .classic:
            return [
                CGPoint(x: 0.5, y: 1.0 / 24.0),
                CGPoint(x: 14.0 / 24.0, y: 10.0 / 24.0),
                CGPoint(x: 23.0 / 24.0, y: 0.5),
                CGPoint(x: 14.0 / 24.0, y: 14.0 / 24.0),
                CGPoint(x: 0.5, y: 23.0 / 24.0),
                CGPoint(x: 10.0 / 24.0, y: 14.0 / 24.0),
                CGPoint(x: 1.0 / 24.0, y: 0.5),
                CGPoint(x: 10.0 / 24.0, y: 10.0 / 24.0),
            ]
        case .sharp:
            return [
                CGPoint(x: 0.5, y: 0.5 / 24.0),
                CGPoint(x: 13.2 / 24.0, y: 10.8 / 24.0),
                CGPoint(x: 23.5 / 24.0, y: 0.5),
                CGPoint(x: 13.2 / 24.0, y: 13.2 / 24.0),
                CGPoint(x: 0.5, y: 23.5 / 24.0),
                CGPoint(x: 10.8 / 24.0, y: 13.2 / 24.0),
                CGPoint(x: 0.5 / 24.0, y: 0.5),
                CGPoint(x: 10.8 / 24.0, y: 10.8 / 24.0),
            ]
        case .twinkle:
            return [
                CGPoint(x: 0.50, y: 0.02),
                CGPoint(x: 0.60, y: 0.39),
                CGPoint(x: 0.96, y: 0.50),
                CGPoint(x: 0.60, y: 0.61),
                CGPoint(x: 0.50, y: 0.98),
                CGPoint(x: 0.40, y: 0.61),
                CGPoint(x: 0.04, y: 0.50),
                CGPoint(x: 0.40, y: 0.39),
            ]
        }
    }
}

struct StelrStarFieldBackground: View {
    var includesRadialBloom = true
    var starCount = 82

    var body: some View {
        ZStack {
            Color.stelrBg
            if includesRadialBloom {
                RadialGradient(
                    colors: [
                        Color(hex: "10131F").opacity(0.62),
                        Color.stelrBg.opacity(0.72),
                        Color.black.opacity(0.98)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 520
                )
            }
            Canvas { ctx, size in
                drawStars(ctx: ctx, size: size)
            }
        }
    }

    private func drawStars(ctx: GraphicsContext, size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        for index in 0..<starCount {
            let x = CGFloat(Double(index) * 137.5).truncatingRemainder(dividingBy: size.width)
            let y = CGFloat(Double(index) * 97.3 + 20).truncatingRemainder(dividingBy: size.height)
            let outerRadius: CGFloat = index % 11 == 0 ? 1.45 : index % 5 == 0 ? 1.05 : 0.64
            let innerRadius = outerRadius * 0.42
            let opacity = 0.055 + Double(index % 6) * 0.026
            let rotation = CGFloat(index % 9) * .pi / 13
            ctx.fill(
                fivePointStarPath(
                    center: CGPoint(x: x, y: y),
                    outerRadius: outerRadius,
                    innerRadius: innerRadius,
                    rotation: rotation
                ),
                with: .color(.white.opacity(opacity))
            )

            if index % 13 == 0 {
                ctx.stroke(
                    fivePointStarPath(
                        center: CGPoint(x: x, y: y),
                        outerRadius: outerRadius + 0.35,
                        innerRadius: innerRadius + 0.12,
                        rotation: rotation
                    ),
                    with: .color(.white.opacity(0.035)),
                    lineWidth: 0.28
                )
            }
        }
    }

    private func fivePointStarPath(
        center: CGPoint,
        outerRadius: CGFloat,
        innerRadius: CGFloat,
        rotation: CGFloat
    ) -> Path {
        var path = Path()
        for pointIndex in 0..<10 {
            let radius = pointIndex.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = -.pi / 2 + rotation + CGFloat(pointIndex) * .pi / 5
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if pointIndex == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

struct StelrPressButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.978
    var pressedOpacity: Double = 0.90

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
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
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .brightness(configuration.isPressed ? 0.04 : 0)
            .shadow(
                color: Color.white.opacity(configuration.isPressed ? 0.10 : 0.03),
                radius: configuration.isPressed ? 8 : 4,
                y: configuration.isPressed ? 0 : 2
            )
            .overlay {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(configuration.isPressed ? 0.22 : 0.10),
                                Color.white.opacity(configuration.isPressed ? 0.06 : 0.025),
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
                    .stroke(Color.white.opacity(configuration.isPressed ? 0.20 : 0.07), lineWidth: 0.8)
                    .allowsHitTesting(false)
            }
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == StelrGlossyPressButtonStyle {
    static var stelrGlossyPress: StelrGlossyPressButtonStyle {
        StelrGlossyPressButtonStyle()
    }
}
