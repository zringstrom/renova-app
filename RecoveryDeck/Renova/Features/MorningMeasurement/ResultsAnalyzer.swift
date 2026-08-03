import RecoveryKit

/// Turns raw `BaselineStatus` values into the plain-language, direction-labeled
/// copy PRD §6.6 requires ("RHR higher than your usual range", never just a
/// color) plus a single actionable tip in the spirit of §6.6's examples.
enum ResultsAnalyzer {
    struct Line {
        let label: String
        let text: String
        let light: BaselineLight?
        /// Set only while the baseline is real but not yet Couzens' full
        /// 60-day long-term norm window — e.g. "still improving — 23/60 days".
        let maturityNote: String?
    }

    struct Summary {
        let lines: [Line]
        let tip: String
    }

    static func analyze(rmssd: BaselineStatus?, rhr: BaselineStatus?, gapPeak: BaselineStatus?, soreness: Int?) -> Summary {
        let rmssdLine = line("rMSSD", rmssd)
        let rhrLine = line("RHR", rhr)
        let gapLine = line("Orthostatic gap", gapPeak)

        let tip: String
        if let soreness, soreness >= 6 {
            tip = "Heavy legs today. Respect muscular recovery even if HRV looks fine."
        } else if direction(rmssd) == .belowNormal && direction(rhr) == .aboveNormal {
            tip = "Low rMSSD and elevated RHR. Bias easy today; avoid intensity."
        } else if direction(rmssd) == .belowNormal && direction(gapPeak) == .belowNormal {
            tip = "Low rMSSD and a blunted stand response. Prefer easy work if unsure."
        } else if direction(rmssd) == .belowNormal {
            tip = "rMSSD lower than usual. Consider an easier day if you're unsure."
        } else if isBuilding(rmssd) {
            tip = "Not enough history yet for a comparison. After 7 days you'll get a real (if rough) baseline, which keeps sharpening until it's fully set at 60 days."
        } else {
            tip = "Signals look within your normal range."
        }

        return Summary(lines: [rmssdLine, rhrLine, gapLine], tip: tip)
    }

    private static func line(_ label: String, _ status: BaselineStatus?) -> Line {
        guard let status else {
            return Line(label: label, text: "No data", light: nil, maturityNote: nil)
        }
        switch status {
        case .building(let collected, let needed):
            let remaining = needed - collected
            return Line(label: label, text: "Building your baseline. \(remaining) more day\(remaining == 1 ? "" : "s") until you get a comparison", light: nil, maturityNote: nil)
        case .established(let assessment):
            let text: String
            switch assessment.direction {
            case .aboveNormal: text = "Higher than your usual range"
            case .belowNormal: text = "Lower than your usual range"
            case .withinNormal: text = "Within your usual range"
            }
            let maturityNote: String? = assessment.isFullyMature
                ? nil
                : "Baseline still improving. \(assessment.priorDaysUsed)/\(BaselineCalculator.normWindowDays) days"
            return Line(label: label, text: text, light: assessment.light, maturityNote: maturityNote)
        }
    }

    private static func direction(_ status: BaselineStatus?) -> BaselineDirection? {
        guard case .established(let assessment) = status else { return nil }
        return assessment.direction
    }

    private static func isBuilding(_ status: BaselineStatus?) -> Bool {
        guard let status else { return true }
        if case .building = status { return true }
        return false
    }
}
