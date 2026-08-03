import CoreBluetooth

/// Standard BLE SIG Heart Rate profile (TECH_SPEC §4.1) — not Polar-specific.
/// Garmin's HRM-Dual/Pro, Wahoo TICKR, Suunto's Smart Sensor, Movesense, and
/// most other serious chest straps all implement the same spec, so this app
/// isn't limited to one brand.
///
/// Computed rather than stored: `CBUUID` isn't `Sendable`, so a stored global
/// `let`/`static let` is flagged under Swift 6 strict concurrency as shared
/// mutable state. A computed property allocates a fresh, equal value per
/// access instead — no shared state to race on.
enum HeartRateSensorIdentifiers {
    static var heartRateService: CBUUID { CBUUID(string: "180D") }
    static var heartRateMeasurement: CBUUID { CBUUID(string: "2A37") }
    static var bodySensorLocation: CBUUID { CBUUID(string: "2A38") }
    static var batteryService: CBUUID { CBUUID(string: "180F") }
    static var batteryLevel: CBUUID { CBUUID(string: "2A19") }

    /// Body Sensor Location values per the BLE SIG spec (characteristic `0x2A38`).
    enum BodySensorLocation: UInt8 {
        case other = 0
        case chest = 1
        case wrist = 2
        case finger = 3
        case hand = 4
        case earLobe = 5
        case foot = 6
    }

    /// Known WATCH name fragments (case-insensitive) — the actual bug this
    /// list exists for: a Coros Vertix (and plenty of other watches) also
    /// advertise the standard Heart Rate service, so scanning by service UUID
    /// alone grabs whichever HR-capable device answers first. This is a
    /// pre-connect optimization only, not the real safeguard — that's
    /// `BodySensorLocation` below, read after connecting, which works for any
    /// watch regardless of whether its name is on this list.
    static let knownWatchNameFragments = [
        "watch", "vertix", "apex", "pace 3", "pace 2", // COROS
        "forerunner", "fenix", "venu", "vivoactive", "instinct", "epix", // Garmin watches
        "polar vantage", "polar grit", "polar ignite", "polar pacer", // Polar watches
        "suunto race", "suunto vertical", "suunto 9",
    ]
}
