import SwiftData
import Foundation

enum AppContainer {
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([DayRecord.self, MeasurementRecord.self, AnalyticsEvent.self])
        // Explicit, bundle-ID-namespaced store URL — SwiftData's default
        // "default.store" filename doesn't vary per target, so Renova and
        // RenovaDev (same App Group, same device) were silently sharing one
        // store. Namespacing by bundle identifier guarantees isolation
        // regardless of how the default path resolves.
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            let bundleID = Bundle.main.bundleIdentifier ?? "com.zringstrom.recoverydeck"
            try? FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
            let storeURL = URL.applicationSupportDirectory.appending(path: "\(bundleID).store")
            configuration = ModelConfiguration(schema: schema, url: storeURL)
        }
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
