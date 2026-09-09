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

    /// (large, small) quick-adjust step sizes for the questionnaire's weight
    /// stepper buttons, native to this unit — 1 lb / 0.5 lb on a lbs display,
    /// 0.5 kg / 0.2 kg on a kg display (roughly the same felt granularity;
    /// 1 kg ≈ 2.2 lb would be a much bigger jump than the lbs pair).
    var stepSizes: (large: Double, small: Double) {
        switch self {
        case .lbs: (1.0, 0.5)
        case .kg: (0.5, 0.2)
        }
    }
}
