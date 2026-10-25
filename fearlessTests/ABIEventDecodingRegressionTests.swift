import BigInt
import XCTest
@testable import fearless

final class ABIEventDecodingRegressionTests: XCTestCase {
    func testNonanonymousEventRejectsMissingOrWrongSignature() {
        let event = ABI.Element.Event(name: "Changed", inputs: [], anonymous: false)
        XCTAssertNil(event.decodeReturnedLogs(eventLogTopics: [], eventLogData: Data()))
        XCTAssertNil(event.decodeReturnedLogs(eventLogTopics: [Data(repeating: 0, count: 32)], eventLogData: Data()))
        XCTAssertNotNil(event.decodeReturnedLogs(eventLogTopics: [event.topic], eventLogData: Data()))
    }

    func testAnonymousEventHasNoSignatureTopic() throws {
        let empty = ABI.Element.Event(name: "Empty", inputs: [], anonymous: true)
        XCTAssertNotNil(empty.decodeReturnedLogs(eventLogTopics: [], eventLogData: Data()))
        let event = ABI.Element.Event(name: "Changed", inputs: [
            .init(name: "value", type: .uint(bits: 256), indexed: true)
        ], anonymous: true)
        let word = Data(repeating: 0, count: 31) + Data([42])
        let result = try XCTUnwrap(event.decodeReturnedLogs(eventLogTopics: [word], eventLogData: Data()))
        XCTAssertEqual(result["value"] as? BigUInt, BigUInt(42))
        XCTAssertNil(event.decodeReturnedLogs(eventLogTopics: [], eventLogData: Data()))
        XCTAssertNil(event.decodeReturnedLogs(eventLogTopics: [word, word], eventLogData: Data()))
    }

    func testNonanonymousIndexedValueKeepsSignatureOffset() throws {
        let event = ABI.Element.Event(name: "Changed", inputs: [
            .init(name: "value", type: .uint(bits: 256), indexed: true)
        ], anonymous: false)
        let word = Data(repeating: 0, count: 31) + Data([7])
        let result = try XCTUnwrap(event.decodeReturnedLogs(eventLogTopics: [event.topic, word], eventLogData: Data()))
        XCTAssertEqual(result["value"] as? BigUInt, BigUInt(7))
    }
}
