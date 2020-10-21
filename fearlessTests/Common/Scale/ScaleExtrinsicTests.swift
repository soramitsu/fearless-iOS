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

    func testEd25519Extrinsic() throws {
        let expectedData = try Data(hexString: "0x390284fdc41550fb5186d71cae699c31731b3e1baa10680c7bd6b3831a6d222cf4d1680092759a11c4961a04d7110b662dd250bf2471ea6a8e1864969853bc486885281107da0ac05e479b4c90c55b4febe7f40b8318525c04612937b5a13ae9916b560d001800040006c60aeddcff7ecdf122d0299e915f63815cdc06a5fbabaa639588b4b9283d500b00f4b028eb00")

        let decoder = try ScaleDecoder(data: expectedData)
        let extrinsic = try Extrinsic(scaleDecoder: decoder)

        if let transferData = extrinsic.call.arguments {
            let decoder = try ScaleDecoder(data: transferData)
            let transfer = try TransferCall(scaleDecoder: decoder)

            Logger.shared.debug("Receiver: \(transfer.receiver.toHex())")
            Logger.shared.debug("Amount: \(transfer.amount)")
        }

        Logger.shared.debug("Signature: \(extrinsic.transaction!.signature.toHex())")

        Logger.shared.debug("Extrinsic: \(extrinsic)")

        let encoder = ScaleEncoder()
        try extrinsic.encode(scaleEncoder: encoder)

        let resultData = encoder.encode()

        XCTAssertEqual(resultData, expectedData)
    }

    func testMortalExtrinsicDecoding() throws {
        let expectedData = try Data(hexString: "0x310284fdc41550fb5186d71cae699c31731b3e1baa10680c7bd6b3831a6d222cf4d168003a8eb7f3be70d98d86a9ba66f29d8aae0fea70a820a66f38272044811b21f2e7d5e16c73375a3ac775b98177ff0e125a109f0c58f7d7dc1a507b37879250060ec50238000403340a806419d5e278172e45cb0e50da1b031795366c99ddfe0a680bd53b142c6302286bee")

        let decoder = try ScaleDecoder(data: expectedData)
        XCTAssertNoThrow(try Extrinsic(scaleDecoder: decoder))
        XCTAssertTrue(decoder.remained == 0)
    }
}
