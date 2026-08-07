import WidgetKit
import SwiftUI
import RecoveryKit

struct RenovaEntry: TimelineEntry {
    let date: Date
    let tasksPending: Int
    let rmssdMs: Double?
    let light: String?
}

struct RenovaProvider: TimelineProvider {
    func placeholder(in context: Context) -> RenovaEntry {
        RenovaEntry(date: Date(), tasksPending: 2, rmssdMs: nil, light: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (RenovaEntry) -> Void) {
        completion(entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RenovaEntry>) -> Void) {
        let now = Date()
        let midnight = LocalDate.today(timeZone: .current)
            .adding(days: 1, timeZone: .current)
            .startOfDay(timeZone: .current)
        let entries = [
            entry(at: now),
            RenovaEntry(date: midnight, tasksPending: 2, rmssdMs: nil, light: nil)
        ]
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }

    /// A snapshot from an earlier day is treated as a fresh, untouched morning —
    /// that's what makes the widget flip back to "2 TASKS" at midnight.
    private func entry(at date: Date) -> RenovaEntry {
        let todayString = LocalDate.today(timeZone: .current).string
        guard let snapshot = WidgetSnapshotStore.read(), snapshot.localDate == todayString else {
            return RenovaEntry(date: date, tasksPending: 2, rmssdMs: nil, light: nil)
        }
        return RenovaEntry(
            date: date,
            tasksPending: snapshot.tasksPending,
            rmssdMs: snapshot.rmssdMs,
            light: snapshot.light
        )
    }
}

struct RenovaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RenovaWidget", provider: RenovaProvider()) { entry in
            RenovaWidgetView(entry: entry)
        }
        .configurationDisplayName("Renova")
        .description("Your morning ritual and today's rMSSD.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

@main
struct RenovaWidgetBundle: WidgetBundle {
    var body: some Widget {
        RenovaWidget()
    }
}
