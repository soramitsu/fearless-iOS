import SSFModels
import XCTest
@testable import fearless

/// SORA history records say whether their extrinsic succeeded. Transfers and rewards used that, but swaps, bridge
/// transfers and other extrinsics were always shown as completed, even when the record said they failed.
final class SoraSubsquidHistoryStatusTests: XCTestCase {
    func testFailedSwapBridgeAndExtrinsicRecordsAreShownAsFailed() throws {
        for (module, method) in [("liquidityProxy", "swap"), ("bridgeMultisig", "transferToSidechain"), ("staking", "bond")] {
            let transaction = try Self.transaction(module: module, method: method, success: false)
            XCTAssertEqual(transaction.status, .rejected, "\(module).\(method)")
        }
    }

    func testSuccessfulSwapBridgeAndExtrinsicRecordsAreShownAsCompleted() throws {
        for (module, method) in [("liquidityProxy", "swap"), ("bridgeMultisig", "transferToSidechain"), ("staking", "bond")] {
            let transaction = try Self.transaction(module: module, method: method, success: true)
            XCTAssertEqual(transaction.status, .commited, "\(module).\(method)")
        }
    }

    private static func transaction(module: String, method: String, success: Bool) throws -> AssetTransactionData {
        let json: [String: Any] = [
            "id": "\(module)-\(method)-\(success)",
            "address": "cnVkoGs3rEMqLqY27c2nfVXJRGdzNJk2ns78DcqtppaSRe8qm",
            "module": module,
            "method": method,
            "networkFee": "700000000000000",
            "timestamp": 1_700_000_000,
            "execution": ["success": success],
            "data": [
                "baseAssetId": "0x0200000000000000000000000000000000000000000000000000000000000000",
                "targetAssetId": "0x0200050000000000000000000000000000000000000000000000000000000000",
                "baseAssetAmount": "1",
                "targetAssetAmount": "2",
                "amount": "1"
            ]
        ]
        let element = try JSONDecoder().decode(
            SoraSubsquidHistoryElement.self,
            from: JSONSerialization.data(withJSONObject: json)
        )
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 69)
        let asset = ChainModelGenerator.generateAssetWithId("xor", symbol: "XOR", assetPresicion: 18)
        return element.createTransactionForAddress(
            "cnVkoGs3rEMqLqY27c2nfVXJRGdzNJk2ns78DcqtppaSRe8qm",
            chain: chain,
            asset: asset
        )
    }
}
