import XCTest
import RobinHood
@testable import fearless

/// CDTransactionHistoryItem stores a call path as its module and call names and rebuilt it with
/// CallCodingPath(moduleName:callName:), which is always `.fromInit`. A stored local transfer therefore read back as
/// `.fromInit("Balances", "transfer")`, which is not `.transfer`, and history showed it as an extrinsic. Nothing
/// writes local history items today, so this was latent.
final class TransactionHistoryItemCallPathRoundTripTests: XCTestCase {
    func testEveryNamedCallPathReadsBackAsItself() throws {
        let named = CallCodingPath.allCases + [.polkaswapSwap]
        let unnamed = CallCodingPath(moduleName: "Utility", callName: "batch")
        let items = (named + [unnamed]).enumerated().map { index, path in
            TransactionHistoryItem(
                sender: "alice", receiver: "bob", status: .pending, txHash: "0x\(index)", timestamp: Int64(index),
                fee: "1", blockNumber: nil, txIndex: nil, callPath: path, call: nil
            )
        }
        let repository: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> =
            SubstrateStorageTestFacade().createRepository()
        let queue = OperationQueue()
        let save = repository.saveOperation({ items }, { [] })
        queue.addOperations([save], waitUntilFinished: true)
        _ = try XCTUnwrap(save.result).get()

        let fetch = repository.fetchAllOperation(with: RepositoryFetchOptions())
        queue.addOperations([fetch], waitUntilFinished: true)
        let loaded = Dictionary(uniqueKeysWithValues: try XCTUnwrap(fetch.result).get().map { ($0.txHash, $0.callPath) })

        for item in items {
            XCTAssertEqual(loaded[item.txHash], item.callPath, "\(item.callPath)")
        }
        XCTAssertEqual(loaded["0x0"].map(\.isTransfer), true, "a stored transfer is still a transfer")
    }
}
