import Testing
@testable import PaneFlipCore

struct SmartShiftTests {
    private func answer(index: UInt8, byte4: UInt8) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 20)
        bytes[0] = 0x11; bytes[1] = 0xFF; bytes[2] = index; bytes[3] = 0x0A; bytes[4] = byte4
        return bytes
    }

    @Test func theQuestionsAreLongReportsToTheBluetoothMouse() {
        let ask = SmartShift.featureQuestion()
        #expect(ask.count == 20)
        #expect(Array(ask[0...5]) == [0x11, 0xFF, 0x00, 0x0A, 0x21, 0x10])
        #expect(Array(SmartShift.modeQuestion(featureIndex: 13)[0...3]) == [0x11, 0xFF, 13, 0x0A])
    }

    @Test func theAnswerToTheFirstQuestionSaysWhereTheFeatureIs() {
        #expect(SmartShift.featureIndex(inAnswer: answer(index: 0x00, byte4: 13)) == 13)
        // A mouse without the feature answers index 0.
        #expect(SmartShift.featureIndex(inAnswer: answer(index: 0x00, byte4: 0)) == nil)
    }

    @Test func theModeByteIsFreeSpinOrRatchet() {
        #expect(SmartShift.mode(inAnswer: answer(index: 13, byte4: 1), featureIndex: 13) == .freeSpin)
        #expect(SmartShift.mode(inAnswer: answer(index: 13, byte4: 2), featureIndex: 13) == .ratchet)
        #expect(SmartShift.mode(inAnswer: answer(index: 13, byte4: 0), featureIndex: 13) == nil)
    }

    @Test func otherReportsAreNotTakenForAnswers() {
        var mouseReport = [UInt8](repeating: 0, count: 8)
        mouseReport[0] = 0x02
        #expect(SmartShift.mode(inAnswer: mouseReport, featureIndex: 13) == nil)
        #expect(SmartShift.mode(inAnswer: answer(index: 12, byte4: 1), featureIndex: 13) == nil)
        var otherSender = answer(index: 13, byte4: 1)
        otherSender[3] = 0x0B
        #expect(SmartShift.mode(inAnswer: otherSender, featureIndex: 13) == nil)
        #expect(SmartShift.featureIndex(inAnswer: mouseReport) == nil)
    }
}
