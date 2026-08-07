import Foundation

/// The only state the app shares with the widget, through the App Group
/// container. Deliberately plain types so the widget target needs nothing
/// but Foundation to read it.
struct WidgetSnapshot: Codable {
    let localDate: String
    let tasksPending: Int
    let rmssdMs: Double?
    let light: String?
}

enum WidgetSnapshotStore {
    static let appGroupID = "group.com.zringstrom.recoverydeck"
    private static let key = "widgetSnapshot"

    static func write(_ snapshot: WidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    static func read() -> WidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
