import Foundation

/// Group-mean effect of one habit chip (e.g. "did I drink last night") on the
/// next morning's rMSSD/RHR. Deliberately not a correlation coefficient or a
/// p-value — group averages only, exactly as pitched to the user ("Correlation,
/// not causation."). PRD/plan Phase 8.
public struct ChipEffect: Sendable, Equatable {
    /// Stable key, e.g. "alcohol" — not the display name shown in UI.
    public let chip: String
    /// Days with the chip set true and an rMSSD value (the group the effect is measured on).
    public let nWith: Int
    /// Days with the chip set false and an rMSSD value.
    public let nWithout: Int
    /// (meanWith − meanWithout) / meanWithout, as a percentage. `nil` if
    /// `meanWithout` is zero (division-by-zero guard) — the chip is then
    /// excluded from `effects(from:)` since there's nothing honest to show.
    public let rmssdPctDelta: Double?
    /// Absolute bpm difference (meanWith − meanWithout). `nil` if either RHR
    /// group has fewer than `minGroupSize` days with an RHR value — the rMSSD
    /// half of the row can still be honest even when RHR can't be shown.
    public let rhrBpmDelta: Double?

    public init(chip: String, nWith: Int, nWithout: Int, rmssdPctDelta: Double?, rhrBpmDelta: Double?) {
        self.chip = chip
        self.nWith = nWith
        self.nWithout = nWithout
        self.rmssdPctDelta = rmssdPctDelta
        self.rhrBpmDelta = rhrBpmDelta
    }
}

/// One day's habit-chip values plus that morning's rMSSD/RHR — the input
/// `CorrelationEngine.effects(from:)` chews on. All optional: a day may be
/// partial (no measurement) or may never have had a given chip answered.
public struct ChipDayInputs: Sendable, Equatable {
    public let habitAlcohol: Bool?
    public let habitIntenseTraining: Bool?
    public let habitLongTraining: Bool?
    public let habitTravel: Bool?
    public let habitLateNight: Bool?
    public let habitSick: Bool?
    public let habitBreathwork: Bool?
    public let rmssd: Double?
    public let rhr: Double?

    public init(
        habitAlcohol: Bool?,
        habitIntenseTraining: Bool?,
        habitLongTraining: Bool?,
        habitTravel: Bool?,
        habitLateNight: Bool?,
        habitSick: Bool?,
        habitBreathwork: Bool?,
        rmssd: Double?,
        rhr: Double?
    ) {
        self.habitAlcohol = habitAlcohol
        self.habitIntenseTraining = habitIntenseTraining
        self.habitLongTraining = habitLongTraining
        self.habitTravel = habitTravel
        self.habitLateNight = habitLateNight
        self.habitSick = habitSick
        self.habitBreathwork = habitBreathwork
        self.rmssd = rmssd
        self.rhr = rhr
    }
}

/// Pure group-mean comparison — no p-values, no ML. TECH_SPEC/plan Phase 8.
public enum CorrelationEngine {
    /// Both the "with" and "without" groups need at least this many days with
    /// an rMSSD value before an effect is reported at all (a "sample of 3"
    /// would be dishonest, not just noisy).
    public static let minGroupSize = 5

    /// Chip keys in display order, with their human-facing chip names
    /// (plan §8.2). `chip` on `ChipEffect` is always one of these keys.
    public static let chipDisplayNames: [(key: String, name: String)] = [
        ("alcohol", "ALCOHOL NIGHTS"),
        ("intenseTraining", "INTENSE TRAINING"),
        ("longTraining", "LONG TRAINING"),
        ("travel", "TRAVEL DAYS"),
        ("lateNight", "LATE NIGHTS"),
        ("sick", "SICK DAYS"),
        ("breathwork", "BREATHWORK DAYS"),
    ]

    public static func displayName(for chip: String) -> String {
        chipDisplayNames.first { $0.key == chip }?.name ?? chip.uppercased()
    }

    /// - Parameter days: one entry per day: `(chipValue, rmssd, rhr)`. `nil`
    ///   chip values (never answered) are excluded from both groups entirely —
    ///   they're neither "with" nor "without."
    /// - Returns: `nil` unless both the with-chip and without-chip groups have
    ///   at least `minGroupSize` days with an rMSSD value.
    public static func effect(chip: String, days: [(Bool?, Double?, Double?)]) -> ChipEffect? {
        let withGroup = days.filter { $0.0 == true }
        let withoutGroup = days.filter { $0.0 == false }

        let rmssdWith = withGroup.compactMap(\.1)
        let rmssdWithout = withoutGroup.compactMap(\.1)

        guard rmssdWith.count >= minGroupSize, rmssdWithout.count >= minGroupSize else {
            return nil
        }

        let meanWith = rmssdWith.reduce(0, +) / Double(rmssdWith.count)
        let meanWithout = rmssdWithout.reduce(0, +) / Double(rmssdWithout.count)

        let rmssdPctDelta: Double?
        if meanWithout != 0 {
            rmssdPctDelta = (meanWith - meanWithout) / meanWithout * 100
        } else {
            rmssdPctDelta = nil
        }

        let rhrWith = withGroup.compactMap(\.2)
        let rhrWithout = withoutGroup.compactMap(\.2)
        let rhrBpmDelta: Double?
        if rhrWith.count >= minGroupSize, rhrWithout.count >= minGroupSize {
            let rhrMeanWith = rhrWith.reduce(0, +) / Double(rhrWith.count)
            let rhrMeanWithout = rhrWithout.reduce(0, +) / Double(rhrWithout.count)
            rhrBpmDelta = rhrMeanWith - rhrMeanWithout
        } else {
            rhrBpmDelta = nil
        }

        return ChipEffect(
            chip: chip,
            nWith: rmssdWith.count,
            nWithout: rmssdWithout.count,
            rmssdPctDelta: rmssdPctDelta,
            rhrBpmDelta: rhrBpmDelta
        )
    }

    /// All seven chips, sorted by `|rmssdPctDelta|` descending. Chips that
    /// don't clear `minGroupSize`, or whose `rmssdPctDelta` is `nil` (the
    /// division-by-zero guard), are filtered out entirely — there is nothing
    /// honest to show for them.
    public static func effects(from days: [ChipDayInputs]) -> [ChipEffect] {
        chipDisplayNames.compactMap { key, _ in
            let rows: [(Bool?, Double?, Double?)] = days.map { day in
                let value: Bool?
                switch key {
                case "alcohol": value = day.habitAlcohol
                case "intenseTraining": value = day.habitIntenseTraining
                case "longTraining": value = day.habitLongTraining
                case "travel": value = day.habitTravel
                case "lateNight": value = day.habitLateNight
                case "sick": value = day.habitSick
                case "breathwork": value = day.habitBreathwork
                default: value = nil
                }
                return (value, day.rmssd, day.rhr)
            }
            guard let result = effect(chip: key, days: rows), result.rmssdPctDelta != nil else { return nil }
            return result
        }
        .sorted { abs($0.rmssdPctDelta ?? 0) > abs($1.rmssdPctDelta ?? 0) }
    }
}
