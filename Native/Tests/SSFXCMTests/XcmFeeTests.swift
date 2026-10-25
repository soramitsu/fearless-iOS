import BigInt
import XCTest

@testable import SSFXCM

final class XcmFeeTests: XCTestCase {
    func testXcmFeeInit() {
        // arrange
        let chainId = "1"
        let destChain = "1"
        let destXcmFee: [DestXcmFee] = [DestXcmFee(symbol: "symbol", precision: "precision")]
        let weight = BigUInt()

        // act
        let fee = XcmFee(
            chainId: chainId,
            destChain: destChain,
            destXcmFee: destXcmFee,
            weight: weight
        )

        // assert
        XCTAssertEqual(fee.chainId, chainId)
        XCTAssertEqual(fee.destChain, destChain)
        XCTAssertEqual(fee.destXcmFee, destXcmFee)
        XCTAssertEqual(fee.weight, weight)
    }

    func testDestXcmFeeInit() {
        // arrange
        let feeInPlanks = BigUInt()
        let symbol = "1"
        let precision = "2"

        // act
        let destXcmFee = DestXcmFee(
            feeInPlanks: feeInPlanks,
            symbol: symbol,
            precision: precision
        )

        // assert
        XCTAssertEqual(destXcmFee.feeInPlanks, feeInPlanks)
        XCTAssertEqual(destXcmFee.symbol, symbol)
        XCTAssertEqual(destXcmFee.precision, precision)
    }
}
