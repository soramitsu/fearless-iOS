import SSFUtils
import XCTest
@testable import fearless

final class CovFPayoutMappingTests: XCTestCase {
    func testNominationFormatsResolveHexAndObjectTargetsAndDiscardInvalidEntries() throws {
        let arguments: [[String: Any]] = [["name": "targets", "value": ["0x0102", ["Id": "0x0304"], "bad-hex", 99]]]
        let encoded = String(decoding: try JSONSerialization.data(withJSONObject: arguments), as: UTF8.self)
        for callField in ["call_module_function", "call_function", "call_name"] {
            for argumentField in ["params", "call_args"] {
                for payload: Any in [arguments, encoded] {
                    let json = try CovFFixtures.json(["call_module": "STAKING", callField: "Nominate", argumentField: payload])
                    XCTAssertEqual(NominateMapper().map(input: json), [Data([1, 2]), Data([3, 4])])
                }
            }
        }
    }

    func testNominationRejectsOtherCallsAndMalformedArguments() throws {
        let values: [[String: Any]] = [
            [:], ["call_module": "Balances", "call_name": "nominate"],
            ["call_module": "Staking", "call_name": "bond"],
            ["call_module": "Staking", "call_name": "nominate"],
            ["call_module": "Staking", "call_name": "nominate", "params": "broken"],
            ["call_module": "Staking", "call_name": "nominate", "params": [["name": "not-targets", "value": []]]]
        ]
        for value in values { XCTAssertNil(NominateMapper().map(input: try CovFFixtures.json(value))) }
        let empty = try CovFFixtures.json(["call_module": "Staking", "call_name": "nominate", "params": [["name": "targets", "value": []]]])
        XCTAssertEqual(NominateMapper().map(input: empty), [])
    }

    func testBatchMapsEachNestedCallForBothIndexerArgumentFormats() throws {
        let mapper = BatchMapper(innerMapper: AnyMapper(mapper: NominateMapper()))
        let call: [String: Any] = [
            "call_module": "Staking", "call_name": "nominate", "params": [["name": "targets", "value": ["0x01"]]]
        ]
        let arguments: [[String: Any]] = [["name": "calls", "value": [call, ["call_name": "transfer"]]]]
        let encoded = String(decoding: try JSONSerialization.data(withJSONObject: arguments), as: UTF8.self)
        for key in ["params", "call_args"] {
            for payload: Any in [arguments, encoded] {
                let mapped = mapper.map(input: try CovFFixtures.json([key: payload]))
                XCTAssertEqual(mapped.count, 2)
                XCTAssertEqual(mapped[0], [Data([1])])
                XCTAssertNil(mapped[1])
            }
        }
        for input: [String: Any] in [[:], ["params": "broken"], ["params": []]] {
            XCTAssertTrue(mapper.map(input: try CovFFixtures.json(input)).isEmpty)
        }
    }
}
