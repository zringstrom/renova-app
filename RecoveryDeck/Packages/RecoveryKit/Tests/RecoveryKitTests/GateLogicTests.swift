import Testing
@testable import RecoveryKit

@Suite("GateLogic")
struct GateLogicTests {
    let today = LocalDate(string: "2026-08-02")!
    let yesterday = LocalDate(string: "2026-08-01")!

    @Test("no questionnaire record blocks both destinations")
    func noRecordBlocks() {
        #expect(GateLogic.canAccessHistory(today: today, questionnaire: nil) == false)
        #expect(GateLogic.canStartMeasurement(today: today, questionnaire: nil) == false)
    }

    @Test("yesterday's completed questionnaire does not carry over at day rollover")
    func dayRolloverBlocks() {
        let stale = QuestionnaireStatus(localDate: yesterday, isComplete: true)
        #expect(GateLogic.canAccessHistory(today: today, questionnaire: stale) == false)
        #expect(GateLogic.canStartMeasurement(today: today, questionnaire: stale) == false)
    }

    @Test("incomplete questionnaire for today blocks both destinations")
    func incompleteBlocks() {
        let incomplete = QuestionnaireStatus(localDate: today, isComplete: false)
        #expect(GateLogic.canAccessHistory(today: today, questionnaire: incomplete) == false)
        #expect(GateLogic.canStartMeasurement(today: today, questionnaire: incomplete) == false)
    }

    @Test("complete questionnaire for today unlocks both destinations")
    func completeUnlocks() {
        let complete = QuestionnaireStatus(localDate: today, isComplete: true)
        #expect(GateLogic.canAccessHistory(today: today, questionnaire: complete) == true)
        #expect(GateLogic.canStartMeasurement(today: today, questionnaire: complete) == true)
    }

    @Test("isQuestionnaireComplete requires all seven scores in range")
    func requiresAllSevenScores() {
        #expect(GateLogic.isQuestionnaireComplete(fatigue: 4, mood: 4, soreness: 4, sleepQuality: 4, workStress: 4, relationshipStress: 4, overallLifeStress: 4) == true)
        #expect(GateLogic.isQuestionnaireComplete(fatigue: nil, mood: 4, soreness: 4, sleepQuality: 4, workStress: 4, relationshipStress: 4, overallLifeStress: 4) == false)
        #expect(GateLogic.isQuestionnaireComplete(fatigue: 4, mood: 4, soreness: 4, sleepQuality: 4, workStress: 4, relationshipStress: 4, overallLifeStress: nil) == false)
    }

    @Test("isQuestionnaireComplete rejects out-of-range scores")
    func rejectsOutOfRange() {
        #expect(GateLogic.isQuestionnaireComplete(fatigue: 0, mood: 4, soreness: 4, sleepQuality: 4, workStress: 4, relationshipStress: 4, overallLifeStress: 4) == false)
        #expect(GateLogic.isQuestionnaireComplete(fatigue: 8, mood: 4, soreness: 4, sleepQuality: 4, workStress: 4, relationshipStress: 4, overallLifeStress: 4) == false)
    }
}
