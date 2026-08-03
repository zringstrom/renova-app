import Testing
@testable import RecoveryKit

@Suite("CorrelationEngine")
struct CorrelationEngineTests {
    @Test("n=4 in either group -> nil (below threshold)")
    func belowThresholdIsNil() {
        // 4 "with" days, 6 "without" days -> nil (with group too small).
        var days: [(Bool?, Double?, Double?)] = []
        days += Array(repeating: (true, 50.0, 50.0), count: 4)
        days += Array(repeating: (false, 60.0, 50.0), count: 6)
        #expect(CorrelationEngine.effect(chip: "alcohol", days: days) == nil)
    }

    @Test("n=5 in both groups -> effect reported")
    func atThresholdReportsEffect() {
        var days: [(Bool?, Double?, Double?)] = []
        days += Array(repeating: (true, 50.0, 50.0), count: 5)
        days += Array(repeating: (false, 60.0, 50.0), count: 5)
        let effect = CorrelationEngine.effect(chip: "alcohol", days: days)
        #expect(effect != nil)
        #expect(effect?.nWith == 5)
        #expect(effect?.nWithout == 5)
    }

    @Test("nil chip values are excluded from both groups")
    func nilChipsExcluded() {
        var days: [(Bool?, Double?, Double?)] = []
        days += Array(repeating: (true, 50.0, 50.0), count: 5)
        days += Array(repeating: (false, 60.0, 50.0), count: 5)
        // 20 days where the chip was never answered -- must not count toward
        // either group, and must not affect the computed means.
        days += Array(repeating: (nil, 999.0, 999.0), count: 20)

        let effect = CorrelationEngine.effect(chip: "alcohol", days: days)
        #expect(effect?.nWith == 5)
        #expect(effect?.nWithout == 5)
        // (50 - 60) / 60 * 100
        #expect(effect?.rmssdPctDelta != nil)
        if let delta = effect?.rmssdPctDelta {
            #expect(abs(delta - (-16.666666666666668)) < 0.0001)
        }
    }

    @Test("sign correctness: alcohol nights with lower rMSSD produce a negative delta")
    func signCorrectness() {
        var days: [(Bool?, Double?, Double?)] = []
        // Alcohol nights: rMSSD 51 (lower).
        days += Array(repeating: (true, 51.0, 50.0), count: 6)
        // Non-alcohol nights: rMSSD 60 (higher).
        days += Array(repeating: (false, 60.0, 47.0), count: 6)

        let effect = CorrelationEngine.effect(chip: "alcohol", days: days)
        #expect(effect != nil)
        #expect((effect?.rmssdPctDelta ?? 0) < 0)
        // RHR is higher on alcohol nights -> positive delta.
        #expect((effect?.rhrBpmDelta ?? 0) > 0)
    }

    @Test("division-by-zero guard: meanWithout == 0 -> nil rmssdPctDelta")
    func divisionByZeroGuard() {
        var days: [(Bool?, Double?, Double?)] = []
        days += Array(repeating: (true, 50.0, 50.0), count: 5)
        days += Array(repeating: (false, 0.0, 50.0), count: 5)
        let effect = CorrelationEngine.effect(chip: "alcohol", days: days)
        #expect(effect != nil)
        #expect(effect?.rmssdPctDelta == nil)
    }

    @Test("rhrBpmDelta is nil when RHR groups don't clear minGroupSize even if rMSSD does")
    func rhrDeltaRequiresOwnThreshold() {
        var days: [(Bool?, Double?, Double?)] = []
        // 5 with-chip days, all with rMSSD but only 3 with RHR.
        days.append((true, 50.0, 50.0))
        days.append((true, 50.0, 50.0))
        days.append((true, 50.0, 50.0))
        days.append((true, 50.0, nil))
        days.append((true, 50.0, nil))
        days += Array(repeating: (false, 60.0, 47.0), count: 5)

        let effect = CorrelationEngine.effect(chip: "alcohol", days: days)
        #expect(effect != nil)
        #expect(effect?.rmssdPctDelta != nil)
        #expect(effect?.rhrBpmDelta == nil)
    }

    @Test("effects(from:) filters below-threshold chips and sorts by |rmssdPctDelta| descending")
    func effectsFromSortsAndFilters() {
        var rows: [ChipDayInputs] = []

        // Alcohol: big negative effect, clears threshold both sides.
        for _ in 0..<6 {
            rows.append(ChipDayInputs(
                habitAlcohol: true, habitIntenseTraining: nil, habitLongTraining: nil,
                habitTravel: nil, habitLateNight: nil, habitSick: nil, habitBreathwork: nil,
                rmssd: 45, rhr: 52
            ))
        }
        for _ in 0..<6 {
            rows.append(ChipDayInputs(
                habitAlcohol: false, habitIntenseTraining: nil, habitLongTraining: nil,
                habitTravel: nil, habitLateNight: nil, habitSick: nil, habitBreathwork: nil,
                rmssd: 60, rhr: 47
            ))
        }
        // Travel: small effect, clears threshold both sides too.
        for _ in 0..<6 {
            rows.append(ChipDayInputs(
                habitAlcohol: nil, habitIntenseTraining: nil, habitLongTraining: nil,
                habitTravel: true, habitLateNight: nil, habitSick: nil, habitBreathwork: nil,
                rmssd: 58, rhr: 48
            ))
        }
        for _ in 0..<6 {
            rows.append(ChipDayInputs(
                habitAlcohol: nil, habitIntenseTraining: nil, habitLongTraining: nil,
                habitTravel: false, habitLateNight: nil, habitSick: nil, habitBreathwork: nil,
                rmssd: 59, rhr: 48
            ))
        }
        // Sick: only 3 sick days -- below threshold, must be excluded.
        for _ in 0..<3 {
            rows.append(ChipDayInputs(
                habitAlcohol: nil, habitIntenseTraining: nil, habitLongTraining: nil,
                habitTravel: nil, habitLateNight: nil, habitSick: true, habitBreathwork: nil,
                rmssd: 40, rhr: 55
            ))
        }
        for _ in 0..<6 {
            rows.append(ChipDayInputs(
                habitAlcohol: nil, habitIntenseTraining: nil, habitLongTraining: nil,
                habitTravel: nil, habitLateNight: nil, habitSick: false, habitBreathwork: nil,
                rmssd: 59, rhr: 48
            ))
        }

        let effects = CorrelationEngine.effects(from: rows)
        #expect(effects.map(\.chip) == ["alcohol", "travel"])
        #expect(effects.first?.chip == "alcohol")
    }

    @Test("displayName maps stable keys to the plan's chip names")
    func displayNames() {
        #expect(CorrelationEngine.displayName(for: "alcohol") == "ALCOHOL NIGHTS")
        #expect(CorrelationEngine.displayName(for: "breathwork") == "BREATHWORK DAYS")
    }
}
