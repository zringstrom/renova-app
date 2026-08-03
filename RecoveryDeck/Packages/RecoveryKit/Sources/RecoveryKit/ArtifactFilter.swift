import Foundation

/// Result of running raw RR intervals through the artifact rules (TECH_SPEC §5.1).
///
/// `segments` are contiguous runs of *accepted* intervals. A rejected interval
/// breaks the current segment rather than being spliced out of it — otherwise
/// the sample on either side of a dropped artifact gets diffed across the gap,
/// which manufactures a large spurious difference and inflates rMSSD. rMSSD is
/// computed only from successive differences *within* a segment.
public struct ArtifactFilterResult: Sendable, Equatable {
    public let segments: [[Double]]
    public let acceptedCount: Int
    public let rejectedCount: Int

    public var artifactRatio: Double {
        let total = acceptedCount + rejectedCount
        guard total > 0 else { return 0 }
        return Double(rejectedCount) / Double(total)
    }
}

/// Artifact rejection rules (TECH_SPEC §5.1, normative):
/// 1. Drop RR < 300 ms or > 2000 ms.
/// 2. Drop RR whose successive difference from the previous *accepted* RR
///    exceeds 20% of that previous value (ectopic/motion heuristic). Exactly
///    20% is accepted, not rejected (pinned boundary — see ArtifactFilterTests).
public enum ArtifactFilter {
    private static let minValidMs = 300.0
    private static let maxValidMs = 2000.0
    private static let maxRelativeJump = 0.20

    public static func filter(_ rawRRMs: [Double]) -> ArtifactFilterResult {
        var segments: [[Double]] = []
        var current: [Double] = []
        var acceptedCount = 0
        var rejectedCount = 0
        var previousAccepted: Double?

        for rr in rawRRMs {
            let inRange = rr >= minValidMs && rr <= maxValidMs
            var isArtifact = !inRange
            if inRange, let previous = previousAccepted {
                let relativeJump = abs(rr - previous) / previous
                if relativeJump > maxRelativeJump {
                    isArtifact = true
                }
            }

            if isArtifact {
                rejectedCount += 1
                if !current.isEmpty {
                    segments.append(current)
                    current = []
                }
                continue
            }

            acceptedCount += 1
            current.append(rr)
            previousAccepted = rr
        }
        if !current.isEmpty { segments.append(current) }

        return ArtifactFilterResult(segments: segments, acceptedCount: acceptedCount, rejectedCount: rejectedCount)
    }
}
