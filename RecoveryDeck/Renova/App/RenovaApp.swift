import SwiftUI
import SwiftData

@main
struct RenovaApp: App {
    let container = AppContainer.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
