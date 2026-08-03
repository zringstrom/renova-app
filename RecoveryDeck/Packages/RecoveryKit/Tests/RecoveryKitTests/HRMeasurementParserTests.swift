import Testing
@testable import RecoveryKit

@Suite("HRMeasurementParser")
struct HRMeasurementParserTests {
    @Test("UInt8 HR, no RR")
    func uint8NoRR() {
        let result = HRMeasurementParser.parse([0x00, 0x3C])
        #expect(result?.bpm == 60)
        #expect(result?.rrIntervalsMs == [])
    }

    @Test("UInt16 HR, no RR")
    func uint16NoRR() {
        let result = HRMeasurementParser.parse([0x01, 0x3C, 0x00])
        #expect(result?.bpm == 60)
        #expect(result?.rrIntervalsMs == [])
    }

    @Test("UInt8 HR plus one RR interval")
    func uint8PlusOneRR() {
        // 0x0400 = 1024 (1/1024s units) -> 1000 ms
        let result = HRMeasurementParser.parse([0x10, 0x3C, 0x00, 0x04])
        #expect(result?.bpm == 60)
        #expect(result?.rrIntervalsMs == [1000.0])
    }

    @Test("UInt8 HR plus two RR intervals")
    func uint8PlusTwoRR() {
        // 0x0333 = 819 -> 799.8046875 ms ; 0x0340 = 832 -> 812.5 ms
        let result = HRMeasurementParser.parse([0x10, 0x3C, 0x33, 0x03, 0x40, 0x03])
        #expect(result?.bpm == 60)
        guard let rr = result?.rrIntervalsMs, rr.count == 2 else {
            Issue.record("expected two RR intervals")
            return
        }
        #expect(abs(rr[0] - 799.8046875) < 1e-9)
        #expect(abs(rr[1] - 812.5) < 1e-9)
    }

    @Test("energy expended field is skipped, not mistaken for RR data")
    func energyExpendedSkipped() {
        // flags 0x18 = energy-expended present (bit3) + RR present (bit4).
        // Energy bytes [0x64, 0x00] must be skipped so RR decodes as 1000 ms, not garbage.
        let result = HRMeasurementParser.parse([0x18, 0x3C, 0x64, 0x00, 0x00, 0x04])
        #expect(result?.bpm == 60)
        #expect(result?.rrIntervalsMs == [1000.0])
    }

    @Test("truncated trailing byte is ignored, not a crash")
    func truncatedTrailingByte() {
        let result = HRMeasurementParser.parse([0x10, 0x3C, 0x00])
        #expect(result?.bpm == 60)
        #expect(result?.rrIntervalsMs == [])
    }

    @Test("sensor contact flags decode correctly")
    func sensorContactFlags() {
        // bit2 (0x04) supported, bit1 (0x02) detected
        let result = HRMeasurementParser.parse([0x06, 0x3C])
        #expect(result?.sensorContactSupported == true)
        #expect(result?.sensorContactDetected == true)

        let notDetected = HRMeasurementParser.parse([0x04, 0x3C])
        #expect(notDetected?.sensorContactSupported == true)
        #expect(notDetected?.sensorContactDetected == false)
    }

    @Test("empty input returns nil")
    func emptyInput() {
        #expect(HRMeasurementParser.parse([]) == nil)
    }
}
