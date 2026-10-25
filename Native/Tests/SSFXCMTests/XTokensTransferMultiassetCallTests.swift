import BigInt
import SSFModels
import XCTest

@testable import SSFXCM

final class XTokensTransferMultiassetCallTests: XCTestCase {
    func testXTokensTransferMultiassetCallInit() {
        // arrange
        let asset: XcmVersionedMultiAsset = .V3(.init(
            multilocation: .init(
                parents: 0,
                interior: .init(items: [.onlyChild])
            ),
            amount: BigUInt()
        ))
        let dest: XcmVersionedMultiLocation = .V3(.init(
            parents: 0,
            interior: .init(items: [.onlyChild])
        ))
        let destWeightLimit: XcmWeightLimit = .unlimited

        // act
        let call = XTokensTransferMultiassetCall(
            asset: asset,
            dest: dest,
            destWeightLimit: destWeightLimit
        )

        // assert
        XCTAssertEqual(call.asset, asset)
        XCTAssertEqual(call.dest, dest)
        XCTAssertEqual(call.destWeightLimit, destWeightLimit)
    }

    func testEncode() throws {
        // arrange
        let call = XTokensTransferMultiassetCall(
            asset: .V3(.init(
                multilocation: .init(parents: 0, interior: .init(items: [.onlyChild])),
                amount: BigUInt()
            )),
            dest: .V3(.init(parents: 0, interior: .init(items: [.onlyChild]))),
            destWeightLimit: .unlimited
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        // act
        let encodedData = try encoder.encode(call)

        // assert: the `dest_weight: u64` form is gone, the limit is always a `WeightLimit`
        XCTAssertEqual(String(decoding: encodedData, as: UTF8.self), TestData.callJson)
    }
}

extension XTokensTransferMultiassetCallTests {
    enum TestData {
        static let callJson = [
            #"{"asset":["V3",{"fun":["Fungible","0"],"id":["Concrete",{"interior":["X1",["OnlyChild",null]],"parents":"0"}]}],"#,
            #""dest":["V3",{"interior":["X1",["OnlyChild",null]],"parents":"0"}],"#,
            #""destWeightLimit":["Unlimited",null]}"#,
        ].joined()
    }
}
