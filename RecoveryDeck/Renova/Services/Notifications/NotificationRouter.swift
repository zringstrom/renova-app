import Foundation
import UserNotifications

@MainActor
final class NotificationRouter: NSObject, ObservableObject {
    @Published var openQuestionnaireRequested = false
}

extension NotificationRouter: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let isReminder = response.notification.request.identifier == ReminderScheduler.identifier
        if isReminder {
            Task { @MainActor in self.openQuestionnaireRequested = true }
        }
        completionHandler()
    }
}
