import Foundation
import RecoveryKit

enum HeartRateConnectionState: Sendable, Equatable {
    case idle
    case scanning
    case connecting(deviceName: String)
    case connected(deviceName: String, batteryPercent: Int?)
    case rrUnavailable
    case failed(HeartRateClientError)
    case disconnected
}

/// User-visible error codes from TECH_SPEC §13.
enum HeartRateClientError: Sendable, Equatable, Error {
    case bluetoothPoweredOff      // BT_POWER
    case bluetoothUnauthorized    // BT_DENIED
    case deviceNotFound           // H10_NOT_FOUND
    case noRRIntervals            // H10_NO_RR
    case connectionLost           // H10_DROP
}

/// Not actor-isolated on purpose: CoreBluetooth already serializes every
/// delegate callback onto a single queue (TECH_SPEC R3) — there's no real
/// concurrency here to model, and pinning this to `@MainActor` only fights
/// Swift 6's sender-analysis on the non-`Sendable` CoreBluetooth types
/// (`CBPeripheral`, `CBService`, ...) without adding any actual safety.
/// Conforming types are `@unchecked Sendable` by construction: single queue in,
/// plain `Sendable` values (`HRSample`, `HeartRateConnectionState`) out via
/// `AsyncStream`.
protocol HeartRateClientProtocol: AnyObject, Sendable {
    var connectionState: AsyncStream<HeartRateConnectionState> { get }
    var samples: AsyncStream<HRSample> { get }
    func connect()
    func disconnect()
}
