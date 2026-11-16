import BigInt
import Foundation
import SSFUtils
import XCTest
@testable import fearless

final class CovGCreatePoolCallTests: XCTestCase {
    func testCreatePoolCallRoundTripsStateTogglerAndBouncerShapes() throws {
        let root = MultiAddress.accoundId(Data(repeating: 1, count: 32))
        let nominator = MultiAddress.accoundId(Data(repeating: 2, count: 32))
        let toggler = MultiAddress.accoundId(Data(repeating: 3, count: 32))
        for value in [StateTogglerValue.stateToggler(value: toggler), .bouncer(value: toggler)] {
            let call = CreatePoolCall(amount: 77, root: root, nominator: nominator, stateToggler: value)
            let data = try JSONEncoder().encode(call)
            let keys = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any]).keys
            let decoded = try JSONDecoder().decode(CreatePoolCall.self, from: data)
            XCTAssertEqual(decoded.amount, 77)
            XCTAssertEqual(decoded.root, root)
            XCTAssertEqual(decoded.nominator, nominator)
            switch (value, decoded.stateToggler) {
            case let (.stateToggler, .stateToggler(decodedValue)):
                XCTAssertTrue(keys.contains("stateToggler"))
                XCTAssertEqual(decodedValue, toggler)
            case let (.bouncer, .bouncer(decodedValue)):
                XCTAssertTrue(keys.contains("bouncer"))
                XCTAssertEqual(decodedValue, toggler)
            default:
                XCTFail("Toggler shape changed: \(value) -> \(decoded.stateToggler)")
            }
        }
        XCTAssertThrowsError(try JSONDecoder().decode(CreatePoolCall.self, from: Data(#"{"amount":"1"}"#.utf8)))
    }
}
