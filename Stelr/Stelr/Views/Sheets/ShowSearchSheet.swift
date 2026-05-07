import SwiftUI

struct ShowSearchSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [Show] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    /// Tracks ids added this session so the checkmark persists without re-querying
    @State private var addedIds: Set<Int> = []
    @State private var detailShow: Show?

    var body: some View {
        VStack(spacing: 0) {
            // ── Drag handle ──────────────────────────────────────────────────
            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(width: 36, height: 4)
                .padding(.top, 8).padding(.bottom, 14)

            // ── Title row ────────────────────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("add a show")
                        .font(StelrTypography.pageTitle)
                        .foregroundColor(.stelrText)
                    Text("search TV + anime")
                        .font(.system(size: 12.3)).foregroundColor(.stelrMuted)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14.6, weight: .semibold))
                        .foregroundColor(.stelrMuted)
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.07))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 18).padding(.bottom, 14)

            // ── Search bar ───────────────────────────────────────────────────
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15.7))
                    .foregroundColor(query.isEmpty ? .stelrMuted : .stelrAccent)
                TextField("search shows…", text: $query)
                    .font(.system(size: 16.8))
                    .foregroundColor(.stelrText)
                    .tint(.stelrAccent)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.stelrMuted)
                            .font(.system(size: 16.8))
                    }
                }
            }
            .padding(.horizontal, 13).padding(.vertical, 11)
            .background(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(query.isEmpty ? Color.stelrBorder : Color.stelrAccent.opacity(0.45), lineWidth: 0.7)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 18).padding(.bottom, 10)
            .animation(.easeInOut(duration: 0.2), value: query.isEmpty)

            Divider().background(Color.stelrBorder)

            // ── Body ─────────────────────────────────────────────────────────
            Group {
                if isSearching {
                    loadingView
                } else if results.isEmpty && !query.isEmpty {
                    emptyView
                } else if results.isEmpty {
                    promptView
                } else {
                    resultsList
                }
            }
            .frame(maxHeight: .infinity)
        }
        .background(Color(hex: "1c1814"))
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
        .sheet(item: $detailShow) { show in
            ShowDetailView(show: show, watchingFriends: appState.friendsWatching(showId: show.id))
        }
        .onChange(of: query) { _, newVal in
            scheduleSearch(query: newVal)
        }
    }

    // ── Sub-views ─────────────────────────────────────────────────────────────

    private var resultsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(results) { show in
                    let alreadyInRotation = appState.myShows.contains(where: { $0.showId == show.id })
                    let justAdded = addedIds.contains(show.id)
	                    SearchResultRow(
	                        show: show,
	                        isAdded: alreadyInRotation || justAdded,
	                        onOpen: { detailShow = show },
	                        onAdd: {
	                            withAnimation(.spring(response: 0.3)) {
	                                appState.addShowToRotation(show)
	                                addedIds.insert(show.id)
	                            }
	                        }
	                    )
                    Divider().background(Color.stelrBorder).padding(.horizontal, 18)
                }
            }
            .padding(.bottom, 48)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(Color.stelrAccent)
                .scaleEffect(1.1)
            Text("searching…")
                .font(.system(size: 13.4)).foregroundColor(.stelrMuted)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Text("📺").font(.system(size: 38))
            Text("no results for \(query)")
                .font(StelrTypography.sectionTitle).italic().foregroundColor(.stelrMuted)
            Text("try another title or check spelling")
                .font(.system(size: 12.3)).foregroundColor(.stelrMuted.opacity(0.7))
        }
    }

    private var promptView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tv")
                .font(.system(size: 30, weight: .ultraLight))
                .foregroundColor(.stelrMuted)
            Text("search any show")
                .font(StelrTypography.sectionTitle).italic().foregroundColor(.stelrMuted)
        }
        .opacity(0.6)
    }

    // ── Search logic ──────────────────────────────────────────────────────────

    private func scheduleSearch(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            results = []
            isSearching = false
            return
        }
        searchTask = Task {
            // 420 ms debounce
            try? await Task.sleep(nanoseconds: 420_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { isSearching = true }
            let found = await appState.searchShows(query: trimmed)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                results = found
                isSearching = false
            }
        }
    }
}

// ── Search result row ─────────────────────────────────────────────────────────

private struct SearchResultRow: View {
    let show: Show
    let isAdded: Bool
    var onOpen: () -> Void
    var onAdd: () -> Void

    @State private var tapped = false

    var body: some View {
        HStack(spacing: 13) {
            Button {
                StelrHaptics.lightTap()
                onOpen()
            } label: {
                HStack(spacing: 13) {
                    ShowPosterView(show: show, width: 50, height: 70, radius: 9) {
                        VStack {
                            Spacer()
                            if let genre = show.genre?.components(separatedBy: " · ").first {
                                Text(genre)
                                    .font(.system(size: 8.4, weight: .medium))
                                    .foregroundColor(.white.opacity(0.75))
                                    .padding(.horizontal, 4).padding(.vertical, 2)
                                    .background(Color.black.opacity(0.45))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .padding(5)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(show.title)
                            .font(StelrTypography.sectionTitle).foregroundColor(.stelrText)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Text(show.platform)
                                .font(.system(size: 12.3)).foregroundColor(.stelrMuted)
                            if let yr = show.year {
                                Text("·").font(.system(size: 12.5)).foregroundColor(.stelrBorder)
                                Text(String(yr))
                                    .font(.system(size: 12.3)).foregroundColor(.stelrMuted)
                            }
                        }

                        if let genre = show.genre {
                            Text(genre)
                                .font(.system(size: 11.8)).foregroundColor(.stelrMuted.opacity(0.7))
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.stelrPress)

            // Add / added button
            Button {
                guard !isAdded else { return }
                tapped = true
                onAdd()
            } label: {
                ZStack {
                    Circle()
                        .fill(isAdded
                              ? Color(hex: "72c97e").opacity(0.12)
                              : Color.stelrAccent.opacity(0.10))
                        .overlay(
                            Circle().stroke(
                                isAdded
                                    ? Color(hex: "72c97e").opacity(0.35)
                                    : Color.stelrAccent.opacity(0.30),
                                lineWidth: 0.6
                            )
                        )
                    if isAdded {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13.4, weight: .semibold))
                            .foregroundColor(Color(hex: "72c97e"))
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 16.8, weight: .medium))
                            .foregroundColor(.stelrAccent)
                    }
                }
                .frame(width: 34, height: 34)
                .scaleEffect(tapped ? 0.88 : 1.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.55), value: tapped)
            }
            .buttonStyle(.stelrPress)
            .disabled(isAdded)
        }
        .padding(.horizontal, 18).padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}
