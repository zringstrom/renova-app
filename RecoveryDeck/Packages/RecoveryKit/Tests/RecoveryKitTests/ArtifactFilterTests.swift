import Testing
@testable import RecoveryKit

@Suite("ArtifactFilter")
struct ArtifactFilterTests {
    @Test("drops RR below 300ms as a low outlier")
    func dropsLowOutlier() {
        let result = ArtifactFilter.filter([800, 250, 800])
        #expect(result.acceptedCount == 2)
        #expect(result.rejectedCount == 1)
        #expect(abs(result.artifactRatio - (1.0 / 3.0)) < 1e-9)
        #expect(result.segments == [[800], [800]])
    }

    @Test("drops RR above 2000ms as a high outlier")
    func dropsHighOutlier() {
        let result = ArtifactFilter.filter([800, 2500, 820])
        #expect(result.acceptedCount == 2)
        #expect(result.rejectedCount == 1)
        #expect(result.segments == [[800], [820]])
    }

    @Test("exactly 20% jump is accepted (pinned inclusive boundary)")
    func exactlyTwentyPercentIsAccepted() {
        // 960 is exactly 20% above 800.
        let result = ArtifactFilter.filter([800, 960])
        #expect(result.acceptedCount == 2)
        #expect(result.rejectedCount == 0)
        #expect(result.segments == [[800, 960]])
    }

    @Test("a jump over 20% is rejected and breaks the segment")
    func overTwentyPercentIsRejected() {
        // 1000 is 25% above 800.
        let result = ArtifactFilter.filter([800, 1000])
        #expect(result.acceptedCount == 1)
        #expect(result.rejectedCount == 1)
        #expect(result.segments == [[800]])
    }

    @Test("a rejected interval does not get diffed across by the next segment")
    func rejectionBreaksTheChain() {
        // 800 -> 250 (rejected, out of range) -> 800: the second 800 must start a
        // NEW segment, never diffed against the first 800 across the dropped beat.
        let result = ArtifactFilter.filter([800, 250, 800])
        #expect(result.segments.count == 2)
        #expect(result.segments.allSatisfy { $0.count == 1 })
    }

    @Test("empty input yields no segments")
    func emptyInput() {
        let result = ArtifactFilter.filter([])
        #expect(result.segments.isEmpty)
        #expect(result.acceptedCount == 0)
        #expect(result.rejectedCount == 0)
        #expect(result.artifactRatio == 0)
    }
}
