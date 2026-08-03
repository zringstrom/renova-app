import Testing
@testable import RecoveryKit

@Suite("BaselineCalculator")
struct BaselineCalculatorTests {
    @Test("fewer than 7 prior days is building, not a light")
    func buildingBelowThreshold() {
        let prior = Array(repeating: 50.0, count: 6)
        let status = BaselineCalculator.assess(today: 50, priorValues: prior, sdFloor: 1)
        #expect(status == .building(daysCollected: 6, daysNeeded: 7))
    }

    @Test("exactly 7 prior days computes a real band, not building — but isn't fully mature yet")
    func establishedAtThreshold() {
        let prior = Array(repeating: 50.0, count: 7)
        let status = BaselineCalculator.assess(today: 50, priorValues: prior, sdFloor: 1)
        guard case .established(let assessment) = status else {
            Issue.record("expected established status")
            return
        }
        #expect(assessment.light == .green)
        #expect(assessment.priorDaysUsed == 7)
        #expect(assessment.isFullyMature == false)
    }

    @Test("60 prior days reaches Couzens' full long-term norm window — fully mature")
    func fullyMatureAtSixtyDays() {
        let prior = Array(repeating: 50.0, count: 60)
        let status = BaselineCalculator.assess(today: 50, priorValues: prior, sdFloor: 1)
        guard case .established(let assessment) = status else {
            Issue.record("expected established status")
            return
        }
        #expect(assessment.priorDaysUsed == 60)
        #expect(assessment.isFullyMature == true)
    }

    @Test("more than 60 prior days still only uses the most recent 60 for the window")
    func capsAtSixtyDaysEvenWithMoreHistory() {
        let prior = Array(repeating: 50.0, count: 90)
        let status = BaselineCalculator.assess(today: 50, priorValues: prior, sdFloor: 1)
        guard case .established(let assessment) = status else {
            Issue.record("expected established status")
            return
        }
        #expect(assessment.priorDaysUsed == 60)
        #expect(assessment.isFullyMature == true)
    }

    @Test("value at exactly mean+1SD is green (inclusive edge)")
    func edgeInclusiveIsGreen() {
        // mean 60, sd 5 (via values 55...65 spread), today exactly mean+1SD
        let prior = [55.0, 55, 55, 60, 60, 60, 60, 60, 60, 65, 65, 65, 65, 65]
        let mean = prior.reduce(0, +) / Double(prior.count)
        let variance = prior.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(prior.count - 1)
        let sd = variance.squareRoot()
        let status = BaselineCalculator.assess(today: mean + sd, priorValues: prior, sdFloor: 1)
        guard case .established(let assessment) = status else {
            Issue.record("expected established status")
            return
        }
        #expect(assessment.light == .green)
    }

    @Test("value clearly outside the band is red and flagged above-normal")
    func clearlyOutsideIsRed() {
        let prior = Array(repeating: 50.0, count: 20)
        // sd floors to 1 since all identical; today is 10 above mean -> 10 SD out.
        let status = BaselineCalculator.assess(today: 60, priorValues: prior, sdFloor: 1)
        guard case .established(let assessment) = status else {
            Issue.record("expected established status")
            return
        }
        #expect(assessment.light == .red)
        #expect(assessment.direction == .aboveNormal)
    }

    @Test("identical prior values floor SD to the metric minimum")
    func sdFloorsWhenPriorValuesAreIdentical() {
        let prior = Array(repeating: 50.0, count: 20)
        let status = BaselineCalculator.assess(today: 50.5, priorValues: prior, sdFloor: 1)
        guard case .established(let assessment) = status else {
            Issue.record("expected established status")
            return
        }
        #expect(assessment.normSD == 1.0)
        #expect(assessment.light == .green)
    }

    @Test("uses sample standard deviation (n-1), not population (n)")
    func usesSampleStandardDeviation() {
        let prior = Array(repeating: 50.0, count: 12) + [40.0, 60.0]
        let mean = prior.reduce(0, +) / Double(prior.count)
        let sumSquares = prior.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) }
        let sampleSD = (sumSquares / Double(prior.count - 1)).squareRoot()
        let populationSD = (sumSquares / Double(prior.count)).squareRoot()

        let status = BaselineCalculator.assess(today: mean, priorValues: prior, sdFloor: 0.001)
        guard case .established(let assessment) = status else {
            Issue.record("expected established status")
            return
        }
        #expect(abs(assessment.normSD - sampleSD) < 1e-9)
        #expect(abs(assessment.normSD - populationSD) > 1e-6)
    }
}
