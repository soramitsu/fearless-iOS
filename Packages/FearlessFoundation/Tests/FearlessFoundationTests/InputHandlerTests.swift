import XCTest
@testable import FearlessFoundation

final class InputHandlerTests: XCTestCase {
    func testReplacement_whenHandlerEnabledAndInputValid_thenUpdatesValueAndReturnsTrue() {
        let handler = InputHandler(
            value: "so2a",
            maxLength: 4,
            validCharacterSet: CharacterSet.alphanumerics
        )

        let result = handler.didReceiveReplacement(
            "r",
            for: NSRange(location: 2, length: 1)
        )

        XCTAssertTrue(result)
        XCTAssertEqual(handler.value, "sora")
    }

    func testReplacement_whenInputContainsInvalidCharacter_thenKeepsValueAndReturnsFalse() {
        let handler = InputHandler(
            value: "sora",
            validCharacterSet: CharacterSet.alphanumerics
        )

        let result = handler.didReceiveReplacement(
            "!",
            for: NSRange(location: 4, length: 0)
        )

        XCTAssertFalse(result)
        XCTAssertEqual(handler.value, "sora")
    }

    func testReplacement_whenInputExceedsMaximumLength_thenKeepsValueAndReturnsFalse() {
        let handler = InputHandler(value: "sora", maxLength: 4)

        let result = handler.didReceiveReplacement(
            "2",
            for: NSRange(location: 4, length: 0)
        )

        XCTAssertFalse(result)
        XCTAssertEqual(handler.value, "sora")
    }

    func testReplacement_whenHandlerDisabled_thenKeepsValueAndReturnsFalse() {
        let handler = InputHandler(value: "sora", enabled: false)

        let result = handler.didReceiveReplacement(
            "x",
            for: NSRange(location: 0, length: 1)
        )

        XCTAssertFalse(result)
        XCTAssertEqual(handler.value, "sora")
    }

    func testReplacement_whenProcessorChangesValue_thenStoresProcessedValueAndReturnsFalse() {
        let handler = InputHandler(
            value: "sora",
            processor: TrimmingCharacterProcessor(charset: CharacterSet.whitespaces)
        )

        let result = handler.didReceiveReplacement(
            " ",
            for: NSRange(location: 4, length: 0)
        )

        XCTAssertFalse(result)
        XCTAssertEqual(handler.value, "sora")
    }

    func testCompleted_whenPredicateAndNormalizerProvided_thenUsesNormalizedValue() {
        let handler = InputHandler(
            value: " sora ",
            predicate: NSPredicate(format: "SELF == %@", "sora"),
            normalizer: TrimmingCharacterProcessor(charset: CharacterSet.whitespaces)
        )

        XCTAssertTrue(handler.completed)
        XCTAssertEqual(handler.normalizedValue, "sora")
    }

    func testObservers_whenValueChanges_thenReceivesOldAndNewValues() {
        let handler = InputHandler(value: "old")
        let observer = InputObserver()
        handler.addObserver(observer)

        handler.changeValue(to: "new")

        XCTAssertEqual(observer.events, [
            InputObserver.Event(oldValue: "old", newValue: "new")
        ])
    }

    func testObservers_whenObserverRemoved_thenDoesNotReceiveFurtherChanges() {
        let handler = InputHandler(value: "old")
        let observer = InputObserver()
        handler.addObserver(observer)

        handler.removeObserver(observer)
        handler.changeValue(to: "new")

        XCTAssertTrue(observer.events.isEmpty)
    }

    func testClearValue_whenCalled_thenEmptiesValueAndNotifiesObservers() {
        let handler = InputHandler(value: "sora")
        let observer = InputObserver()
        handler.addObserver(observer)

        handler.clearValue()

        XCTAssertEqual(handler.value, "")
        XCTAssertEqual(observer.events, [
            InputObserver.Event(oldValue: "sora", newValue: "")
        ])
    }
}

private final class InputObserver: InputHandlingObserver {
    struct Event: Equatable {
        let oldValue: String
        let newValue: String
    }

    private(set) var events: [Event] = []

    func didChangeInputValue(_ handler: InputHandling, from oldValue: String) {
        events.append(Event(oldValue: oldValue, newValue: handler.value))
    }
}
