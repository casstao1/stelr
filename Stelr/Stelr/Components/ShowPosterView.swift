import SwiftUI

struct ShowPosterView<Content: View>: View {
    let show: Show
    var width: CGFloat
    var height: CGFloat
    var radius: CGFloat = 14
    @ViewBuilder var overlay: () -> Content

    init(show: Show, width: CGFloat, height: CGFloat, radius: CGFloat = 14, @ViewBuilder overlay: @escaping () -> Content) {
        self.show = show; self.width = width; self.height = height; self.radius = radius; self.overlay = overlay
    }

    var body: some View {
        ZStack {
            // ── Background: real poster if available, else gradient ───────────
            if let urlStr = show.imageURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        fittedPoster(image)
                    case .failure:
                        gradientBg
                    default:
                        // Placeholder while loading: show gradient + shimmer
                        gradientBg
                            .overlay(shimmer)
                    }
                }
            } else {
                gradientBg
            }

            // ── Grid texture (only visible on gradient fallback) ─────────────
            if show.imageURL == nil {
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

            // ── Accent top bar ────────────────────────────────────────────────
            VStack {
                HStack {
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [Color(hex: show.accentColor).opacity(0.8), .clear],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: width * 0.6, height: 2)
                    Spacer()
                }
                Spacer()
            }

            // ── Dark scrim so overlay text stays readable on real posters ─────
            if show.imageURL != nil {
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

    private var gradientBg: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(LinearGradient(
                colors: [Color(hex: show.gradient1), Color(hex: show.gradient2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: width, height: height)
    }

    private func fittedPoster(_ image: Image) -> some View {
        ZStack {
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .scaleEffect(1.08)
                .blur(radius: 12)
                .opacity(0.38)
                .clipped()

            LinearGradient(
                colors: [
                    Color(hex: show.gradient1).opacity(0.38),
                    Color(hex: show.gradient2).opacity(0.78)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: width, height: height)
                .shadow(color: .black.opacity(0.28), radius: 8, y: 3)
        }
        .frame(width: width, height: height)
        .clipped()
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
    init(show: Show, width: CGFloat, height: CGFloat, radius: CGFloat = 14) {
        self.init(show: show, width: width, height: height, radius: radius) { EmptyView() }
    }
}
