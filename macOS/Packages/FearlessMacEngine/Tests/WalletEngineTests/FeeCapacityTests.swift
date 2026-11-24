import WalletCore
import XCTest
@testable import WalletEngine

final class FeeCapacityTests: XCTestCase {
    func testFeeWithdrawalPreservesNativeDepositBeforeExecutingCall() throws {
        let native = Funds(free: 11, total: 11, transferable: 11, minimum: 10, exists: true)
        let heldAsset = Funds(free: 100, total: 100, transferable: 100, minimum: 5, exists: true)
        var request = try TransferRequest(
            walletID: WalletID(),
            assetID: .native("chain"),
            recipient: "recipient",
            amount: XCTUnwrap(TokenAmount(units: "9", decimals: 0)),
            keepAlive: false
        )
        var capacity = TransferCapacity(balance: native, native: native, fee: 2, request: request, preserveAsset: false)
        XCTAssertTrue(capacity.insufficientFee)
        XCTAssertEqual(capacity.maximum, 0)
        capacity = TransferCapacity(balance: native, native: native, fee: 1, request: request, preserveAsset: false)
        XCTAssertFalse(capacity.insufficientFee)
        XCTAssertEqual(capacity.maximum, 10)
        request.assetID = AssetID(chainID: "chain", key: "asset:1984")
        capacity = TransferCapacity(balance: heldAsset, native: native, fee: 2, request: request, preserveAsset: true)
        XCTAssertTrue(capacity.insufficientFee)
        XCTAssertEqual(capacity.maximum, 0)
        capacity = TransferCapacity(balance: heldAsset, native: native, fee: 1, request: request, preserveAsset: true)
        XCTAssertFalse(capacity.insufficientFee)
        XCTAssertEqual(capacity.maximum, 95)
    }
}
