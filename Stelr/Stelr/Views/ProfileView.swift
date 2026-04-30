import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAuthSheet = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.stelrBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("profile")
                            .font(.custom("Georgia", size: 26.9).weight(.semibold))
                            .foregroundColor(.stelrText)
                        Spacer()
                        Button {} label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 20.2)).foregroundColor(.stelrMuted)
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
                                    .font(.system(size: 40.3, weight: .semibold))
                                    .foregroundColor(.stelrAccent)
                            }
                            .frame(width: 80, height: 80)

                            Text(user.email ?? "")
                                .font(.system(size: 15.7)).foregroundColor(.stelrMuted)

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
                                .font(.custom("Georgia", size: 20.2)).italic().foregroundColor(.stelrText)
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
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.custom("Georgia", size: 27.6).weight(.semibold)).foregroundColor(.stelrText)
            Text(label).font(.system(size: 13.8)).foregroundColor(.stelrMuted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16)
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
                        .font(.custom("Georgia", size: 24.6)).foregroundColor(.stelrText)

                    VStack(spacing: 12) {
                        inputField("Email", text: $email, keyboard: .emailAddress)
                        inputField("Password", text: $password, secure: true)
                    }
                    .padding(.horizontal, 20)

                    if let err = errorMsg {
                        Text(err).font(.system(size: 16.4)).foregroundColor(Color(hex: "c46060"))
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
                            } catch {
                                errorMsg = error.localizedDescription
                            }
                            loading = false
                        }
                    } label: {
                        Group {
                            if loading { ProgressView().tint(.white) }
                            else { Text(isSignUp ? "Create account" : "Sign in").font(.system(size: 18.8, weight: .semibold)).foregroundColor(.white) }
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
        .font(.system(size: 16.8)).foregroundColor(.stelrText)
        .padding(14)
        .background(Color.white.opacity(0.05))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.stelrBorder, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .tint(.stelrAccent)
    }
}
