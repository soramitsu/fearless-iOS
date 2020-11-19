import XCTest
@testable import fearless

class ByteLengthEncodingTests: XCTestCase {
    func testSimpleCase() {
        let processor = ByteLengthProcessor(maxLength: 8)

        XCTAssertEqual(processor.process(text: "kusama"), "kusama")
        XCTAssertEqual(processor.process(text: "polkadot-and-kusama"), "polkadot")
    }

    func testCompoundCharactersFullyTruncated() {
        let processor = ByteLengthProcessor(maxLength: 8)

        XCTAssertEqual(processor.process(text: "westend😀polkadot"), "westend")
    }
}
