import Testing
@testable import RecoveryKit

@Suite("RMSSDCalculator")
struct RMSSDCalculatorTests {
    @Test("empty RR list yields nil rMSSD and nil means")
    func emptyYieldsNil() {
        let result = RMSSDCalculator.compute(rawRRMs: [])
        #expect(result.rmssdMs == nil)
        #expect(result.meanRRMs == nil)
        #expect(result.meanHRBpm == nil)
    }

    @Test("a single RR interval yields nil rMSSD (needs at least two)")
    func singleYieldsNil() {
        let result = RMSSDCalculator.compute(rawRRMs: [800])
        #expect(result.rmssdMs == nil)
        #expect(result.meanRRMs == 800)
    }

    @Test("flat RR series yields rMSSD of exactly zero")
    func flatYieldsExactZero() {
        let result = RMSSDCalculator.compute(rawRRMs: [1000, 1000, 1000, 1000])
        #expect(result.rmssdMs == 0.0)
    }

    @Test("alternating RR series yields exact rMSSD of 50")
    func alternatingYieldsExact50() {
        let result = RMSSDCalculator.compute(rawRRMs: [800, 850, 800, 850])
        #expect(result.rmssdMs == 50.0)
    }

    @Test("irregular RR series matches hand-calculated rMSSD")
    func irregularMatchesHandCalculation() {
        let result = RMSSDCalculator.compute(rawRRMs: [800, 810, 815, 805])
        #expect(abs((result.rmssdMs ?? 0) - 8.660254) < 1e-5)
    }

    @Test("monotonic ramp yields exact rMSSD of 10")
    func monotonicRampYieldsExact10() {
        let result = RMSSDCalculator.compute(rawRRMs: [800, 810, 820, 830])
        #expect(result.rmssdMs == 10.0)
    }

    @Test("mean HR is derived correctly from mean RR")
    func meanHRSanity() {
        let result = RMSSDCalculator.compute(rawRRMs: Array(repeating: 1000.0, count: 5))
        #expect(result.meanHRBpm == 60.0)
    }

    @Test("a rejected artifact does not get diffed across, so it can't inflate rMSSD")
    func rejectedArtifactDoesNotInflateRMSSD() {
        // Without segmentation, diffing 800 -> (dropped) -> 800 across the gap
        // would still read as zero here, so use a case where the artifact's
        // neighbors actually differ to prove the segment break matters.
        let withArtifact = RMSSDCalculator.compute(rawRRMs: [800, 810, 3000, 820, 830])
        let withoutArtifact = RMSSDCalculator.compute(rawRRMs: [800, 810, 820, 830])
        #expect(withArtifact.rmssdMs == withoutArtifact.rmssdMs)
    }

    @Test("quality fails when accepted count is below the 45 floor")
    func qualityFailsBelowCountFloor() {
        let rr = Array(repeating: 800.0, count: 44)
        let result = RMSSDCalculator.compute(rawRRMs: rr)
        #expect(result.acceptedCount == 44)
        #expect(result.quality == .fail)
    }

    @Test("quality passes at exactly the 45 accepted floor with zero artifacts")
    func qualityPassesAtFloor() {
        let rr = Array(repeating: 800.0, count: 45)
        let result = RMSSDCalculator.compute(rawRRMs: rr)
        #expect(result.acceptedCount == 45)
        #expect(result.quality == .ok)
    }

    @Test("quality fails when artifact ratio exceeds 20% even with enough accepted beats")
    func qualityFailsAboveRatioFloor() {
        var rr = Array(repeating: 800.0, count: 45)
        rr.append(contentsOf: Array(repeating: 100.0, count: 12)) // out-of-range -> rejected
        let result = RMSSDCalculator.compute(rawRRMs: rr)
        #expect(result.acceptedCount == 45)
        #expect(result.rejectedCount == 12)
        #expect(result.artifactRatio > 0.20)
        #expect(result.quality == .fail)
    }
}
