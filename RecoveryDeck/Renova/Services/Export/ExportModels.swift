import Foundation

/// Flat, human-readable export shape — deliberately not a 1:1 dump of the
/// SwiftData schema, so it stays stable even if the on-device model changes.
struct ExportDay: Codable {
    let localDate: String
    let fatigue: Int?
    let mood: Int?
    let soreness: Int?
    let sleepQuality: Int?
    let lifeStress: Int?
    let bodyWeightKg: Double?
    let lastCaffeineAt: Date?
    let caffeineAmountMg: Double?
    let lastMealAt: Date?
    let habitAlcohol: Bool?
    let habitIntenseTrainingYesterday: Bool?
    let habitLongTrainingYesterday: Bool?
    let habitTravel: Bool?
    let habitLateNight: Bool?
    let habitSick: Bool?
    let habitMeditationYesterday: Bool?
    let notes: String?
    let measurement: ExportMeasurement?

    private enum CodingKeys: String, CodingKey {
        case localDate, fatigue, mood, soreness, sleepQuality, lifeStress
        case legacyOverallLifeStress = "overallLifeStress"
        case legacyWorkStress = "workStress"
        case bodyWeightKg, lastCaffeineAt, caffeineAmountMg, lastMealAt
        case habitAlcohol, habitIntenseTrainingYesterday, habitLongTrainingYesterday
        case habitTravel, habitLateNight, habitSick, habitMeditationYesterday
        case notes, measurement
    }

    init(
        localDate: String, fatigue: Int?, mood: Int?, soreness: Int?, sleepQuality: Int?, lifeStress: Int?,
        bodyWeightKg: Double?, lastCaffeineAt: Date?, caffeineAmountMg: Double?, lastMealAt: Date?,
        habitAlcohol: Bool?, habitIntenseTrainingYesterday: Bool?, habitLongTrainingYesterday: Bool?,
        habitTravel: Bool?, habitLateNight: Bool?, habitSick: Bool?, habitMeditationYesterday: Bool?,
        notes: String?, measurement: ExportMeasurement?
    ) {
        self.localDate = localDate
        self.fatigue = fatigue
        self.mood = mood
        self.soreness = soreness
        self.sleepQuality = sleepQuality
        self.lifeStress = lifeStress
        self.bodyWeightKg = bodyWeightKg
        self.lastCaffeineAt = lastCaffeineAt
        self.caffeineAmountMg = caffeineAmountMg
        self.lastMealAt = lastMealAt
        self.habitAlcohol = habitAlcohol
        self.habitIntenseTrainingYesterday = habitIntenseTrainingYesterday
        self.habitLongTrainingYesterday = habitLongTrainingYesterday
        self.habitTravel = habitTravel
        self.habitLateNight = habitLateNight
        self.habitSick = habitSick
        self.habitMeditationYesterday = habitMeditationYesterday
        self.notes = notes
        self.measurement = measurement
    }

    /// Custom decode only to carry old exports forward: files written before
    /// the three-way stress split was reverted have `overallLifeStress` /
    /// `workStress` / `relationshipStress` instead of `lifeStress`, and the
    /// UI always kept those three equal, so either one is representative.
    /// Everything else is a plain field-by-field decode.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        localDate = try c.decode(String.self, forKey: .localDate)
        fatigue = try c.decodeIfPresent(Int.self, forKey: .fatigue)
        mood = try c.decodeIfPresent(Int.self, forKey: .mood)
        soreness = try c.decodeIfPresent(Int.self, forKey: .soreness)
        sleepQuality = try c.decodeIfPresent(Int.self, forKey: .sleepQuality)
        lifeStress = try c.decodeIfPresent(Int.self, forKey: .lifeStress)
            ?? c.decodeIfPresent(Int.self, forKey: .legacyOverallLifeStress)
            ?? c.decodeIfPresent(Int.self, forKey: .legacyWorkStress)
        bodyWeightKg = try c.decodeIfPresent(Double.self, forKey: .bodyWeightKg)
        lastCaffeineAt = try c.decodeIfPresent(Date.self, forKey: .lastCaffeineAt)
        caffeineAmountMg = try c.decodeIfPresent(Double.self, forKey: .caffeineAmountMg)
        lastMealAt = try c.decodeIfPresent(Date.self, forKey: .lastMealAt)
        habitAlcohol = try c.decodeIfPresent(Bool.self, forKey: .habitAlcohol)
        habitIntenseTrainingYesterday = try c.decodeIfPresent(Bool.self, forKey: .habitIntenseTrainingYesterday)
        habitLongTrainingYesterday = try c.decodeIfPresent(Bool.self, forKey: .habitLongTrainingYesterday)
        habitTravel = try c.decodeIfPresent(Bool.self, forKey: .habitTravel)
        habitLateNight = try c.decodeIfPresent(Bool.self, forKey: .habitLateNight)
        habitSick = try c.decodeIfPresent(Bool.self, forKey: .habitSick)
        habitMeditationYesterday = try c.decodeIfPresent(Bool.self, forKey: .habitMeditationYesterday)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        measurement = try c.decodeIfPresent(ExportMeasurement.self, forKey: .measurement)
    }

    /// Manual, since the custom `init(from:)` above stops Encodable from
    /// being auto-synthesized. Always writes the current `lifeStress` key —
    /// the legacy keys are decode-only.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(localDate, forKey: .localDate)
        try c.encodeIfPresent(fatigue, forKey: .fatigue)
        try c.encodeIfPresent(mood, forKey: .mood)
        try c.encodeIfPresent(soreness, forKey: .soreness)
        try c.encodeIfPresent(sleepQuality, forKey: .sleepQuality)
        try c.encodeIfPresent(lifeStress, forKey: .lifeStress)
        try c.encodeIfPresent(bodyWeightKg, forKey: .bodyWeightKg)
        try c.encodeIfPresent(lastCaffeineAt, forKey: .lastCaffeineAt)
        try c.encodeIfPresent(caffeineAmountMg, forKey: .caffeineAmountMg)
        try c.encodeIfPresent(lastMealAt, forKey: .lastMealAt)
        try c.encodeIfPresent(habitAlcohol, forKey: .habitAlcohol)
        try c.encodeIfPresent(habitIntenseTrainingYesterday, forKey: .habitIntenseTrainingYesterday)
        try c.encodeIfPresent(habitLongTrainingYesterday, forKey: .habitLongTrainingYesterday)
        try c.encodeIfPresent(habitTravel, forKey: .habitTravel)
        try c.encodeIfPresent(habitLateNight, forKey: .habitLateNight)
        try c.encodeIfPresent(habitSick, forKey: .habitSick)
        try c.encodeIfPresent(habitMeditationYesterday, forKey: .habitMeditationYesterday)
        try c.encodeIfPresent(notes, forKey: .notes)
        try c.encodeIfPresent(measurement, forKey: .measurement)
    }
}

struct ExportMeasurement: Codable {
    let measuredAt: Date
    let protocolVersion: String
    let rmssdMs: Double?
    let meanHrBpm: Double?
    let hrvQuality: String?
    let avgLyingHr: Double?
    let avgStandingHr: Double?
    let peakStandingHr: Double?
    let gapAvg: Double?
    let gapPeak: Double?
    let orthostaticSkipped: Bool
}

extension DayRecord {
    var exportRecord: ExportDay {
        ExportDay(
            localDate: localDate,
            fatigue: fatigue,
            mood: mood,
            soreness: soreness,
            sleepQuality: sleepQuality,
            lifeStress: lifeStress,
            bodyWeightKg: bodyWeightKg,
            lastCaffeineAt: lastCaffeineAt,
            caffeineAmountMg: caffeineAmountMg,
            lastMealAt: lastMealAt,
            habitAlcohol: habitAlcohol,
            habitIntenseTrainingYesterday: habitIntenseTrainingYesterday,
            habitLongTrainingYesterday: habitLongTrainingYesterday,
            habitTravel: habitTravel,
            habitLateNight: habitLateNight,
            habitSick: habitSick,
            habitMeditationYesterday: habitMeditationYesterday,
            notes: notes,
            measurement: measurement?.exportRecord
        )
    }
}

extension MeasurementRecord {
    var exportRecord: ExportMeasurement {
        ExportMeasurement(
            measuredAt: measuredAt,
            protocolVersion: protocolVersion,
            rmssdMs: rmssdMs,
            meanHrBpm: meanHrBpm,
            hrvQuality: hrvQuality,
            avgLyingHr: avgLyingHr,
            avgStandingHr: avgStandingHr,
            peakStandingHr: peakStandingHr,
            gapAvg: gapAvg,
            gapPeak: gapPeak,
            orthostaticSkipped: orthostaticSkipped
        )
    }
}
