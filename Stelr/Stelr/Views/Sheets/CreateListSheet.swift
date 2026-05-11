import SwiftUI

// MARK: - CreateListSheet

struct CreateListSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    /// Pass an existing list to edit, or nil to create a new one.
    var editingList: ShowList? = nil

    // ── State ────────────────────────────────────────────────────────────────
    @State private var title: String = ""
    @State private var entries: [ShowListEntry] = []
    @State private var editingSlot: Int? = nil          // rank 1-5 being filled
    @State private var searchQuery: String = ""
    @State private var searchResults: [Show] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var freeTextDraft: String = ""       // typed when no results
    @FocusState private var titleFocused: Bool
    @FocusState private var searchFocused: Bool

    private let titleSuggestions = [
        "Top 5 Anime", "Top 5 Drama", "Top 5 Sci-Fi",
        "Top 5 Comfort Shows", "Top 5 Thrillers", "Top 5 Comedy"
    ]

    private var isEditing: Bool { editingList != nil }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !entries.isEmpty
    }

    // ── Body ─────────────────────────────────────────────────────────────────
    var body: some View {
        ZStack {
            Color(hex: "0d0d0f").ignoresSafeArea()

            VStack(spacing: 0) {
                dragHandle

                if let slot = editingSlot {
                    slotSearchView(rank: slot)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    listEditorView
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.84), value: editingSlot)
        }
        .onAppear {
            if let list = editingList {
                title = list.title
                entries = list.entries
            } else {
                titleFocused = true
            }
        }
    }

    // MARK: Drag handle

    private var dragHandle: some View {
        Capsule()
            .fill(Color.white.opacity(0.18))
            .frame(width: 36, height: 4)
            .padding(.top, 8)
            .padding(.bottom, 14)
    }

    // MARK: List editor (main view)

    private var listEditorView: some View {
        VStack(spacing: 0) {
            // ── Header ───────────────────────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isEditing ? "edit list" : "new list")
                        .font(StelrTypography.pageTitle)
                        .foregroundColor(.stelrText)
                    Text("rank your top 5")
                        .font(.system(size: 12.3))
                        .foregroundColor(.stelrMuted)
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
            .padding(.horizontal, 18)
            .padding(.bottom, 18)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {

                    // ── Title field ──────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        Text("List title")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.stelrMuted)
                            .textCase(.uppercase)
                            .tracking(0.6)

                        TextField("e.g. Top 5 Anime", text: $title)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.stelrText)
                            .tint(.stelrAccent)
                            .focused($titleFocused)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(titleFocused ? Color.stelrAccent.opacity(0.5) : Color.stelrBorder, lineWidth: 0.7)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Quick suggestions
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(titleSuggestions, id: \.self) { s in
                                    Button {
                                        title = s
                                        titleFocused = false
                                    } label: {
                                        Text(s)
                                            .font(.system(size: 12.5, weight: .medium))
                                            .foregroundColor(title == s ? .white : .stelrMuted)
                                            .padding(.horizontal, 11)
                                            .padding(.vertical, 6)
                                            .background(
                                                title == s
                                                    ? AnyShapeStyle(Color.stelrAccent)
                                                    : AnyShapeStyle(Color.white.opacity(0.07))
                                            )
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)

                    // ── Slots ────────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Shows")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.stelrMuted)
                            .textCase(.uppercase)
                            .tracking(0.6)
                            .padding(.horizontal, 18)

                        VStack(spacing: 0) {
                            ForEach(1...5, id: \.self) { rank in
                                slotRow(rank: rank)
                                if rank < 5 {
                                    Divider()
                                        .background(Color.stelrBorder)
                                        .padding(.leading, 60)
                                }
                            }
                        }
                        .background(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.stelrBorder, lineWidth: 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 18)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top, 2)
            }

            // ── Save button ──────────────────────────────────────────────────
            saveBar
        }
    }

    // MARK: Slot row

    @ViewBuilder
    private func slotRow(rank: Int) -> some View {
        let entry = entries.first(where: { $0.rank == rank })
        let show = entry.flatMap { appState.show(forListEntry: $0) }

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                searchQuery = ""
                searchResults = []
                freeTextDraft = ""
                editingSlot = rank
            }
            searchFocused = true
        } label: {
            HStack(spacing: 14) {
                // Rank number
                Text("\(rank)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(entry != nil ? .stelrAccent : .stelrMuted.opacity(0.5))
                    .frame(width: 24)

                if let entry {
                    // Filled slot
                    if let show {
                        ShowPosterView(show: show, width: 34, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    } else {
                        // Free-text — no poster
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.07))
                            .frame(width: 34, height: 48)
                            .overlay(
                                Image(systemName: "text.alignleft")
                                    .font(.system(size: 12))
                                    .foregroundColor(.stelrMuted)
                            )
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(show?.title ?? entry.freeTextTitle ?? "")
                            .font(.system(size: 14.5, weight: .medium))
                            .foregroundColor(.stelrText)
                            .lineLimit(1)
                        if entry.isFreeText {
                            Text("custom entry")
                                .font(.system(size: 11.5))
                                .foregroundColor(.stelrMuted)
                        } else if let genre = show?.genre {
                            Text(genre)
                                .font(.system(size: 11.5))
                                .foregroundColor(.stelrMuted)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // Remove button
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                            entries.removeAll { $0.rank == rank }
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.stelrMuted.opacity(0.6))
                    }
                    .buttonStyle(.plain)

                } else {
                    // Empty slot
                    Text("add a show")
                        .font(.system(size: 14.5))
                        .foregroundColor(.stelrMuted.opacity(0.5))
                    Spacer()
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.stelrMuted.opacity(0.5))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: Slot search view

    @ViewBuilder
    private func slotSearchView(rank: Int) -> some View {
        VStack(spacing: 0) {
            // Back + title
            HStack(spacing: 10) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        editingSlot = nil
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.stelrAccent)
                }

                Text("slot \(rank)")
                    .font(StelrTypography.pageTitle)
                    .foregroundColor(.stelrText)

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
            .padding(.horizontal, 18)
            .padding(.bottom, 14)

            // Search bar
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15.7))
                    .foregroundColor(searchQuery.isEmpty ? .stelrMuted : .stelrAccent)
                TextField("search shows…", text: $searchQuery)
                    .font(.system(size: 16.8))
                    .foregroundColor(.stelrText)
                    .tint(.stelrAccent)
                    .focused($searchFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: searchQuery) { _, q in
                        scheduleSearch(query: q)
                    }
                if !searchQuery.isEmpty {
                    Button { searchQuery = "" } label: {
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
                    .stroke(Color.stelrAccent.opacity(0.45), lineWidth: 0.7)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 18).padding(.bottom, 10)

            Divider().background(Color.stelrBorder)

            // Results
            if isSearching {
                Spacer()
                ProgressView().tint(.stelrAccent)
                Spacer()
            } else if !searchQuery.isEmpty && searchResults.isEmpty {
                // No library match — offer free text
                noResultsView(rank: rank)
            } else if searchResults.isEmpty {
                // Empty state
                Spacer()
                Text("search for a show or type a title")
                    .font(.system(size: 14.5))
                    .foregroundColor(.stelrMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(searchResults) { show in
                            searchResultRow(show: show, rank: rank)
                            Divider()
                                .background(Color.stelrBorder)
                                .padding(.leading, 62)
                        }
                    }
                }
            }
        }
        .onAppear { searchFocused = true }
    }

    @ViewBuilder
    private func searchResultRow(show: Show, rank: Int) -> some View {
        let alreadyUsed = entries.contains(where: { $0.showId == show.id })

        Button {
            guard !alreadyUsed else { return }
            let rememberedShow = appState.rememberListShow(show)
            addEntry(ShowListEntry(rank: rank, showId: rememberedShow.id))
        } label: {
            HStack(spacing: 12) {
                ShowPosterView(show: show, width: 36, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(show.title)
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundColor(alreadyUsed ? .stelrMuted : .stelrText)
                        .lineLimit(1)
                    if let genre = show.genre {
                        Text(genre)
                            .font(.system(size: 12))
                            .foregroundColor(.stelrMuted)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if alreadyUsed {
                    Text("added")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.stelrMuted)
                } else {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.stelrAccent)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .disabled(alreadyUsed)
    }

    @ViewBuilder
    private func noResultsView(rank: Int) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("No results for \"\(searchQuery)\"")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.stelrText)
                Text("Not in the library? Add it as a custom entry.")
                    .font(.system(size: 13.5))
                    .foregroundColor(.stelrMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)

            // Editable title for free-text entry
            HStack(spacing: 9) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 14))
                    .foregroundColor(.stelrMuted)
                TextField("Title", text: $freeTextDraft)
                    .font(.system(size: 15.5))
                    .foregroundColor(.stelrText)
                    .tint(.stelrAccent)
                    .onAppear { freeTextDraft = searchQuery }
            }
            .padding(.horizontal, 13).padding(.vertical, 11)
            .background(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.stelrBorder, lineWidth: 0.7)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 18)

            Button {
                let t = freeTextDraft.trimmingCharacters(in: .whitespaces)
                guard !t.isEmpty else { return }
                addEntry(ShowListEntry(rank: rank, showId: nil, freeTextTitle: t))
            } label: {
                Text("Add \"\(freeTextDraft.trimmingCharacters(in: .whitespaces))\"")
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.stelrAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .padding(.horizontal, 18)
            .disabled(freeTextDraft.trimmingCharacters(in: .whitespaces).isEmpty)

            Spacer()
        }
    }

    // MARK: Save bar

    private var saveBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color.stelrBorder)
            Button {
                let list = ShowList(
                    id: editingList?.id ?? UUID(),
                    title: title.trimmingCharacters(in: .whitespaces),
                    entries: entries,
                    createdAt: editingList?.createdAt ?? Date()
                )
                appState.saveList(list)
                dismiss()
            } label: {
                Text(isEditing ? "save changes" : "save list")
                    .font(.system(size: 16.8, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(canSave ? Color.stelrAccent : Color.stelrMuted.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!canSave)
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: Helpers

    private func addEntry(_ entry: ShowListEntry) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            entries.removeAll { $0.rank == entry.rank }
            entries.append(entry)
            entries.sort { $0.rank < $1.rank }
            editingSlot = nil
        }
    }

    private func scheduleSearch(query: String) {
        searchTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 320_000_000)
            guard !Task.isCancelled else { return }
            let results = await appState.searchShows(query: query)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                searchResults = results
                isSearching = false
            }
        }
    }
}
