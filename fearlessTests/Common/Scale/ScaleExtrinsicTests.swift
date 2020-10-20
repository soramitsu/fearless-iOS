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

    func testOneMoreEd25519Extrinsic() throws {
        let expectedData = try Data(hexString: "0x35028406c60aeddcff7ecdf122d0299e915f63815cdc06a5fbabaa639588b4b9283d5000823ae47acdaca4b8fc1b4c2ebab3f90c6e154d2ece08ca8b7c048b86f1b0577aa4ae13c988f77d61518f503651811a79c331cb01cbf389623c989515307ca884001800040006c60aeddcff7ecdf122d0299e915f63815cdc06a5fbabaa639588b4b9283d500700f4b028eb")

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
}
