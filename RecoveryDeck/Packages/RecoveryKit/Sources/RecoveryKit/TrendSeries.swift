import Foundation

/// One value on a trend chart, keyed to its calendar day.
public struct TrendPoint: Sendable, Equatable {
    public let localDate: String   // "yyyy-MM-dd"
    public let value: Double

    public init(localDate: String, value: Double) {
        self.localDate = localDate
        self.value = value
    }
}

/// A windowed run of `TrendPoint`s plus the personal-baseline band (mean/SD)
/// computed over all prior values, per `BaselineCalculator` (TECH_SPEC §5.4).
/// Powers both the Today sparkline (Phase 3) and the Trends charts (Phase 4).
public struct TrendSeries: Sendable, Equatable {
    public let points: [TrendPoint]      // oldest → newest, gaps simply absent
    public let normMean: Double?         // nil until >= BaselineCalculator.minimumPriorDays prior values
    public let normSD: Double?

    public init(points: [TrendPoint], normMean: Double?, normSD: Double?) {
        self.points = points
        self.normMean = normMean
        self.normSD = normSD
    }

    /// Per-point light using `BaselineCalculator.assess` against values strictly
    /// before that point (same semantics as `AppViewModel.analyze`) — i.e. this
    /// re-derives the assessment as of that historical day, not against the
    /// series-wide band above.
    public func light(at index: Int, sdFloor: Double) -> BaselineLight? {
        guard points.indices.contains(index) else { return nil }
        let priorValues = points[..<index].map(\.value)
        let status = BaselineCalculator.assess(today: points[index].value, priorValues: priorValues, sdFloor: sdFloor)
        switch status {
        case .building:
            return nil
        case .established(let assessment):
            return assessment.light
        }
    }
}

public enum TrendBuilder {
    /// - Parameters:
    ///   - values: `(localDate, value)` pairs, unordered ok.
    ///   - windowDays: how many trailing days to include in `points`.
    ///   - sdFloor: per-metric minimum SD (TECH_SPEC §5.4).
    /// - Returns: a `TrendSeries` whose `points` are the most recent `windowDays`
    ///   values (oldest → newest), and whose band (`normMean`/`normSD`) is
    ///   computed from ALL prior values relative to the newest point on file,
    ///   via `BaselineCalculator` (60-day window, same sdFloor rules) — i.e. the
    ///   band reflects "today" (the newest point), not the start of the window.
    public static func series(values: [(String, Double)], windowDays: Int, sdFloor: Double) -> TrendSeries {
        let sorted = values.sorted { $0.0 < $1.0 }
        guard !sorted.isEmpty else {
            return TrendSeries(points: [], normMean: nil, normSD: nil)
        }

        let points = sorted.suffix(windowDays).map { TrendPoint(localDate: $0.0, value: $0.1) }

        // Band is computed treating the newest overall value as "today" and
        // everything before it as prior — mirrors AppViewModel.analyze, which
        // assesses today's measurement against every earlier measured day.
        let latest = sorted.last!
        let priorValues = sorted.dropLast().map(\.1)
        let status = BaselineCalculator.assess(today: latest.1, priorValues: priorValues, sdFloor: sdFloor)

        switch status {
        case .building:
            return TrendSeries(points: points, normMean: nil, normSD: nil)
        case .established(let assessment):
            return TrendSeries(points: points, normMean: assessment.normMean, normSD: assessment.normSD)
        }
    }
}
