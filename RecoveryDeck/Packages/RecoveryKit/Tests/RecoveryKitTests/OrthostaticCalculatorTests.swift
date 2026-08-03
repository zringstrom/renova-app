import Testing
@testable import RecoveryKit

@Suite("OrthostaticCalculator")
struct OrthostaticCalculatorTests {
    @Test("computes gaps from lying and standing BPM windows")
    func computesGaps() {
        let result = OrthostaticCalculator.result(
            lyingBpm: Array(repeating: 60.0, count: 30),
            standingBpm: [70, 80, 95, 90, 85]
        )
        #expect(result?.avgLyingHR == 60.0)
        #expect(result?.avgStandingHR == 84.0)
        #expect(result?.peakStandingHR == 95.0)
        #expect(result?.gapAvg == 24.0)
        #expect(result?.gapPeak == 35.0)
    }

    @Test("empty standing window yields nil")
    func emptyStandingYieldsNil() {
        let result = OrthostaticCalculator.result(lyingBpm: [60, 60], standingBpm: [])
        #expect(result == nil)
    }

    @Test("v3.1: accepts a precomputed avgLyingHR (from the merged rMSSD/lying window)")
    func acceptsPrecomputedLyingHR() {
        let result = OrthostaticCalculator.result(avgLyingHR: 52.0, standingBpm: [70, 80, 95, 90, 85])
        #expect(result?.avgLyingHR == 52.0)
        #expect(result?.peakStandingHR == 95.0)
        #expect(result?.gapPeak == 43.0)
    }
}
