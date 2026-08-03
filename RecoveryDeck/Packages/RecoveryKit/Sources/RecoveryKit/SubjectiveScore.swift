import Foundation

/// Converts one day's Block A subjective scores into a single 1...7
/// "higher is better" number. Powers the Weekly readout's subjective average
/// (plan Phase 10) — never part of a composite readiness score, just its own
/// standalone row.
///
/// **Polarity trap:** `fatigue`, `workStress`, `relationshipStress`, and
/// `overallLifeStress` are stored as "amount" scales (1 = little/good, 7 = a
/// lot/bad — see `DayRecord`'s doc comment in the app target). `mood`,
/// `soreness`, and `sleepQuality` are already "higher = better." Averaging
/// them together without flipping the four amount scales via `8 − x` first
/// would silently invert the whole readout (a terrible week of fatigue=7
/// would read as *good*). This type does the flip so callers never have to
/// remember to.
public enum SubjectiveScore {
    /// Any subset of the 7 fields may be present (a day's questionnaire may
    /// be incomplete); the average is over whatever is non-nil. `nil` if none
    /// are present at all.
    public static func dailyAverage(
        fatigue: Int?,
        mood: Int?,
        soreness: Int?,
        sleepQuality: Int?,
        workStress: Int?,
        relationshipStress: Int?,
        overallLifeStress: Int?
    ) -> Double? {
        var values: [Double] = []
        if let fatigue { values.append(8 - Double(fatigue)) }
        if let mood { values.append(Double(mood)) }
        if let soreness { values.append(Double(soreness)) }
        if let sleepQuality { values.append(Double(sleepQuality)) }
        if let workStress { values.append(8 - Double(workStress)) }
        if let relationshipStress { values.append(8 - Double(relationshipStress)) }
        if let overallLifeStress { values.append(8 - Double(overallLifeStress)) }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Mean of `dailyAverage` across whichever of `dailyAverages` are non-nil.
    /// `nil` if none of the days had any subjective data at all.
    public static func weeklyAverage(_ dailyAverages: [Double?]) -> Double? {
        let values = dailyAverages.compactMap { $0 }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
