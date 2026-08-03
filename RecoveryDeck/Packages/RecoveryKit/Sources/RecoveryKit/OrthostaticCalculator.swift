import Foundation

/// Derived orthostatic values (TECH_SPEC §5.3). `gapPeak` is the primary UI
/// number (locked decision O3); `gapAvg` is shown secondary.
public struct OrthostaticResult: Sendable, Equatable {
    public let avgLyingHR: Double
    public let avgStandingHR: Double
    public let peakStandingHR: Double

    public var gapAvg: Double { avgStandingHR - avgLyingHR }
    public var gapPeak: Double { peakStandingHR - avgLyingHR }

    public init(avgLyingHR: Double, avgStandingHR: Double, peakStandingHR: Double) {
        self.avgLyingHR = avgLyingHR
        self.avgStandingHR = avgStandingHR
        self.peakStandingHR = peakStandingHR
    }
}

public enum OrthostaticCalculator {
    /// Mean of BPM samples in a phase window (TECH_SPEC §5.2).
    public static func meanHR(_ bpmSamples: [Double]) -> Double? {
        guard !bpmSamples.isEmpty else { return nil }
        return bpmSamples.reduce(0, +) / Double(bpmSamples.count)
    }

    /// Max BPM over the full standing window (TECH_SPEC §5.2 — includes the
    /// early rise, which is the Couzens peak response).
    public static func peakHR(_ bpmSamples: [Double]) -> Double? {
        bpmSamples.max()
    }

    public static func result(lyingBpm: [Double], standingBpm: [Double]) -> OrthostaticResult? {
        guard let lying = meanHR(lyingBpm),
              let standing = meanHR(standingBpm),
              let peak = peakHR(standingBpm) else { return nil }
        return OrthostaticResult(avgLyingHR: lying, avgStandingHR: standing, peakStandingHR: peak)
    }

    /// TECH_SPEC §5.1/§5.2 (v3.1 revised): `avgLyingHR` now comes from the same
    /// RR-derived mean HR used for rMSSD (`60000 / meanRR` over the merged
    /// Lying phase) rather than a separately-sampled BPM average — one window,
    /// one set of heartbeats, feeding both numbers.
    public static func result(avgLyingHR: Double, standingBpm: [Double]) -> OrthostaticResult? {
        guard let standing = meanHR(standingBpm),
              let peak = peakHR(standingBpm) else { return nil }
        return OrthostaticResult(avgLyingHR: avgLyingHR, avgStandingHR: standing, peakStandingHR: peak)
    }
}
