import XCTest
@testable import fearless

class MnemonicTextProcessorTest: XCTestCase {

    func testTrimmedMnemonic() {
        let processor = MnemonicTextProcessor()
        let result = processor.process(text: "   remove  \t stairs edit swift write \n agent sing     train vacuum nothing gesture axis ")

        XCTAssertEqual(result, "remove stairs edit swift write agent sing train vacuum nothing gesture axis")
    }
}
