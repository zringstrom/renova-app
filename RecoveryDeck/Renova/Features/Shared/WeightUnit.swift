import Foundation

/// User-selectable display unit for morning body weight logging. Storage is
/// always kilograms (`DayRecord.bodyWeightKg`) — this only governs what the
/// questionnaire/settings UI shows and accepts.
enum WeightUnit: String, CaseIterable {
    case kg
    case lbs

    private static let kgPerLb = 0.45359237

    var label: String {
        switch self {
        case .kg: "KG"
        case .lbs: "LBS"
        }
    }

    func fromKg(_ kg: Double) -> Double {
        switch self {
        case .kg: kg
        case .lbs: kg / Self.kgPerLb
        }
    }

    func toKg(_ value: Double) -> Double {
        switch self {
        case .kg: value
        case .lbs: value * Self.kgPerLb
        }
    }

    /// `lbs` in kg — used by the questionnaire's ±1 lb / ±0.5 lb weight
    /// stepper, which nudges by a fixed pound amount regardless of which
    /// unit the user has chosen to display.
    static func lbsToKg(_ lbs: Double) -> Double {
        lbs * kgPerLb
    }
}
