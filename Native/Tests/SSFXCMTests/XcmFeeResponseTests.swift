import BigInt
import XCTest

@testable import SSFXCM

final class XcmFeeResponseTests: XCTestCase {
    func testXcmFeeResponseInit() {
        // act
        let response = XcmFeeResponse(
            originalChainFee: TestData.fee,
            destinationChainFee: TestData.fee
        )

        // assert
        XCTAssertEqual(response.originalChainFee, TestData.fee)
        XCTAssertEqual(response.destinationChainFee, TestData.fee)
    }
}

extension XcmFeeResponseTests {
    enum TestData {
        static let fee = XcmFee(
            chainId: "chainId",
            destChain: "destChain",
            destXcmFee: [DestXcmFee(
                feeInPlanks: BigUInt(),
                symbol: "symbol",
                precision: "precision"
            )],
            weight: BigUInt()
        )
    }
}
