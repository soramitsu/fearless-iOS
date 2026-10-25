import BigInt
import XCTest

@testable import SSFXCM

final class SpWeightsWeightV3WeightTests: XCTestCase {
    func testSpWeightsWeightV3WeightInit() {
        // arrange
        let refTime = BigUInt()
        let proofSize = BigUInt()

        // act
        let weight = SpWeightsWeightV3Weight(
            refTime: refTime,
            proofSize: proofSize
        )

        // assert
        XCTAssertEqual(weight.refTime, refTime)
        XCTAssertEqual(weight.proofSize, proofSize)
    }
}
