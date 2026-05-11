import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAuthSheet = false
    @State private var showCreateList = false
    @State private var editingList: ShowList? = nil
    @State private var previewList: ShowList? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            StelrStarFieldBackground().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("profile")
                            .font(StelrTypography.pageTitle)
                            .foregroundColor(.stelrText)
                        Spacer()
                        Button {} label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 16.5)).foregroundColor(.stelrMuted)
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 66).padding(.bottom, 24)

                    if appState.isAuthenticated, let user = appState.supabase.currentUser {
                        // Authenticated state
                        VStack(spacing: 20) {
                            // Avatar
                            ZStack {
                                Circle().fill(Color.stelrAccent.opacity(0.15))
                                    .overlay(Circle().stroke(Color.stelrAccent.opacity(0.4), lineWidth: 1.5))
                                Text(String(user.email?.prefix(1).uppercased() ?? "?"))
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundColor(.stelrAccent)
                            }
                            .frame(width: 80, height: 80)

                            Text(user.email ?? "")
                                .font(.system(size: 15.7)).foregroundColor(.stelrMuted)

                            TasteAuraBadge(aura: profileTasteAura, compact: true)
                                .padding(.horizontal, 20)

                            // Stats
                            HStack(spacing: 0) {
                                statCell(value: "\(appState.myShows.count)", label: "Shows")
                                Divider().background(Color.stelrBorder).frame(height: 40)
                                statCell(value: "\(appState.friends.count)", label: "Friends")
                                Divider().background(Color.stelrBorder).frame(height: 40)
                                statCell(value: "\(appState.activities.count)", label: "Vibes")
                            }
                            .background(Color.stelrSurface)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.stelrBorder, lineWidth: 0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 20)

                            // Lists section
                            listsSection

                            // Sign out
                            Button {
                                Task { try? await appState.supabase.signOut(); appState.isAuthenticated = false }
                            } label: {
                                Text("Sign out")
                                    .font(.system(size: 16.8, weight: .medium)).foregroundColor(.stelrMuted)
                                    .frame(maxWidth: .infinity).frame(height: 48)
                                    .background(Color.white.opacity(0.05))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.stelrBorder, lineWidth: 0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .padding(.horizontal, 20)
                        }
                    } else {
                        // Sign in prompt
                        VStack(spacing: 16) {
                            MascotView(mood: .idle, size: 60)
                            Text("Sign in to sync across devices")
                                .font(StelrTypography.sectionTitle).italic().foregroundColor(.stelrText)
                            Text("Your rotation, vibes and friends live on Supabase")
                                .font(.system(size: 14.6)).foregroundColor(.stelrMuted).multilineTextAlignment(.center)
                            Button { showAuthSheet = true } label: {
                                Text("Get started")
                                    .font(.system(size: 16.8, weight: .semibold)).foregroundColor(.white)
                                    .frame(maxWidth: .infinity).frame(height: 50)
                                    .background(Color.stelrAccent)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.top, 40)
                    }

                    Spacer(minLength: 80)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .sheet(isPresented: $showAuthSheet) { AuthSheet() }
        .sheet(isPresented: $showCreateList) {
            CreateListSheet()
                .environmentObject(appState)
        }
        .sheet(item: $editingList) { list in
            CreateListSheet(editingList: list)
                .environmentObject(appState)
        }
        .fullScreenCover(item: $previewList) { list in
            ListConstellationView(list: list) {
                previewList = nil
            }
            .environmentObject(appState)
        }
    }

    // MARK: Lists section

    private var profileTasteAura: TasteAura {
        TasteAura.make(
            myShows: appState.myShows,
            allShows: appState.shows,
            lists: appState.myLists,
            watchlistShows: appState.watchlistShows
        )
    }

    private var listsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Lists")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.stelrMuted)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Spacer()
            }
            .padding(.horizontal, 20)

            if appState.myLists.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "list.number")
                        .font(.system(size: 20))
                        .foregroundColor(.stelrMuted.opacity(0.5))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No lists yet")
                            .font(.system(size: 14.5, weight: .medium))
                            .foregroundColor(.stelrText.opacity(0.6))
                        Text("Ranked lists will appear here.")
                            .font(.system(size: 12.5))
                            .foregroundColor(.stelrMuted.opacity(0.5))
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.stelrBorder, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(appState.myLists) { list in
                        ListCardView(list: list)
                            .onTapGesture { previewList = list }
                            .contextMenu {
                                Button {
                                    editingList = list
                                } label: {
                                    Label("Edit list", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    appState.deleteList(id: list.id)
                                } label: {
                                    Label("Delete list", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(StelrTypography.statValue).foregroundColor(.stelrText)
            Text(label).font(StelrTypography.metadata).foregroundColor(.stelrMuted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16)
    }
}

// MARK: - ListCardView

struct ListCardView: View {
    @EnvironmentObject var appState: AppState
    let list: ShowList

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title + count
            HStack {
                Text(list.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.stelrText)
                Spacer()
                Text("\(list.filledCount)/5")
                    .font(.system(size: 12))
                    .foregroundColor(.stelrMuted)
            }

            // Poster strip
            HStack(spacing: 6) {
                ForEach(Array(1...5), id: \.self) { rank in
                    posterSlot(rank: rank)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.stelrMuted.opacity(0.5))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.stelrBorder, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func posterSlot(rank: Int) -> some View {
        let entry = listEntry(for: rank)
        let show = entry.flatMap { appState.show(forListEntry: $0) }

        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.stelrBorder, lineWidth: 0.5)
                )

            if let show {
                ShowPosterView(show: show, width: 48, height: 68, radius: 7)
            } else if let entry, entry.isFreeText {
                Text(entry.freeTextTitle?.prefix(1).uppercased() ?? "")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.stelrMuted)
            } else {
                Text("\(rank)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.stelrMuted.opacity(0.3))
            }
        }
        .frame(width: 48, height: 68)
        .overlay(alignment: .bottomLeading) {
            if entry != nil {
                Text("\(rank)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(3)
            }
        }
    }

    private func listEntry(for rank: Int) -> ShowListEntry? {
        list.entries.first { $0.rank == rank }
    }
}

// ─── Auth Sheet ──────────────────────────────────────────────────────────────
struct AuthSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var loading = false
    @State private var errorMsg: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "1c1814").ignoresSafeArea()
                VStack(spacing: 20) {
                    MascotView(mood: .happy, size: 52).padding(.top, 20)
                    Text(isSignUp ? "Create account" : "Welcome back")
                        .font(StelrTypography.pageTitle).foregroundColor(.stelrText)

                    VStack(spacing: 12) {
                        inputField("Email", text: $email, keyboard: .emailAddress)
                        inputField("Password", text: $password, secure: true)
                    }
                    .padding(.horizontal, 20)

                    if let err = errorMsg {
                        Text(err).font(StelrTypography.callout).foregroundColor(Color(hex: "c46060"))
                            .padding(.horizontal, 20)
                    }

                    Button {
                        loading = true; errorMsg = nil
                        Task {
                            do {
                                if isSignUp { try await appState.supabase.signUp(email: email, password: password) }
                                else        { try await appState.supabase.signIn(email: email, password: password) }
                                appState.isAuthenticated = true
                                dismiss()
                                await appState.loadUserData()
                            } catch {
                                errorMsg = error.localizedDescription
                            }
                            loading = false
                        }
                    } label: {
                        Group {
                            if loading { ProgressView().tint(.white) }
                            else { Text(isSignUp ? "Create account" : "Sign in").font(StelrTypography.button).foregroundColor(.white) }
                        }
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(Color.stelrAccent).clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(loading || email.isEmpty || password.isEmpty)
                    .padding(.horizontal, 20)

                    Button { isSignUp.toggle() } label: {
                        Text(isSignUp ? "Already have an account? Sign in" : "No account? Create one")
                            .font(.system(size: 14.6)).foregroundColor(.stelrMuted)
                    }
                    Spacer()
                }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.foregroundColor(.stelrMuted)
            }}
        }
        .preferredColorScheme(.dark)
    }

    private func inputField(_ placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default, secure: Bool = false) -> some View {
        Group {
            if secure {
                SecureField(placeholder, text: text)
            } else {
                TextField(placeholder, text: text).keyboardType(keyboard).autocapitalization(.none)
            }
        }
        .font(StelrTypography.callout).foregroundColor(.stelrText)
        .padding(14)
        .background(Color.white.opacity(0.05))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.stelrBorder, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .tint(.stelrAccent)
    }
}
