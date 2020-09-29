import XCTest
@testable import fearless
import IrohaCrypto
import FearlessUtils

class ScaleExtrinsicTestsTests: XCTestCase {
    func testImmortal() throws {
        let expectedData = try Data(hexString: "0x3502848ad2a3fba73321961cd5d1b8272aa95a21e75dd5b098fb36ed996961ac7b2931015604975bd1ce5ac5d00210216db0944278db674146a08f69257ef45cd1f9f1680800c437195b6181bd3161bdd23fb6bb856ed7427787edef125a692bd512b5880014000400dd0072af4b3b66a01be502555d4ddafb55e8e7df3fb04c836d83255547a8a2ff0700e40b5402")

        let decoder = try ScaleDecoder(data: expectedData)
        let extrinsic = try Extrinsic(scaleDecoder: decoder)

        if let transferData = extrinsic.call.arguments {
            let decoder = try ScaleDecoder(data: transferData)
            let transfer = try TransferCall(scaleDecoder: decoder)

            Logger.shared.debug("\(transfer.receiver.toHex())")
        }

        let encoder = ScaleEncoder()
        try extrinsic.encode(scaleEncoder: encoder)

        let resultData = encoder.encode()

        XCTAssertEqual(resultData, expectedData)
    }
}
