import CoreBluetooth
import RecoveryKit
import Foundation

/// Real CoreBluetooth implementation (TECH_SPEC §4).
///
/// `CBCentralManager(delegate:queue: nil)` delivers every delegate callback on
/// the main queue, one at a time — CoreBluetooth itself is the serialization
/// point, not Swift's actor system. Deliberately not `@MainActor`: pinning this
/// class to an actor only makes Swift 6 try (and fail) to prove data-race
/// safety for the non-`Sendable` CoreBluetooth types passed into every delegate
/// callback (`CBPeripheral`, `CBService`, ...) — see TECH_SPEC R3. `@unchecked
/// Sendable` states the actual safety argument directly: single queue in,
/// plain `Sendable` values out via `AsyncStream`.
final class HeartRateClient: NSObject, HeartRateClientProtocol, @unchecked Sendable {
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var hrCharacteristic: CBCharacteristic?

    private var stateContinuation: AsyncStream<HeartRateConnectionState>.Continuation?
    private var sampleContinuation: AsyncStream<HRSample>.Continuation?

    let connectionState: AsyncStream<HeartRateConnectionState>
    let samples: AsyncStream<HRSample>

    private var wantsToConnect = false
    private var currentDeviceName = "HR strap"
    private var currentBatteryPercent: Int?
    /// Peripherals already ruled out this session (confirmed a watch via Body
    /// Sensor Location) — skipped if seen again while still scanning.
    private var rejectedPeripheralIDs: Set<UUID> = []

    override init() {
        var stateContinuation: AsyncStream<HeartRateConnectionState>.Continuation!
        let stateStream = AsyncStream<HeartRateConnectionState> { continuation in
            stateContinuation = continuation
        }
        var sampleContinuation: AsyncStream<HRSample>.Continuation!
        let sampleStream = AsyncStream<HRSample> { continuation in
            sampleContinuation = continuation
        }
        self.connectionState = stateStream
        self.samples = sampleStream
        super.init()
        self.stateContinuation = stateContinuation
        self.sampleContinuation = sampleContinuation
        self.central = CBCentralManager(delegate: self, queue: nil)
    }

    func connect() {
        wantsToConnect = true
        guard central.state == .poweredOn else {
            // centralManagerDidUpdateState resumes this once Bluetooth is on.
            return
        }
        startScanning()
    }

    func disconnect() {
        wantsToConnect = false
        central.stopScan()
        if let peripheral {
            central.cancelPeripheralConnection(peripheral)
        }
        peripheral = nil
        hrCharacteristic = nil
        stateContinuation?.yield(.disconnected)
    }

    private func startScanning() {
        stateContinuation?.yield(.scanning)
        // Prefer an already-bonded peripheral (TECH_SPEC §4.2: iPhone may
        // already be bonded to the strap from a prior session).
        let known = central.retrieveConnectedPeripherals(withServices: [HeartRateSensorIdentifiers.heartRateService])
        if let match = known.first(where: isLikelyChestStrap) {
            connectTo(match)
            return
        }
        central.scanForPeripherals(withServices: [HeartRateSensorIdentifiers.heartRateService], options: nil)
    }

    /// Pre-connect optimization only, not the real filter: the standard
    /// Bluetooth Heart Rate service (`0x180D`) isn't strap-exclusive — plenty
    /// of watches (a Coros Vertix, for one) advertise it too. This just skips
    /// obvious watches by name so we don't waste a connection attempt on one;
    /// the actual decision is Body Sensor Location, read after connecting
    /// (see `didUpdateValueFor` below), which works for any watch regardless
    /// of whether its name happens to be on this list — and accepts any
    /// compliant chest strap (Garmin, Wahoo, Suunto, ...) without needing to
    /// know its name at all.
    private func isLikelyChestStrap(_ peripheral: CBPeripheral) -> Bool {
        guard let name = peripheral.name else { return true }
        return !HeartRateSensorIdentifiers.knownWatchNameFragments.contains { name.localizedCaseInsensitiveContains($0) }
    }

    private func connectTo(_ peripheral: CBPeripheral) {
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        currentDeviceName = peripheral.name ?? "HR strap"
        stateContinuation?.yield(.connecting(deviceName: currentDeviceName))
        central.connect(peripheral, options: nil)
    }

    /// Body Sensor Location said "wrist" — this is a watch, not a chest
    /// strap. Disconnect quietly and keep scanning for the real thing rather
    /// than surfacing an error the user didn't cause.
    private func rejectAsWatch(_ peripheral: CBPeripheral) {
        rejectedPeripheralIDs.insert(peripheral.identifier)
        central.cancelPeripheralConnection(peripheral)
        self.peripheral = nil
        hrCharacteristic = nil
        guard wantsToConnect else { return }
        stateContinuation?.yield(.scanning)
        central.scanForPeripherals(withServices: [HeartRateSensorIdentifiers.heartRateService], options: nil)
    }
}

extension HeartRateClient: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if wantsToConnect { startScanning() }
        case .poweredOff:
            stateContinuation?.yield(.failed(.bluetoothPoweredOff))
        case .unauthorized:
            stateContinuation?.yield(.failed(.bluetoothUnauthorized))
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard !rejectedPeripheralIDs.contains(peripheral.identifier), isLikelyChestStrap(peripheral) else { return }
        connectTo(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([HeartRateSensorIdentifiers.heartRateService, HeartRateSensorIdentifiers.batteryService])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        stateContinuation?.yield(.failed(.deviceNotFound))
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.peripheral = nil
        hrCharacteristic = nil
        stateContinuation?.yield(wantsToConnect ? .failed(.connectionLost) : .disconnected)
    }
}

extension HeartRateClient: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            if service.uuid == HeartRateSensorIdentifiers.heartRateService {
                peripheral.discoverCharacteristics(
                    [HeartRateSensorIdentifiers.heartRateMeasurement, HeartRateSensorIdentifiers.bodySensorLocation],
                    for: service
                )
            } else if service.uuid == HeartRateSensorIdentifiers.batteryService {
                peripheral.discoverCharacteristics([HeartRateSensorIdentifiers.batteryLevel], for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == HeartRateSensorIdentifiers.heartRateMeasurement {
                hrCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                stateContinuation?.yield(.connected(deviceName: currentDeviceName, batteryPercent: currentBatteryPercent))
            } else if characteristic.uuid == HeartRateSensorIdentifiers.bodySensorLocation {
                peripheral.readValue(for: characteristic)
            } else if characteristic.uuid == HeartRateSensorIdentifiers.batteryLevel {
                peripheral.readValue(for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        let bytes = [UInt8](data)
        if characteristic.uuid == HeartRateSensorIdentifiers.heartRateMeasurement {
            guard let measurement = HRMeasurementParser.parse(bytes) else { return }
            sampleContinuation?.yield(
                HRSample(timestamp: Date(), bpm: measurement.bpm, rrIntervalsMs: measurement.rrIntervalsMs)
            )
        } else if characteristic.uuid == HeartRateSensorIdentifiers.bodySensorLocation {
            // The authoritative check (TECH_SPEC §4.1 update): if this device
            // explicitly reports it's worn on the wrist, it's a watch, not a
            // chest strap, regardless of what its name suggested.
            if let raw = bytes.first, HeartRateSensorIdentifiers.BodySensorLocation(rawValue: raw) == .wrist {
                rejectAsWatch(peripheral)
            }
        } else if characteristic.uuid == HeartRateSensorIdentifiers.batteryLevel, let level = bytes.first {
            currentBatteryPercent = Int(level)
            stateContinuation?.yield(.connected(deviceName: currentDeviceName, batteryPercent: currentBatteryPercent))
        }
    }
}
