import BigInt
import RobinHood
import SSFModels
import Web3
import XCTest
@testable import fearless

/// Balance subscriptions on Ethereum chains.
final class EthereumWalletRemoteSubscriptionTests: XCTestCase {
    /// Without an Ethereum connection the attach returned from inside its continuation without resuming it, so the
    /// caller waited forever. It now answers that there is no subscription.
    func testAttachWithoutAConnectionAnswersNil() {
        let registry = EthereumConnectionRegistry()
        let service = Self.service(registry: registry)
        let chainAsset = Self.chainAsset()
        let answered = XCTestExpectation(description: "the attach returns")
        let result = SubscriptionIdBox()

        Task {
            let subscriptionId = await service.attachToAccountInfo(
                of: Data(repeating: 1, count: 20), chainAsset: chainAsset, queue: nil, closure: nil
            )
            result.store(subscriptionId)
            answered.fulfill()
        }

        XCTAssertEqual(XCTWaiter.wait(for: [answered], timeout: 5), .completed, "the caller is not left waiting")
        XCTAssertNil(result.value)
        XCTAssertEqual(registry.requestedChainIds, [chainAsset.chain.chainId])
    }

    /// Detaching read the third part of the key "assetId:chainId:accountIdHex", the account, as the chain id, so it
    /// looked for a connection that does not exist and the node subscription was never ended.
    func testDetachLooksUpTheConnectionOfTheSubscriptionsChain() {
        let registry = EthereumConnectionRegistry()
        let service = Self.service(registry: registry)
        let chainAsset = Self.chainAsset()
        let key = chainAsset.uniqueKey(accountId: Data(repeating: 0xAB, count: 20))

        service.detachFromAccountInfo(for: "0x1", chainAssetKey: key, queue: nil, closure: nil)

        XCTAssertEqual(registry.requestedChainIds, [chainAsset.chain.chainId])
    }

    // MARK: - Fixtures

    static func service(registry: ChainRegistryProtocol) -> EthereumWalletRemoteSubscriptionService {
        let repository = AnyDataProviderRepository(RecordingStorageWrapperRepository())
        return EthereumWalletRemoteSubscriptionService(
            chainRegistry: registry,
            logger: Logger.shared,
            repository: repository,
            operationManager: OperationManager(),
            repositoryWrapper: BalanceRepositoryCacheWrapper(
                logger: Logger.shared,
                repository: repository,
                operationManager: OperationManager()
            )
        )
    }

    static func chainAsset() -> ChainAsset {
        let asset = AssetModel(
            id: "eth", name: "ETH", symbol: "ETH", precision: 18, isUtility: true, isNative: true, ethereumType: .normal
        )
        let chain = ChainModel(
            rank: nil, disabled: false, chainId: "1", parentId: nil, paraId: nil, name: "Ethereum",
            assets: [asset], xcm: nil, nodes: [], addressPrefix: 1, icon: nil, options: [.ethereum],
            iosMinAppVersion: nil, identityChain: nil
        )
        return ChainAsset(chain: chain, asset: asset)
    }
}

/// A registry with no Ethereum connections that records which chains were asked for.
final class EthereumConnectionRegistry: ChainRegistryProtocolStub, @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [ChainModel.Id] = []

    var requestedChainIds: [ChainModel.Id] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }

    override func getEthereumConnection(for chainId: ChainModel.Id) -> Web3.Eth? {
        lock.lock()
        requests.append(chainId)
        lock.unlock()
        return nil
    }
}

private final class SubscriptionIdBox {
    private let lock = NSLock()
    private var stored: String?

    var value: String? {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func store(_ value: String?) {
        lock.lock()
        stored = value
        lock.unlock()
    }
}
