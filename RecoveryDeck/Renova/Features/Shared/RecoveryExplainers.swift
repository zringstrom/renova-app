import Foundation

/// Single source of truth for the "what the heck is X?" explainer copy —
/// shared by Onboarding, the live measurement session, Today, and Settings,
/// so all four always say the same thing.
enum RecoveryExplainerTopic: CaseIterable {
    case hrv
    case orthostatic

    var shortLabel: String {
        switch self {
        case .hrv: "HRV"
        case .orthostatic: "Orthostatic HR"
        }
    }

    var title: String {
        switch self {
        case .hrv: "WHAT THE HECK IS HRV?"
        case .orthostatic: "WHAT THE HECK IS ORTHOSTATIC HR?"
        }
    }

    var rows: [(String, String)] {
        switch self {
        case .hrv:
            [
                ("WHAT", "HRV (heart rate variability) is the tiny variation in time between each heartbeat. Not your heart rate itself, but how much it naturally speeds up and slows down beat to beat."),
                ("SO WHAT", "Higher HRV generally reflects a more recovered, less stressed nervous system. But it's not just \"lower is bad.\" A reading well outside your own normal range in either direction, unusually low OR unusually high, can signal fatigue, poor sleep, illness, or overreaching, often before you'd feel it any other way."),
                ("NOW WHAT", "You'll get a real comparison after just 7 days of morning measurements. Approximate at first, since it's an early estimate. It keeps sharpening every day until it's fully set at 60 days."),
            ]
        case .orthostatic:
            [
                ("WHAT", "It's how your heart rate reacts when you go from lying down to standing up. Specifically the gap between your resting heart rate and your peak heart rate right after you stand."),
                ("SO WHAT", "A smaller-than-usual gap can be an early sign of accumulated fatigue, dehydration, or under-recovery. Like HRV, this is an early signal you wouldn't notice from feel alone."),
                ("NOW WHAT", "You'll get a real comparison after just 7 days of morning readings. Approximate at first, but it keeps sharpening every day until it's fully set at 60 days."),
            ]
        }
    }
}
