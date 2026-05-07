import SwiftUI
import UIKit

struct AvatarView: View {
    let initials: String
    let hexColor: String
    var imageURL: String? = nil
    var size: CGFloat = 36
    var showBorder: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: hexColor).opacity(0.16))

            if let imageURL {
                StableRemoteAvatarImage(urlString: imageURL, size: size) {
                    initialsFallback
                }
            } else {
                initialsFallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle().stroke(
                Color.white.opacity(showBorder ? 0.12 : 0.07),
                lineWidth: showBorder ? 0.8 : 0.6
            )
        )
    }

    private var initialsFallback: some View {
        Text(initials)
            .font(.system(size: size * 0.36, weight: .semibold))
            .foregroundColor(Color(hex: hexColor))
    }
}

private struct StableRemoteAvatarImage<Fallback: View>: View {
    let urlString: String
    let size: CGFloat
    @ViewBuilder var fallback: () -> Fallback

    @State private var image: UIImage?
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                fallback()
                    .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .task(id: urlString) {
            loadTask?.cancel()
            guard let url = URL(string: urlString) else { return }
            if let cached = AvatarImageCache.shared.image(for: url) {
                setImageWithoutAnimating(cached)
                return
            }

            let task = Task {
                guard let (data, _) = try? await URLSession.shared.data(from: url),
                      !Task.isCancelled,
                      let decoded = UIImage(data: data) else { return }
                AvatarImageCache.shared.insert(decoded, for: url)
                await MainActor.run {
                    setImageWithoutAnimating(decoded)
                }
            }
            loadTask = task
            await task.value
        }
        .onDisappear {
            loadTask?.cancel()
        }
    }

    @MainActor
    private func setImageWithoutAnimating(_ newImage: UIImage) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            image = newImage
        }
    }
}

private final class AvatarImageCache {
    static let shared = AvatarImageCache()

    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 160
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func insert(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}
