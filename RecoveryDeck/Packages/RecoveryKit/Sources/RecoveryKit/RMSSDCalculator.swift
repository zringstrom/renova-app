import Foundation

public enum MeasurementQuality: String, Sendable, Equatable {
    case ok
    case fail
}

/// Result of a full rMSSD session computation (TECH_SPEC §5.1).
public struct RMSSDResult: Sendable, Equatable {
    public let rmssdMs: Double?
    public let meanRRMs: Double?
    public let meanHRBpm: Double?
    public let acceptedCount: Int
    public let rejectedCount: Int
    public let artifactRatio: Double
    public let quality: MeasurementQuality
}

/// Root mean square of successive differences of valid NN (RR) intervals
/// (TECH_SPEC §5.1). Quality fails, and rMSSD should be treated as unreliable,
/// when `artifactRatio > 0.20` or `acceptedCount < 45`.
public enum RMSSDCalculator {
    private static let minAcceptedCount = 45
    private static let maxArtifactRatio = 0.20

    public static func compute(rawRRMs: [Double]) -> RMSSDResult {
        let filtered = ArtifactFilter.filter(rawRRMs)
        let accepted = filtered.segments.flatMap { $0 }

        let meanRR: Double? = accepted.isEmpty ? nil : accepted.reduce(0, +) / Double(accepted.count)
        let meanHR = meanRR.map { 60_000.0 / $0 }

        var sumSquaredDiffs = 0.0
        var diffCount = 0
        for segment in filtered.segments where segment.count >= 2 {
            for i in 1..<segment.count {
                let diff = segment[i] - segment[i - 1]
                sumSquaredDiffs += diff * diff
                diffCount += 1
            }
        }
        let rmssd: Double? = diffCount > 0 ? (sumSquaredDiffs / Double(diffCount)).squareRoot() : nil

        let quality: MeasurementQuality =
            (filtered.artifactRatio > maxArtifactRatio || filtered.acceptedCount < minAcceptedCount)
            ? .fail : .ok

        return RMSSDResult(
            rmssdMs: rmssd,
            meanRRMs: meanRR,
            meanHRBpm: meanHR,
            acceptedCount: filtered.acceptedCount,
            rejectedCount: filtered.rejectedCount,
            artifactRatio: filtered.artifactRatio,
            quality: quality
        )
    }
}
