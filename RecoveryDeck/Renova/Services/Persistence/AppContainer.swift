import SwiftData

enum AppContainer {
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([DayRecord.self, MeasurementRecord.self, AnalyticsEvent.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
