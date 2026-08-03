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

    /// Block A + B (PRD §6.3, revised): seven required 1–7 scores — Fatigue,
    /// Mood, Soreness, Sleep quality, and stress split three ways (Work,
    /// Relationship, Overall). Submit enables only when all seven have been set.
    ///
    /// Note on polarity: Fatigue and the three stress fields are "amount" scales
    /// (1 = little/good, 7 = a lot/bad); Mood, Soreness, and Sleep quality are
    /// "higher = better" scales. `isQuestionnaireComplete` only checks presence
    /// and range — it does not need to know about polarity, since nothing here
    /// averages the scores together.
    public static func isQuestionnaireComplete(
        fatigue: Int?,
        mood: Int?,
        soreness: Int?,
        sleepQuality: Int?,
        workStress: Int?,
        relationshipStress: Int?,
        overallLifeStress: Int?
    ) -> Bool {
        let scores = [fatigue, mood, soreness, sleepQuality, workStress, relationshipStress, overallLifeStress]
        for score in scores {
            guard let score, (1...7).contains(score) else { return false }
        }
        return true
    }
}
