import XCTest
@testable import fearless

class MnemonicTextNormalizerTest: XCTestCase {

    func testTrimmedMnemonic() {
        let normalizer = MnemonicTextNormalizer()
        let normalized = normalizer.process(text: "   remove  \t stairs edit swift write \n agent sing     train vacuum nothing gesture axis ")

        XCTAssertEqual(normalized, "remove stairs edit swift write agent sing train vacuum nothing gesture axis")
    }
}
