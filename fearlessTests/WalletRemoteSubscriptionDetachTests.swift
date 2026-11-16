import RobinHood
import SSFModels
import XCTest
@testable import fearless

/// A balance subscription is attached under a key built from the asset's own storage (System.Account,
/// Tokens.Accounts, Assets.Account…). Detaching always built the System.Account key, so token subscriptions were
/// never detached and kept their node subscription.
final class WalletRemoteSubscriptionDetachTests: XCTestCase {
    func testDetachingATokenSubscriptionRemovesIt() async throws {
        let service = WalletRemoteSubscriptionService(
            chainRegistry: ChainRegistryProtocolStub(),
            repository: AnyDataProviderRepository(RecordingStorageWrapperRepository()),
            operationManager: HoldingOperationManager(),
            logger: Logger.shared
        )
        let accountId = Data(repeating: 7, count: 32)
        let token = AssetModel(
            id: "kusd", name: "KUSD", symbol: "KUSD", precision: 12, currencyId: "KUSD",
            isUtility: false, isNative: false, type: .ormlAsset
        )
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 8)
        let chainAsset = ChainAsset(chain: chain, asset: token)
        XCTAssertEqual(chainAsset.storagePath, .tokens)

        let attached = await service.attachToAccountInfo(of: accountId, chainAsset: chainAsset, queue: nil, closure: nil)
        let subscriptionId = try XCTUnwrap(attached)
        XCTAssertEqual(try Self.pendingKeys(of: service).count, 1)

        let detached = XCTestExpectation(description: "the detach completes")
        service.detachFromAccountInfo(
            for: subscriptionId,
            chainAssetKey: chainAsset.uniqueKey(accountId: accountId),
            queue: nil
        ) { _ in detached.fulfill() }
        await fulfillment(of: [detached], timeout: 5)

        XCTAssertEqual(try Self.pendingKeys(of: service), [], "the token subscription is gone")
    }

    /// The keys of the base service's pending subscriptions.
    private static func pendingKeys(of service: WalletRemoteSubscriptionService) throws -> [String] {
        let base = try XCTUnwrap(Mirror(reflecting: service).superclassMirror)
        let pending = try XCTUnwrap(base.descendant("pendingSubscriptions") as? [String: Any])
        return Array(pending.keys)
    }
}

/// Accepts operations and never runs them, so a subscription stays pending.
private final class HoldingOperationManager: OperationManagerProtocol {
    private let lock = NSLock()
    private var held: [Operation] = []

    func enqueue(operations: [Operation], in _: OperationMode) {
        lock.lock()
        held.append(contentsOf: operations)
        lock.unlock()
    }
}
