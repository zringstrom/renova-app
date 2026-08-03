import Foundation
import UserNotifications

enum ReminderScheduler {
    static let identifier = "renova.morning.checkin"

    static func sync() {
        let defaults = UserDefaults.standard
        let enabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? true
        let hour = defaults.object(forKey: "notificationHour") as? Int ?? 6
        let minute = defaults.object(forKey: "notificationMinute") as? Int ?? 30

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard enabled else { return }

        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

            let content = UNMutableNotificationContent()
            content.title = "Morning check-in"
            content.body = "Questionnaire first — then H10."
            content.sound = .default

            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(request)
        }
    }
}
