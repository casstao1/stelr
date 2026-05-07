import SwiftUI

struct VibeCheckSheet: View {
    let show: Show
    let currentMyShow: MyShow?
    var onSubmit: (_ season: Int?, _ episode: Int?, _ score: Double) -> Void
    var onSeasonRating: ((_ season: Int, _ score: Double) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var season: Int
    @State private var episode: Int
    @State private var selectedScore: Double?
    @State private var previewScore: Double
    @State private var confirming = false
    @State private var tipPulse = false

    // Season rating flow
    @State private var showingSeasonRating = false
    @State private var seasonRatingPicked: Double? = 3.0
    @State private var seasonRatingConfirmed = false
    @State private var seasonPreviewScore: Double = 3.0

    init(show: Show, currentMyShow: MyShow?,
         onSubmit: @escaping (_ season: Int?, _ episode: Int?, _ score: Double) -> Void,
         onSeasonRating: ((_ season: Int, _ score: Double) -> Void)? = nil) {
        self.show = show
        self.currentMyShow = currentMyShow
        self.onSubmit = onSubmit
        self.onSeasonRating = onSeasonRating

        let existingScore = currentMyShow?.score
        let hasScore = existingScore.map { $0 >= 1 && $0 <= 5 } ?? false
        let score = hasScore ? CheckInStep.from(existingScore ?? 1).score : 1.0
        _selectedScore = State(initialValue: hasScore ? score : nil)
        _previewScore = State(initialValue: score)
        _season = State(initialValue: max(1, currentMyShow?.currentSeason ?? 1))
        _episode = State(initialValue: max(1, currentMyShow?.currentEpisode ?? 1))
    }

    private var supportsEpisode: Bool {
        show.totalEpisodes != nil ||
        show.seasons != nil ||
        currentMyShow.map { $0.totalEpisodes > 1 } == true ||
        !show.currentEpisode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var step: CheckInStep {
        CheckInStep.from(selectedScore ?? previewScore)
    }

    private var ratingColor: Color {
        H7bStarVisualStyle.ratingColor(appScore: step.score)
    }

    private var episodeCap: Int? {
        show.episodeCount(forSeason: season, fallback: currentMyShow?.totalEpisodes)
    }

    private var justFinishedSeason: Bool {
        guard let cap = episodeCap else { return false }
        return episode >= cap
    }

    private var totalSeasons: Int? {
        show.seasons
    }

    private var canAutoAdvanceSeason: Bool {
        totalSeasons.map { season < $0 } ?? true
    }

    private var episodePlusDisabled: Bool {
        guard let episodeCap else { return false }
        return episode >= episodeCap && !canAutoAdvanceSeason
    }

    private var submitTextColor: Color {
        guard selectedScore != nil else { return .stelrMuted }
        return Color(hex: "0a0a14")
    }

    var body: some View {
        ZStack {
            StelrStarFieldBackground()
                .ignoresSafeArea()

            if showingSeasonRating {
                seasonRatingContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
                VStack(spacing: 0) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 36, height: 4)
                        .padding(.top, 16)
                        .padding(.bottom, 12)

                    header

                    if supportsEpisode {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("which episode did you last watch?")
                                .font(.system(size: 13.8, weight: .semibold))
                                .foregroundColor(.stelrText.opacity(0.86))
                                .padding(.horizontal, 18)

                            episodeStepper
                        }
                        .padding(.top, 14)
                    }

                    VStack(spacing: 12) {
                        VibeWaveView(vibe: step.vibe, score: step.score, size: 64, animate: selectedScore != nil)
                            .frame(height: 140)
                            .padding(.top, 8)

                        VStack(spacing: 3) {
                            Text(selectedScore == nil ? "unrated" : step.vibe.label)
                                .font(StelrTypography.sectionTitle)
                                .foregroundColor(selectedScore == nil ? .stelrMuted : ratingColor)
                                .contentTransition(.numericText())
                                .animation(.easeInOut(duration: 0.3), value: step.score)
                            if selectedScore == nil {
                                Text("drag or tap to rate")
                                    .font(.system(size: 13.4, weight: .medium))
                                    .foregroundColor(.stelrMuted)
                                    .scaleEffect(tipPulse ? 1.04 : 1.0)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 18)
                    .padding(.top, 10)

                    CheckInRatingSlider(selectedScore: $selectedScore, previewScore: $previewScore)
                        .padding(.horizontal, 22)
                        .padding(.top, 14)

                    Button {
                        submit()
                    } label: {
                        Text("Check In")
                            .font(StelrTypography.button)
                            .foregroundColor(submitTextColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(selectedScore == nil ? Color.white.opacity(0.08) : ratingColor)
                                    .shadow(
                                        color: selectedScore == nil ? .clear : ratingColor.opacity(0.28),
                                        radius: 18,
                                        y: 8
                                    )
                            )
                    }
                    .buttonStyle(.stelrPress)
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .transition(.opacity)
            }

            if confirming {
                confirmationOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            if seasonRatingConfirmed {
                seasonRatingConfirmationOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .presentationDetents([.height(showingSeasonRating ? 660 : (supportsEpisode ? 628 : 524))])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(show.title)
                    .font(StelrTypography.sectionTitle)
                    .foregroundColor(.stelrText)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(show.platform)
                    if supportsEpisode {
                        Text("-")
                        Text("S\(season)")
                    }
                }
                .font(.system(size: 13.2))
                .foregroundColor(.stelrMuted)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14.2, weight: .semibold))
                    .foregroundColor(.stelrMuted)
                    .frame(width: 31, height: 31)
                    .background(Color.white.opacity(0.07))
                    .clipShape(Circle())
            }
            .buttonStyle(.stelrPress)
        }
        .padding(.horizontal, 18)
    }

    private var episodeStepper: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                Text("Season")
                    .font(.system(size: 13.2, weight: .medium))
                    .foregroundColor(.stelrMuted)
                    .frame(width: 56, alignment: .leading)

                stepperButton(systemName: "minus", disabled: season <= 1) {
                    season = max(1, season - 1)
                    episode = 1
                }

                Text("S\(season)")
                    .font(StelrTypography.sectionTitle)
                    .foregroundColor(.stelrText)
                    .frame(minWidth: 74)
                    .contentTransition(.numericText())

                stepperButton(systemName: "plus") {
                    season += 1
                    episode = 1
                }

                Spacer()

                if let totalSeasons, season <= totalSeasons {
                    Text("of \(totalSeasons)")
                        .font(.system(size: 12.2, weight: .medium))
                        .foregroundColor(.stelrMuted.opacity(0.74))
                }
            }

            Rectangle()
                .fill(Color.stelrBorder.opacity(0.7))
                .frame(height: 0.5)

            HStack(spacing: 14) {
                Text("Episode")
                    .font(.system(size: 13.2, weight: .medium))
                    .foregroundColor(.stelrMuted)
                    .frame(width: 56, alignment: .leading)

                stepperButton(systemName: "minus", disabled: episode <= 1) {
                    episode = max(1, episode - 1)
                }

                Text(episodeLabel)
                    .font(StelrTypography.sectionTitle)
                    .foregroundColor(.stelrText)
                    .frame(minWidth: 92)
                    .contentTransition(.numericText())

                stepperButton(systemName: "plus", disabled: episodePlusDisabled) {
                    incrementEpisode()
                }

                Spacer()
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.045))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.stelrBorder, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 18)
    }

    private var episodeLabel: String {
        if let episodeCap {
            return "Ep \(episode) / \(episodeCap)"
        }
        return "Ep \(episode)"
    }

    private var confirmationOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                VibeWaveView(vibe: step.vibe, score: step.score, size: 52, animate: true)
                    .frame(width: 132, height: 132)
                Text(step.vibe.label)
                    .font(StelrTypography.sectionTitle)
                    .foregroundColor(ratingColor)
                Text("\(show.title)\(supportsEpisode ? " - S\(season) Ep \(episode)" : "")")
                    .font(.system(size: 13.8))
                    .foregroundColor(.stelrMuted)
            }
            .padding(28)
            .background(Color.black.opacity(0.42))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.12), lineWidth: 0.7))
            .padding(.horizontal, 28)
        }
    }

    // MARK: - Season Rating Screen

    private var seasonRatingContent: some View {
        let step = CheckInStep.from(seasonRatingPicked ?? seasonPreviewScore)
        let ratingColor = Color(hex: step.coreHex)

        return VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(width: 36, height: 4)
                .padding(.top, 24)
                .padding(.bottom, 18)

            VStack(spacing: 7) {
                Text("season \(season) complete 🎬")
                    .font(.system(size: 13.2, weight: .semibold))
                    .foregroundColor(.stelrMuted)
                Text("how was it?")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.stelrText)
                Text(show.title)
                    .font(.system(size: 13.4, weight: .medium))
                    .foregroundColor(.stelrMuted.opacity(0.72))
                    .lineLimit(1)
            }
            .padding(.top, 18)
            .multilineTextAlignment(.center)

            // Fixed-height star area keeps the slider from moving as the visual changes.
            ZStack {
                VibeWaveView(vibe: step.vibe, score: step.score, size: 60, animate: true)
                    .frame(width: 126, height: 126)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 190)
            .padding(.top, 12)

            // Same slider as vibe check-in
            CheckInRatingSlider(selectedScore: $seasonRatingPicked, previewScore: $seasonPreviewScore, stableTicks: true)
                .padding(.horizontal, 20)
                .frame(height: 88)

            Spacer(minLength: 20)

            // Save / skip
            VStack(spacing: 10) {
                Button {
                    let score = seasonRatingPicked ?? seasonPreviewScore
                    StelrHaptics.success()
                    onSeasonRating?(season, score)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                        withAnimation(.easeInOut(duration: 0.18)) { seasonRatingConfirmed = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { dismiss() }
                    }
                } label: {
                    Text("Save")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "1a0e02"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(ratingColor)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                        .shadow(color: ratingColor.opacity(0.28), radius: 10, y: 5)
                }
                .buttonStyle(.stelrPress)
                .animation(.easeInOut(duration: 0.18), value: seasonRatingPicked)

                Button { dismiss() } label: {
                    Text("skip")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.stelrMuted.opacity(0.55))
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var seasonRatingConfirmationOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            if let picked = seasonRatingPicked {
                let step = CheckInStep.from(picked)
                VStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Text(picked.truncatingRemainder(dividingBy: 1) == 0
                             ? "\(Int(picked))"
                             : String(format: "%.1f", picked))
                            .font(.system(size: 44, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Image(systemName: "star.fill")
                            .font(.system(size: 22, weight: .semibold))
                    }
                    .foregroundStyle(Color(hex: step.coreHex))

                    VStack(spacing: 4) {
                        Text("Season \(season) rated")
                            .font(.system(size: 17.4, weight: .semibold))
                            .foregroundColor(.stelrText)
                        Text(show.title)
                            .font(.system(size: 13.8))
                            .foregroundColor(.stelrMuted)
                    }
                }
                .padding(32)
                .background(Color.black.opacity(0.44))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.12), lineWidth: 0.7))
                .padding(.horizontal, 32)
            }
        }
    }

    private func submit() {
        guard let selectedScore else {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.55)) { tipPulse = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.65)) { tipPulse = false }
            }
            return
        }

        StelrHaptics.success()
        onSubmit(supportsEpisode ? season : nil, supportsEpisode ? episode : nil, selectedScore)
        withAnimation(.easeInOut(duration: 0.18)) { confirming = true }

        if supportsEpisode && justFinishedSeason {
            // Brief vibe check confirmation, then slide to season rating
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
                withAnimation(.spring(response: 0.44, dampingFraction: 0.80)) {
                    confirming = false
                    showingSeasonRating = true
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                dismiss()
            }
        }
    }

    private func incrementEpisode() {
        if let episodeCap, episode >= episodeCap {
            guard canAutoAdvanceSeason else {
                episode = episodeCap
                return
            }
            season += 1
            episode = 1
            StelrHaptics.selection()
            return
        }
        episode += 1
    }

    private func stepperButton(systemName: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            guard !disabled else { return }
            StelrHaptics.lightTap()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.72)) {
                action()
            }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 13.4, weight: .semibold))
                .foregroundColor(disabled ? .stelrMuted.opacity(0.32) : .stelrText)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.06))
                .clipShape(Circle())
        }
        .disabled(disabled)
        .buttonStyle(.stelrPress)
    }
}

struct ShowActionSheet: View {
    let show: Show
    var onViewShow: () -> Void
    var onCheckIn: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 18)

            HStack(spacing: 12) {
                ShowPosterView(show: show, width: 54, height: 76, radius: 10)
                VStack(alignment: .leading, spacing: 4) {
                    Text(show.title)
                        .font(StelrTypography.sectionTitle)
                        .foregroundColor(.stelrText)
                        .lineLimit(1)
                    Text(show.platform)
                        .font(.system(size: 13.2))
                        .foregroundColor(.stelrMuted)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)

            HStack(spacing: 10) {
                Button {
                    closeThen(onViewShow)
                } label: {
                    Label("View Show", systemImage: "rectangle.stack")
                        .font(.system(size: 15.2, weight: .semibold))
                        .foregroundColor(.stelrText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.white.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.stelrBorder, lineWidth: 0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.stelrPress)

                Button {
                    closeThen(onCheckIn)
                } label: {
                    Label("Check In", systemImage: "sparkle")
                        .font(.system(size: 15.2, weight: .semibold))
                        .foregroundColor(Color(hex: "0a0a14"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.stelrAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.stelrPress)
            }
            .padding(.horizontal, 18)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(hex: "1c1814").ignoresSafeArea())
        .presentationDetents([.height(220)])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }

    private func closeThen(_ action: @escaping () -> Void) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            action()
        }
    }
}


// MARK: - EpisodeNoteSheet

struct EpisodeNoteSheet: View {
    let show: Show
    let currentSeason: Int
    let currentEpisode: Int
    let preSelectedEpisode: Int
    var onSubmit: (_ season: Int, _ episode: Int, _ text: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var selectedEpisode: Int
    @State private var noteText: String = ""
    @FocusState private var textFocused: Bool

    private let characterLimit = 280

    init(
        show: Show,
        currentSeason: Int,
        currentEpisode: Int,
        preSelectedEpisode: Int,
        onSubmit: @escaping (_ season: Int, _ episode: Int, _ text: String) -> Void
    ) {
        self.show = show
        self.currentSeason = currentSeason
        self.currentEpisode = currentEpisode
        self.preSelectedEpisode = preSelectedEpisode
        self.onSubmit = onSubmit
        _selectedEpisode = State(initialValue: min(max(1, preSelectedEpisode), max(1, currentEpisode)))
    }

    private var completedEpisodes: [Int] {
        guard currentEpisode >= 1 else { return [] }
        return Array(1...currentEpisode)
    }

    private var canSubmit: Bool {
        !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var characterCount: Int {
        noteText.count
    }

    private var remainingCharacters: Int {
        max(0, characterLimit - characterCount)
    }

    private var existingNote: String? {
        appState.myComment(showId: show.id, season: currentSeason, episode: selectedEpisode)?.text
    }

    var body: some View {
        ZStack {
            StelrStarFieldBackground()
                .ignoresSafeArea()

            RadialGradient(
                colors: [Color(hex: show.accentColor).opacity(0.06), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 320
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 36, height: 4)
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(show.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        HStack(spacing: 5) {
                            Text("S\(currentSeason)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("·")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text("Episode \(selectedEpisode)")
                                .font(.caption)
                                .foregroundStyle(Color(hex: show.accentColor).opacity(0.90))
                                .contentTransition(.numericText())
                                .animation(.easeInOut(duration: 0.18), value: selectedEpisode)
                        }
                    }

                    Spacer()

                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.07), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)

                // Episode chip selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(completedEpisodes, id: \.self) { ep in
                            let isSelected = ep == selectedEpisode
                            let hasNote = appState.myComment(showId: show.id, season: currentSeason, episode: ep) != nil

                            Button {
                                withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) {
                                    selectedEpisode = ep
                                    noteText = appState.myComment(
                                        showId: show.id, season: currentSeason, episode: ep
                                    )?.text ?? ""
                                }
                                StelrHaptics.selection()
                            } label: {
                                HStack(spacing: 4) {
                                    Text("E\(ep)")
                                        .font(.caption)
                                        .fontWeight(isSelected ? .semibold : .regular)
                                        .foregroundStyle(isSelected ? Color(hex: show.accentColor) : Color.secondary)

                                    if hasNote {
                                        Circle()
                                            .fill(isSelected ? Color(hex: show.accentColor) : Color.secondary.opacity(0.6))
                                            .frame(width: 4, height: 4)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    isSelected
                                        ? Color(hex: show.accentColor).opacity(0.15)
                                        : Color.white.opacity(0.055),
                                    in: Capsule(style: .continuous)
                                )
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(
                                            isSelected
                                                ? Color(hex: show.accentColor).opacity(0.38)
                                                : Color.white.opacity(0.07),
                                            lineWidth: isSelected ? 1 : 0.6
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 3)
                }
                .padding(.top, 18)

                // Text editor
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $noteText)
                        .focused($textFocused)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 108, maxHeight: 160)

                    if noteText.isEmpty {
                        Text("What's your take on this episode?")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.7)
                )
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .onChange(of: noteText) { _, newValue in
                    let capped = cappedNote(newValue)
                    if capped != newValue {
                        noteText = capped
                    }
                }

                // Spoiler hint
                HStack(spacing: 6) {
                    Image(systemName: "eye.slash")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("Friends see your take after they check in to E\(selectedEpisode)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.18), value: selectedEpisode)
                    Spacer()
                    Text("\(remainingCharacters) characters left")
                        .font(.caption2)
                        .foregroundStyle(remainingCharacters == 0 ? AnyShapeStyle(Color(hex: show.accentColor)) : AnyShapeStyle(.tertiary))
                        .monospacedDigit()
                }
                .padding(.horizontal, 22)
                .padding(.top, 10)

                Spacer(minLength: 0)

                // Submit
                Button {
                    guard canSubmit else { return }
                    StelrHaptics.success()
                    onSubmit(currentSeason, selectedEpisode, normalizedNote(noteText))
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil.line")
                            .font(.body)
                        Text(existingNote != nil ? "Update take" : "Post take")
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(canSubmit ? Color(hex: "0a0a14") : .stelrMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        canSubmit
                            ? Color(hex: show.accentColor)
                            : Color.white.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .shadow(
                        color: canSubmit ? Color(hex: show.accentColor).opacity(0.24) : .clear,
                        radius: 14, y: 7
                    )
                }
                .disabled(!canSubmit)
                .buttonStyle(.stelrPress)
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .presentationDetents([.height(452)])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
        .onAppear {
            // Pre-fill if editing an existing note
            noteText = appState.myComment(
                showId: show.id, season: currentSeason, episode: selectedEpisode
            )?.text ?? ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                textFocused = true
            }
        }
    }

    private func cappedNote(_ value: String) -> String {
        guard value.count > characterLimit else { return value }
        return String(value.prefix(characterLimit))
    }

    private func normalizedNote(_ value: String) -> String {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return cappedNote(normalized)
    }
}

// MARK: - CheckInRatingSlider

struct CheckInRatingSlider: View {
    @Binding var selectedScore: Double?
    @Binding var previewScore: Double
    var stableTicks: Bool = false

    private let steps = CheckInStep.all

    private var activeStep: CheckInStep {
        CheckInStep.from(selectedScore ?? previewScore)
    }

    private var trackColor: Color {
        H7bStarVisualStyle.ratingColor(appScore: activeStep.score)
    }

    var body: some View {
        GeometryReader { geo in
            let width = max(1, geo.size.width)
            let sideInset: CGFloat = 10
            let trackY: CGFloat = 23
            let thumbY: CGFloat = 25
            let index = indexFor(score: selectedScore ?? previewScore)
            let x = xPosition(for: index, width: width, sideInset: sideInset)
            let usableWidth = max(1, width - sideInset * 2)

            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .allowsHitTesting(false)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.07))
                    .frame(width: usableWidth, height: 4)
                    .offset(x: sideInset, y: trackY)
                    .allowsHitTesting(false)

                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.05),
                                trackColor.opacity(0.88),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(4, x - sideInset), height: 4)
                    .offset(x: sideInset, y: trackY)
                    .animation(.spring(response: 0.35, dampingFraction: 0.72), value: x)
                    .allowsHitTesting(false)

                ForEach(Array(steps.enumerated()), id: \.offset) { item in
                    Button {
                        setScore(item.element.score)
                    } label: {
                        tickView(step: item.element)
                            .frame(width: 44, height: 88, alignment: .top)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .position(
                        x: xPosition(for: item.offset, width: width, sideInset: sideInset),
                        y: 44
                    )
                    .zIndex(2)
                }

                Circle()
                    .fill(Color.white.opacity(0.90))
                    .frame(width: 20, height: 20)
                    .shadow(color: trackColor.opacity(selectedScore == nil ? 0.20 : 0.65), radius: 8)
                    .position(x: x, y: thumbY)
                    .animation(.spring(response: 0.35, dampingFraction: 0.72), value: x)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        setScore(score(at: value.location.x, width: width, sideInset: sideInset))
                    }
                    .onEnded { value in
                        setScore(score(at: value.location.x, width: width, sideInset: sideInset))
                    }
            )
        }
        .frame(height: 88)
    }

    private func tickView(step: CheckInStep) -> some View {
        let isActive    = step.score == (selectedScore ?? previewScore)
        let isWhole     = step.score.rounded() == step.score
        let isLeftFill  = step.score <= (selectedScore ?? previewScore)
        let tickH: CGFloat = stableTicks ? (isWhole ? 10 : 6) : (isActive ? 13 : isWhole ? 10 : 6)
        let tickOpacity: Double = stableTicks ? (isLeftFill ? 0.60 : 0.30) : (isActive ? 0.50 : isLeftFill ? 0.60 : 0.30)
        let tickColor = isLeftFill ? trackColor : Color.white
        let labelSize: CGFloat = stableTicks ? 17.2 : (isActive ? 19.4 : 17.2)
        let labelWeight: Font.Weight = stableTicks ? .medium : (isActive ? .semibold : .medium)

        return VStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 1)
                .fill(tickColor.opacity(tickOpacity))
                .frame(width: isWhole ? 1.5 : 1, height: tickH)

            Text(isWhole ? "\(Int(step.score))" : "½")
                .font(.system(size: labelSize, weight: labelWeight, design: .rounded))
                .foregroundColor(isLeftFill ? trackColor.opacity(0.75) : .stelrMuted.opacity(0.55))
                .monospacedDigit()
        }
        .frame(width: 44, height: 88, alignment: .top)
        .padding(.top, 8)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }

    private func setScore(_ score: Double) {
        let snapped = CheckInStep.from(score).score
        let changed = selectedScore != snapped
        previewScore = snapped
        selectedScore = snapped
        if changed { StelrHaptics.selection() }
    }

    private func score(at x: CGFloat, width: CGFloat, sideInset: CGFloat) -> Double {
        let usableWidth = max(1, width - sideInset * 2)
        let clampedX = min(max(x, sideInset), width - sideInset)
        let idx = Int(round((clampedX - sideInset) / usableWidth * CGFloat(steps.count - 1)))
        return steps[min(max(idx, 0), steps.count - 1)].score
    }

    private func indexFor(score: Double) -> Int {
        steps.enumerated().min(by: { abs($0.element.score - score) < abs($1.element.score - score) })?.offset ?? 0
    }

    private func xPosition(for index: Int, width: CGFloat, sideInset: CGFloat) -> CGFloat {
        let usableWidth = max(1, width - sideInset * 2)
        return sideInset + CGFloat(index) / CGFloat(steps.count - 1) * usableWidth
    }
}
