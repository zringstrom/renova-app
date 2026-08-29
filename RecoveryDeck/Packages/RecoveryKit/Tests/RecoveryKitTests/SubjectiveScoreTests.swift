import Testing
@testable import RecoveryKit

@Suite("SubjectiveScore")
struct SubjectiveScoreTests {
    @Test("all-good day: mood/soreness/sleep at 7, fatigue/stress at 1 (least of the bad amount) -> high average")
    func allGoodDay() {
        let avg = SubjectiveScore.dailyAverage(
            fatigue: 1, mood: 7, soreness: 7, sleepQuality: 7, lifeStress: 1
        )
        // fatigue/stress flip to 8-1=7 each; all five values are 7.
        #expect(avg == 7.0)
    }

    @Test("polarity trap: fatigue=7 (worst) must LOWER the average, not raise it")
    func fatigueMaxLowersAverage() {
        let lowFatigue = SubjectiveScore.dailyAverage(
            fatigue: 1, mood: 4, soreness: 4, sleepQuality: 4, lifeStress: 4
        )
        let highFatigue = SubjectiveScore.dailyAverage(
            fatigue: 7, mood: 4, soreness: 4, sleepQuality: 4, lifeStress: 4
        )
        #expect(lowFatigue != nil && highFatigue != nil)
        #expect(highFatigue! < lowFatigue!)
    }

    @Test("polarity trap: lifeStress=7 (worst) must also lower the average")
    func stressMaxLowersAverage() {
        let lowStress = SubjectiveScore.dailyAverage(
            fatigue: 4, mood: 4, soreness: 4, sleepQuality: 4, lifeStress: 1
        )
        let highStress = SubjectiveScore.dailyAverage(
            fatigue: 4, mood: 4, soreness: 4, sleepQuality: 4, lifeStress: 7
        )
        #expect(lowStress != nil && highStress != nil)
        #expect(highStress! < lowStress!)
    }

    @Test("mood/soreness/sleepQuality are NOT flipped -- higher raises the average directly")
    func higherIsBetterFieldsNotFlipped() {
        let low = SubjectiveScore.dailyAverage(
            fatigue: 4, mood: 1, soreness: 1, sleepQuality: 1, lifeStress: 4
        )
        let high = SubjectiveScore.dailyAverage(
            fatigue: 4, mood: 7, soreness: 7, sleepQuality: 7, lifeStress: 4
        )
        #expect(low != nil && high != nil)
        #expect(high! > low!)
    }

    @Test("partial data: average over whatever's present")
    func partialData() {
        let avg = SubjectiveScore.dailyAverage(
            fatigue: nil, mood: 6, soreness: nil, sleepQuality: nil, lifeStress: nil
        )
        #expect(avg == 6.0)
    }

    @Test("no data at all -> nil")
    func noData() {
        let avg = SubjectiveScore.dailyAverage(
            fatigue: nil, mood: nil, soreness: nil, sleepQuality: nil, lifeStress: nil
        )
        #expect(avg == nil)
    }

    @Test("weeklyAverage averages non-nil daily averages, ignoring nils")
    func weeklyAverage() {
        let result = SubjectiveScore.weeklyAverage([4.0, 6.0, nil, 5.0])
        #expect(result != nil)
        #expect(abs(result! - 5.0) < 0.0001)
    }

    @Test("weeklyAverage of all-nil days -> nil")
    func weeklyAverageAllNil() {
        #expect(SubjectiveScore.weeklyAverage([nil, nil]) == nil)
    }
}
