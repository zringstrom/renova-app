import Foundation

/// One parsed Bluetooth Heart Rate Measurement notification (service `0x180D`,
/// characteristic `0x2A37`). Pure decode result — no BLE types leak into RecoveryKit.
public struct HRMeasurement: Sendable, Equatable {
    public let bpm: Double
    /// Zero or more RR intervals carried in this notification, in milliseconds.
    public let rrIntervalsMs: [Double]
    public let sensorContactSupported: Bool
    public let sensorContactDetected: Bool

    public init(bpm: Double, rrIntervalsMs: [Double], sensorContactSupported: Bool, sensorContactDetected: Bool) {
        self.bpm = bpm
        self.rrIntervalsMs = rrIntervalsMs
        self.sensorContactSupported = sensorContactSupported
        self.sensorContactDetected = sensorContactDetected
    }
}

/// One timestamped sample surfaced to session view models (TECH_SPEC §4.3).
public struct HRSample: Sendable, Equatable {
    public let timestamp: Date
    public let bpm: Double?
    public let rrIntervalsMs: [Double]

    public init(timestamp: Date, bpm: Double?, rrIntervalsMs: [Double]) {
        self.timestamp = timestamp
        self.bpm = bpm
        self.rrIntervalsMs = rrIntervalsMs
    }
}
