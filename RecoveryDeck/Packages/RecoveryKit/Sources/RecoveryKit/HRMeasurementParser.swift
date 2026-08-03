import Foundation

/// Decodes raw bytes from the Bluetooth Heart Rate Measurement characteristic
/// (service `0x180D`, characteristic `0x2A37`) per the Bluetooth SIG Heart Rate
/// Profile (TECH_SPEC §4.1).
///
/// Flags byte layout:
///   bit 0     Heart Rate Value Format (0 = UInt8, 1 = UInt16)
///   bit 1     Sensor Contact Detected (meaningful only if bit 2 is set)
///   bit 2     Sensor Contact Feature Supported
///   bit 3     Energy Expended present (2-byte UInt16 field to skip)
///   bit 4     One or more RR-Interval values present
///   bits 5-7  Reserved
///
/// RR intervals are transmitted in 1/1024 s units and converted to milliseconds:
/// `rr_ms = rr_raw * 1000 / 1024`.
public enum HRMeasurementParser {
    public static func parse(_ bytes: [UInt8]) -> HRMeasurement? {
        guard !bytes.isEmpty else { return nil }
        var index = 0
        let flags = bytes[index]; index += 1

        let isUInt16HR = (flags & 0x01) != 0
        let contactSupported = (flags & 0x04) != 0
        let contactDetected = (flags & 0x02) != 0
        let energyExpendedPresent = (flags & 0x08) != 0
        let rrPresent = (flags & 0x10) != 0

        let bpm: Double
        if isUInt16HR {
            guard index + 2 <= bytes.count else { return nil }
            let value = UInt16(bytes[index]) | (UInt16(bytes[index + 1]) << 8)
            bpm = Double(value)
            index += 2
        } else {
            guard index + 1 <= bytes.count else { return nil }
            bpm = Double(bytes[index])
            index += 1
        }

        if energyExpendedPresent {
            // Two-byte field we don't use, but MUST skip or every RR value
            // downstream is misaligned by 2 bytes.
            guard index + 2 <= bytes.count else {
                return HRMeasurement(bpm: bpm, rrIntervalsMs: [], sensorContactSupported: contactSupported, sensorContactDetected: contactDetected)
            }
            index += 2
        }

        var rrIntervalsMs: [Double] = []
        if rrPresent {
            // RR values come as consecutive UInt16 LE pairs. An odd trailing byte
            // (truncated notification) is ignored rather than crashing.
            while index + 2 <= bytes.count {
                let raw = UInt16(bytes[index]) | (UInt16(bytes[index + 1]) << 8)
                rrIntervalsMs.append(Double(raw) * 1000.0 / 1024.0)
                index += 2
            }
        }

        return HRMeasurement(
            bpm: bpm,
            rrIntervalsMs: rrIntervalsMs,
            sensorContactSupported: contactSupported,
            sensorContactDetected: contactDetected
        )
    }
}
