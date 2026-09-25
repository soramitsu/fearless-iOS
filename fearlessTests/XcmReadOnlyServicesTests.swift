import BigInt
import Foundation
import SSFExtrinsicKit
import SSFModels
@testable import SSFXCM
import XCTest

final class XcmReadOnlyServicesTests: XCTestCase {
    func testFeeQuoteForwardsExactPublicInputsWithoutTransfer() async throws {
        let service = ReadOnlyXcmServiceSpy()
        let estimator = XcmReadOnlyFeeEstimator(service: service)
        let account = Data(repeating: 23, count: 32)
        let amount = BigUInt("18446744073709551617")
        let result = await estimator.estimateOriginalFee(
            fromChainId: "origin", assetSymbol: "XOR", destChainId: "destination",
            destAccountId: account, amount: amount
        )
        XCTAssertEqual(try result.get().fee, "7")
        XCTAssertEqual(service.origin, "origin")
        XCTAssertEqual(service.symbol, "XOR")
        XCTAssertEqual(service.destination, "destination")
        XCTAssertEqual(service.account, account)
        XCTAssertEqual(service.amount, amount)
        XCTAssertEqual(service.feeCalls, 1)
        XCTAssertEqual(service.transferCalls, 0)
    }

    func testFeeFailureIsPreservedWithoutAttemptingTransfer() async {
        let service = ReadOnlyXcmServiceSpy()
        let expected = NSError(domain: "read-only-fee-fixture", code: 7)
        service.feeResult = .failure(expected)
        let result = await XcmReadOnlyFeeEstimator(service: service).estimateOriginalFee(
            fromChainId: "origin", assetSymbol: "XOR", destChainId: "destination",
            destAccountId: Data(repeating: 1, count: 32), amount: 1
        )
        guard case let .failure(error) = result else { return XCTFail("Expected original fee error") }
        XCTAssertTrue(error as NSError === expected)
        XCTAssertEqual(service.transferCalls, 0)
    }

    func testReadOnlyExistentialCannotBeCastIntoTransferService() {
        let estimator: XcmFeeEstimating = XcmReadOnlyFeeEstimator(service: ReadOnlyXcmServiceSpy())
        XCTAssertNil(estimator as? XcmExtrinsicServiceProtocol)
    }

    func testReadOnlySignerRejectsEveryPayloadWithoutSigningMaterial() {
        for bytes in [Data(), Data(repeating: 1, count: 32), Data(repeating: 255, count: 1024)] {
            XCTAssertThrowsError(try XcmReadOnlySigner().sign(bytes)) { error in
                guard case XcmReadOnlyError.signingUnavailable = error else {
                    return XCTFail("Expected explicit read-only refusal")
                }
            }
        }
    }
}

private final class ReadOnlyXcmServiceSpy: XcmExtrinsicServiceProtocol {
    var feeResult: SSFExtrinsicKit.FeeExtrinsicResult = .success(
        SSFExtrinsicKit.RuntimeDispatchInfo(inclusionFee: FeeDetails(baseFee: 1, lenFee: 2, adjustedWeightFee: 4))
    )
    var feeCalls = 0
    var transferCalls = 0
    var origin: String?
    var destination: String?
    var symbol: String?
    var account: AccountId?
    var amount: BigUInt?

    func estimateOriginalFee(fromChainId: String, assetSymbol: String, destChainId: String,
                             destAccountId: AccountId, amount: BigUInt) async -> SSFExtrinsicKit.FeeExtrinsicResult {
        feeCalls += 1
        origin = fromChainId
        symbol = assetSymbol
        destination = destChainId
        account = destAccountId
        self.amount = amount
        return feeResult
    }

    func transfer(fromChainId: String, assetSymbol: String, destChainId: String,
                  destAccountId: AccountId, amount: BigUInt) async -> SSFExtrinsicKit.SubmitExtrinsicResult {
        transferCalls += 1
        XCTFail("Read-only service invoked transfer")
        return .failure(XcmReadOnlyError.signingUnavailable)
    }
}
