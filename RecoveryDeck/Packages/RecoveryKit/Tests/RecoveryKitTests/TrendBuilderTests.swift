import Testing
@testable import RecoveryKit

@Suite("TrendBuilder")
struct TrendBuilderTests {
    @Test("empty input produces an empty series with no band")
    func emptyInput() {
        let series = TrendBuilder.series(values: [], windowDays: 14, sdFloor: 1)
        #expect(series.points.isEmpty)
        #expect(series.normMean == nil)
        #expect(series.normSD == nil)
    }

    @Test("fewer than 7 prior days -> nil band")
    func fewerThanMinimumPriorDaysIsNilBand() {
        // 6 prior days + 1 "today" = 7 total, only 6 prior -> building.
        let values: [(String, Double)] = (1...7).map { (String(format: "2026-01-%02d", $0), 50.0) }
        let series = TrendBuilder.series(values: values, windowDays: 14, sdFloor: 1)
        #expect(series.normMean == nil)
        #expect(series.normSD == nil)
        #expect(series.points.count == 7)
    }

    @Test("band matches BaselineCalculator.assess mean/SD for a known fixture")
    func bandMatchesDirectAssessCall() {
        let priorRaw: [Double] = [55, 55, 55, 60, 60, 60, 60, 60, 60, 65, 65, 65, 65, 65]
        let today = 62.0
        var values: [(String, Double)] = []
        for (index, value) in priorRaw.enumerated() {
            values.append((String(format: "2026-01-%02d", index + 1), value))
        }
        values.append((String(format: "2026-01-%02d", priorRaw.count + 1), today))

        let series = TrendBuilder.series(values: values, windowDays: 30, sdFloor: 1)

        let direct = BaselineCalculator.assess(today: today, priorValues: priorRaw, sdFloor: 1)
        guard case .established(let assessment) = direct else {
            Issue.record("expected established status")
            return
        }
        #expect(series.normMean == assessment.normMean)
        #expect(series.normSD == assessment.normSD)
    }

    @Test("windowDays trims points to the most recent N, oldest to newest")
    func windowTrimming() {
        let values: [(String, Double)] = (1...20).map { (String(format: "2026-01-%02d", $0), Double($0)) }
        let series = TrendBuilder.series(values: values, windowDays: 5, sdFloor: 1)
        #expect(series.points.count == 5)
        #expect(series.points.map(\.localDate) == [
            "2026-01-16", "2026-01-17", "2026-01-18", "2026-01-19", "2026-01-20",
        ])
        #expect(series.points.first?.value == 16)
        #expect(series.points.last?.value == 20)
    }

    @Test("unordered input is sorted before windowing and banding")
    func unorderedInputIsSorted() {
        let ordered: [(String, Double)] = (1...10).map { (String(format: "2026-01-%02d", $0), Double($0) * 10) }
        let shuffled = ordered.shuffled()
        let series = TrendBuilder.series(values: shuffled, windowDays: 10, sdFloor: 1)
        #expect(series.points.map(\.localDate) == ordered.map(\.0))
    }

    @Test("per-point lights match direct assess calls against strictly-prior points")
    func perPointLightsMatchDirectAssess() {
        let priorRaw: [Double] = [55, 55, 55, 60, 60, 60, 60, 60, 60, 65, 65, 65, 65, 65]
        var values: [(String, Double)] = []
        for (index, value) in priorRaw.enumerated() {
            values.append((String(format: "2026-01-%02d", index + 1), value))
        }
        // One more day, clearly out of band.
        values.append(("2026-01-20", 90.0))

        let series = TrendBuilder.series(values: values, windowDays: 30, sdFloor: 1)

        for index in series.points.indices {
            let priorValues = series.points[..<index].map(\.value)
            let expectedStatus = BaselineCalculator.assess(today: series.points[index].value, priorValues: priorValues, sdFloor: 1)
            let expectedLight: BaselineLight?
            switch expectedStatus {
            case .building:
                expectedLight = nil
            case .established(let assessment):
                expectedLight = assessment.light
            }
            #expect(series.light(at: index, sdFloor: 1) == expectedLight)
        }

        // Sanity: the last point (90, wildly above a tight band) should be red.
        #expect(series.light(at: series.points.count - 1, sdFloor: 1) == .red)
    }

    @Test("light(at:) out of range returns nil")
    func lightOutOfRangeIsNil() {
        let series = TrendBuilder.series(values: [], windowDays: 14, sdFloor: 1)
        #expect(series.light(at: 0, sdFloor: 1) == nil)
        #expect(series.light(at: -1, sdFloor: 1) == nil)
    }
}
