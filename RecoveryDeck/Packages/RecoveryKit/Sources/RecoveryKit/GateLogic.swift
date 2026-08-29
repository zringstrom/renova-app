import Foundation

/// What the gate needs to know about a day's questionnaire — a plain DTO the app
/// maps its SwiftData `DayRecord` onto at the boundary, so this logic stays testable
/// without pulling in SwiftData (see TECH_SPEC §6.3, PRD §6.2).
public struct QuestionnaireStatus: Sendable, Equatable {
    public let localDate: LocalDate
    public let isComplete: Bool

    public init(localDate: LocalDate, isComplete: Bool) {
        self.localDate = localDate
        self.isComplete = isComplete
    }
}

/// Normative gating rules from PRD §6.2 / TECH_SPEC §6.3.
///
/// Both destinations require a questionnaire *for today specifically* — a completed
/// questionnaire from yesterday does not carry over at day rollover.
public enum GateLogic {
    public static func canAccessHistory(today: LocalDate, questionnaire: QuestionnaireStatus?) -> Bool {
        isCompleteForToday(today: today, questionnaire: questionnaire)
    }

    public static func canStartMeasurement(today: LocalDate, questionnaire: QuestionnaireStatus?) -> Bool {
        isCompleteForToday(today: today, questionnaire: questionnaire)
    }

    private static func isCompleteForToday(today: LocalDate, questionnaire: QuestionnaireStatus?) -> Bool {
        guard let questionnaire else { return false }
        return questionnaire.localDate == today && questionnaire.isComplete
    }

    /// Block A + B (PRD §6.3): five required 1–7 scores — Fatigue, Mood,
    /// Soreness, Sleep quality, Life stress. Submit enables only when all
    /// five have been set. (Stress was briefly split three ways — Work,
    /// Relationship, Overall — but that was reverted; a single Life stress
    /// score is the only stress input now.)
    ///
    /// Note on polarity: Fatigue and Life stress are "amount" scales (1 =
    /// little/good, 7 = a lot/bad); Mood, Soreness, and Sleep quality are
    /// "higher = better" scales. `isQuestionnaireComplete` only checks presence
    /// and range — it does not need to know about polarity, since nothing here
    /// averages the scores together.
    public static func isQuestionnaireComplete(
        fatigue: Int?,
        mood: Int?,
        soreness: Int?,
        sleepQuality: Int?,
        lifeStress: Int?
    ) -> Bool {
        let scores = [fatigue, mood, soreness, sleepQuality, lifeStress]
        for score in scores {
            guard let score, (1...7).contains(score) else { return false }
        }
        return true
    }
}
