import Foundation
import UserNotifications

/// Fires a push notification when a friend finishes a show, so the user knows
/// a shooting star is waiting for them the next time they open the constellation.
final class ShootingStarNotificationManager {
    static let shared = ShootingStarNotificationManager()
    private init() {}

    /// Schedules an immediate local notification for a friend-completion event.
    /// Silently no-ops when permission has not been granted.
    func scheduleNotification(for event: ShootingStarEvent) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
           || settings.authorizationStatus == .provisional
           || settings.authorizationStatus == .ephemeral
        else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(event.friend.name) finished S\(event.season)"
        content.body  = "\(event.show.title) · open Stelr to catch the shooting star"
        content.sound = .default
        content.userInfo = [
            "type"   : "shooting_star",
            "showId" : event.show.id,
            "season" : event.season,
        ]

        let request = UNNotificationRequest(
            identifier: "shooting-star-\(event.id.uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        try? await center.add(request)
    }
}
