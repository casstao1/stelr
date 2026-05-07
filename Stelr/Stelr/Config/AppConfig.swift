import Foundation

enum AppConfig {
    // ─── Supabase ────────────────────────────────────────────────────────────
    // Flip this off for pure local/mock builds without touching the Supabase code paths.
    static let supabaseEnabled = true

    // 1. Your project URL (already filled in from your dashboard)
    static let supabaseURL = URL(string: "https://vdtsdanotuewetigepbg.supabase.co")!

    // 2. Paste your anon/public key here (Settings → API Keys → Legacy → anon public)
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZkdHNkYW5vdHVld2V0aWdlcGJnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzczMTA1ODAsImV4cCI6MjA5Mjg4NjU4MH0.cMHDVjDoBCNcEIwsw7OV3gF7YepGZpW93E-Sgi01YrE"

    // ─── TVMaze (free, no auth needed) ───────────────────────────────────────
    static let tvmazeBaseURL = "https://api.tvmaze.com"

    // ─── AniList (public GraphQL API) ────────────────────────────────────────
    static let anilistGraphQLEndpoint = URL(string: "https://graphql.anilist.co")!
}
