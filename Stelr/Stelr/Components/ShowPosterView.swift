import SwiftUI

struct ShowPosterView<Content: View>: View {
    let show: Show
    var width: CGFloat
    var height: CGFloat
    var radius: CGFloat = 14
    var loadsRemoteImage: Bool = true
    @ViewBuilder var overlay: () -> Content

    init(
        show: Show,
        width: CGFloat,
        height: CGFloat,
        radius: CGFloat = 14,
        loadsRemoteImage: Bool = true,
        @ViewBuilder overlay: @escaping () -> Content
    ) {
        self.show = show
        self.width = width
        self.height = height
        self.radius = radius
        self.loadsRemoteImage = loadsRemoteImage
        self.overlay = overlay
    }

    var body: some View {
        ZStack {
            // ── Background: real poster if available, else gradient ───────────
            if loadsRemoteImage, let primaryImageURL {
                remotePoster(primary: primaryImageURL, fallback: fallbackImageURL)
            } else {
                gradientBg
            }

            // ── Grid texture (only visible on gradient fallback) ─────────────
            if !loadsRemoteImage || primaryImageURL == nil {
                Canvas { ctx, size in
                    let step: CGFloat = 12
                    var x: CGFloat = 0
                    while x <= size.width {
                        var y: CGFloat = 0
                        while y <= size.height {
                            var p = Path()
                            p.move(to: CGPoint(x: x, y: y))
                            p.addLine(to: CGPoint(x: x - step, y: y))
                            p.addLine(to: CGPoint(x: x - step, y: y + step))
                            ctx.stroke(p, with: .color(.white.opacity(0.07)), lineWidth: 0.4)
                            y += step
                        }
                        x += step
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: radius))
            }

            // ── Dark scrim so overlay text stays readable on real posters ─────
            if loadsRemoteImage && primaryImageURL != nil {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.35)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }

            overlay()
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: radius))
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private var primaryImageURL: URL? {
        (show.imageURL ?? show.previewImageURL).flatMap(URL.init(string:))
    }

    private var fallbackImageURL: URL? {
        guard let previewImageURL = show.previewImageURL,
              previewImageURL != show.imageURL else { return nil }
        return URL(string: previewImageURL)
    }

    private var gradientBg: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(LinearGradient(
                colors: [Color(hex: show.gradient1), Color(hex: show.gradient2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: width, height: height)
    }

    private func remotePoster(primary: URL, fallback: URL?) -> some View {
        AsyncImage(url: primary) { phase in
            switch phase {
            case .success(let image):
                fittedPoster(image)
            case .failure:
                if let fallback {
                    AsyncImage(url: fallback) { fallbackPhase in
                        switch fallbackPhase {
                        case .success(let image):
                            fittedPoster(image)
                        case .failure:
                            gradientBg
                        default:
                            gradientBg
                                .overlay(shimmer)
                        }
                    }
                } else {
                    gradientBg
                }
            default:
                // Placeholder while loading: show gradient + shimmer
                gradientBg
                    .overlay(shimmer)
            }
        }
    }

    private func fittedPoster(_ image: Image) -> some View {
        ZStack {
            // Gradient base — always fills frame with show's palette
            LinearGradient(
                colors: [
                    Color(hex: show.gradient1),
                    Color(hex: show.gradient2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if isPortraitFrame {
                // Portrait frame: show full poster with colored fill on any thin side bars
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .blur(radius: 10)
                    .opacity(0.30)
                    .clipped()

                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: width, height: height)
            } else {
                // Landscape frame: fill to crop — shows the center of the poster (key art)
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
            }
        }
        .frame(width: width, height: height)
        .clipped()
    }

    // True when the frame is taller than wide (portrait or square-ish)
    private var isPortraitFrame: Bool {
        height >= width * 0.85
    }

    private var shimmer: some View {
        ShimmerView()
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .opacity(0.4)
    }
}

// ── Shimmer placeholder ────────────────────────────────────────────────────────
private struct ShimmerView: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white.opacity(0.15), location: 0.45),
                    .init(color: .white.opacity(0.3),  location: 0.5),
                    .init(color: .white.opacity(0.15), location: 0.55),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .init(x: phase, y: 0.5),
                endPoint:   .init(x: phase + 1, y: 0.5)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
        }
    }
}

// ── Convenience init without overlay ──────────────────────────────────────────
extension ShowPosterView where Content == EmptyView {
    init(show: Show, width: CGFloat, height: CGFloat, radius: CGFloat = 14, loadsRemoteImage: Bool = true) {
        self.init(show: show, width: width, height: height, radius: radius, loadsRemoteImage: loadsRemoteImage) { EmptyView() }
    }
}
