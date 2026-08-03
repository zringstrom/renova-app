import SwiftUI
import SwiftData
import UserNotifications

@main
struct RenovaApp: App {
    let container = AppContainer.makeContainer()

    @StateObject private var notificationRouter: NotificationRouter
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let router = NotificationRouter()
        UNUserNotificationCenter.current().delegate = router
        _notificationRouter = StateObject(wrappedValue: router)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(notificationRouter)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { ReminderScheduler.sync() }
        }
    }
}
