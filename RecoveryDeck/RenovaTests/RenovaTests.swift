import XCTest
import RecoveryKit
@testable import Renova

final class RenovaTests: XCTestCase {
    func testGateLogicIsReachableFromTheAppTarget() {
        let today = LocalDate(string: "2026-08-02")!
        let complete = QuestionnaireStatus(localDate: today, isComplete: true)
        XCTAssertTrue(GateLogic.canAccessHistory(today: today, questionnaire: complete))
    }
}
