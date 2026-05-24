import XCTest
@testable import FearlessFoundation

final class TextProcessorTests: XCTestCase {
    func testPrefixCharacterProcessor_whenInputStartsWithCharactersInSet_thenRemovesOnlyPrefix() {
        let processor = PrefixCharacterProcessor(charset: CharacterSet(charactersIn: "-"))

        XCTAssertEqual(processor.process(text: "---swift--wallet"), "swift--wallet")
    }

    func testDuplicatingCharacterProcessor_whenInputHasRepeatedCharactersInSet_thenCollapsesDuplicates() {
        let processor = DuplicatingCharacterProcessor(charset: CharacterSet(charactersIn: "-"))

        XCTAssertEqual(processor.process(text: "swift---wallet--ios"), "swift-wallet-ios")
    }

    func testTrimmingCharacterProcessor_whenInputHasCharactersAroundValue_thenTrimsBothEnds() {
        let processor = TrimmingCharacterProcessor(charset: CharacterSet(charactersIn: "-"))

        XCTAssertEqual(processor.process(text: "---swift-wallet---"), "swift-wallet")
    }

    func testCompoundTextProcessor_whenProcessorsAreChained_thenAppliesThemInOrder() {
        let processor = CompoundTextProcessor(processors: [
            PrefixCharacterProcessor(charset: CharacterSet(charactersIn: "-")),
            DuplicatingCharacterProcessor(charset: CharacterSet(charactersIn: "-")),
            TrimmingCharacterProcessor(charset: CharacterSet(charactersIn: "-"))
        ])

        XCTAssertEqual(processor.process(text: "---swift---wallet---"), "swift-wallet")
    }
}
