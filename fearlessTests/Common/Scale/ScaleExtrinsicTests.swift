import XCTest
@testable import fearless
import IrohaCrypto
import FearlessUtils

class ScaleExtrinsicTestsTests: XCTestCase {
    func testEcdsaExtrinsic() throws {
        let expectedData = try Data(hexString: "0x3902848a6da7dc6a1d69fcd96b00272053e3885aedb26a8bd461b5093621b7b2dba42a02bcf07bae88dfc74a786fa0f8922a85bbba805ed32fd2cb7b5315c5a11c3ca0b5aed916e5dffb215927f89e46a1e03a778ddebcf74ac10e2ab466d84182c8ca15010000000400d44468311136089496167577614e28b934710d799583177a86af6352d09f6f6b070010a5d4e8")

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
