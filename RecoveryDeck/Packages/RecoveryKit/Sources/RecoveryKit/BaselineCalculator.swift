import Foundation

public enum BaselineLight: String, Sendable, Equatable {
    case green
    case yellow
    case red
}

public enum BaselineDirection: String, Sendable, Equatable {
    case aboveNormal
    case belowNormal
    case withinNormal
}

public struct BaselineAssessment: Sendable, Equatable {
    public let light: BaselineLight
    public let direction: BaselineDirection
    public let normMean: Double
    public let normSD: Double
    /// How many prior days actually went into `normMean`/`normSD` — capped at
    /// `normWindowDays`. Lets callers tell "a real comparison, still sharpening"
    /// (< normWindowDays) apart from "the fully-set 60-day baseline."
    public let priorDaysUsed: Int

    /// `true` once `priorDaysUsed` reaches `normWindowDays` — Couzens' full
    /// long-term norm window, not just the minimum needed to show a number at all.
    public var isFullyMature: Bool { priorDaysUsed >= BaselineCalculator.normWindowDays }
}

public enum BaselineStatus: Sendable, Equatable {
    case building(daysCollected: Int, daysNeeded: Int)
    case established(BaselineAssessment)
}

/// Couzens-aligned personal baseline (TECH_SPEC §5.4): acute value vs a 60-day
/// rolling mean, normal band = mean ± 1 SD.
///
/// Two thresholds, on purpose: real (if rough) feedback starts at
/// `minimumPriorDays` (7) so the app isn't silent for two months; the baseline
/// keeps sharpening from there and isn't "fully set" — Couzens' actual 60-day
/// long-term norm window — until `normWindowDays`. `BaselineAssessment.isFullyMature`
/// tells a caller which state it's in so the UI can say so honestly.
public enum BaselineCalculator {
    public static let minimumPriorDays = 7
    public static let normWindowDays = 60

    /// `priorValues` must exclude today. Only the most recent `normWindowDays`
    /// are used for the mean/SD. `sdFloor` is the per-metric minimum SD
    /// (TECH_SPEC §5.4: rMSSD 1ms, HR 1bpm, gap 1bpm, subjective 0.25) so a
    /// freakishly stable run of days doesn't manufacture a hair-trigger band.
    public static func assess(today: Double, priorValues: [Double], sdFloor: Double) -> BaselineStatus {
        guard priorValues.count >= minimumPriorDays else {
            return .building(daysCollected: priorValues.count, daysNeeded: minimumPriorDays)
        }

        let window = Array(priorValues.suffix(normWindowDays))
        let mean = window.reduce(0, +) / Double(window.count)
        let variance = window.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(window.count - 1)
        let sd = max(variance.squareRoot(), sdFloor)

        let deviation = abs(today - mean) / sd
        let light: BaselineLight = switch deviation {
        case ...1.0: .green
        case ...1.5: .yellow
        default: .red
        }

        let direction: BaselineDirection =
            today > mean + sd ? .aboveNormal :
            (today < mean - sd ? .belowNormal : .withinNormal)

        return .established(BaselineAssessment(light: light, direction: direction, normMean: mean, normSD: sd, priorDaysUsed: window.count))
    }
}
