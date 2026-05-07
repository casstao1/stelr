import Foundation
import UserNotifications

final class SeasonReleaseNotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = SeasonReleaseNotificationManager()

    private let knownSeasonCountsKey = "stelr.knownSeasonCountsByShowID"

    private override init() {
        super.init()
    }

    func configure() {
        UNUserNotificationCenter.current().delegate = self
    }

    func checkForNewSeasons(
        refreshedShows: [Show],
        watchedShowIds: Set<Int>,
        previousSeasonCounts: [Int: Int]
    ) async {
        guard !watchedShowIds.isEmpty else { return }

        var knownSeasonCounts = loadKnownSeasonCounts()
        var notificationsToSchedule: [(show: Show, season: Int)] = []

        for show in refreshedShows where watchedShowIds.contains(show.id) {
            guard let refreshedSeasonCount = show.seasons, refreshedSeasonCount > 0 else { continue }

            let key = String(show.id)
            let persistedCount = knownSeasonCounts[key]
            let inMemoryCount = previousSeasonCounts[show.id]
            let baseline = max(persistedCount ?? 0, inMemoryCount ?? 0)

            if baseline == 0 {
                // First time seeing this show on this device: store the baseline
                // without alerting for seasons that already existed.
                knownSeasonCounts[key] = refreshedSeasonCount
                continue
            }

            if refreshedSeasonCount > baseline {
                notificationsToSchedule.append((show, refreshedSeasonCount))
            }

            if refreshedSeasonCount > (persistedCount ?? 0) {
                knownSeasonCounts[key] = refreshedSeasonCount
            }
        }

        saveKnownSeasonCounts(knownSeasonCounts)

        guard !notificationsToSchedule.isEmpty else { return }
        let isAuthorized = await requestAuthorizationIfNeeded()
        guard isAuthorized else { return }

        for notification in notificationsToSchedule {
            await scheduleNewSeasonNotification(show: notification.show, season: notification.season)
        }
    }

    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    private func scheduleNewSeasonNotification(show: Show, season: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "New season in orbit"
        content.body = "\(show.title) has Season \(season) available."
        content.sound = .default
        content.userInfo = [
            "showId": show.id,
            "season": season
        ]

        let request = UNNotificationRequest(
            identifier: "new-season-\(show.id)-\(season)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    private func loadKnownSeasonCounts() -> [String: Int] {
        guard
            let data = UserDefaults.standard.data(forKey: knownSeasonCountsKey),
            let decoded = try? JSONDecoder().decode([String: Int].self, from: data)
        else {
            return [:]
        }
        return decoded
    }

    private func saveKnownSeasonCounts(_ counts: [String: Int]) {
        guard let data = try? JSONEncoder().encode(counts) else { return }
        UserDefaults.standard.set(data, forKey: knownSeasonCountsKey)
    }
}
