import SwiftUI

// Compact per-show rating star. Uses the same H7b ringed visual as constellation nodes.
struct VibeWaveView: View {
    let vibe: VibeOption
    /// Optional explicit score (1.0–5.0). Falls back to the vibe's representative score.
    var score: Double? = nil
    /// Approximate visual size of the star system. Defaults to 20.
    var size: CGFloat = 20
    /// When false, suppresses motion but keeps the ringed visual state.
    var animate: Bool = true

    private var effectiveScore: Double {
        score ?? vibe.representativeScore
    }

    var body: some View {
        StarGlowView(
            score: effectiveScore,
            maxCoreSize: size,
            animate: animate
        )
    }
}
