import BigInt
import Foundation
import RobinHood
import SSFModels
import Web3
import XCTest
@testable import fearless

/// Web3 provider that answers balance reads and new-head subscriptions locally.
final class CovFBalWeb3Provider: Web3BidirectionalProvider {
    static let subscriptionId = "cov-f-bal-sub"
    /// 100 wei.
    var balanceHex = "0x64"
    /// A 32-byte ABI word holding 512.
    var callHex = "0x" + String(repeating: "0", count: 61) + "200"
    var failsBalance = false
    var subscriptionError: Error?

    private let lock = NSLock()
    private var storedMethods: [String] = []
    private var storedUnsubscribed: [String] = []
    private var storedEvent: ((Error) -> Void)?

    var methods: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storedMethods
    }

    var unsubscribed: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storedUnsubscribed
    }

    func send<Params, Result>(request: RPCRequest<Params>, response: @escaping (Web3Response<Result>) -> Void) {
        lock.lock()
        storedMethods.append(request.method)
        lock.unlock()
        let value: String
        switch request.method {
        case "eth_getBalance" where !failsBalance:
            value = balanceHex
        case "eth_call":
            value = callHex
        default:
            response(Web3Response(error: CovFBalError.expected))
            return
        }
        do {
            let data = try JSONEncoder().encode(value)
            response(Web3Response(status: .success(try JSONDecoder().decode(Result.self, from: data))))
        } catch {
            response(Web3Response(error: error))
        }
    }

    func subscribe<Params, Result>(
        request _: RPCRequest<Params>,
        response: @escaping (Web3Response<String>) -> Void,
        onEvent: @escaping (Web3Response<Result>) -> Void
    ) {
        lock.lock()
        storedEvent = { onEvent(Web3Response(error: $0)) }
        let error = subscriptionError
        lock.unlock()
        if let error {
            response(Web3Response(error: error))
        } else {
            response(Web3Response(status: .success(Self.subscriptionId)))
        }
    }

    func unsubscribe(subscriptionId: String, completion: @escaping (Bool) -> Void) {
        lock.lock()
        storedUnsubscribed.append(subscriptionId)
        lock.unlock()
        completion(true)
    }

    /// Delivers a new-head event; the service refreshes the balance on any event.
    func emitHead() {
        lock.lock()
        let event = storedEvent
        lock.unlock()
        event?(CovFBalError.expected)
    }
}

/// Provider without subscription support: `subscribeToNewHeads` and `unsubscribe` throw.
final class CovFBalPlainWeb3Provider: Web3Provider {
    func send<Params, Result>(request _: RPCRequest<Params>, response: @escaping (Web3Response<Result>) -> Void) {
        response(Web3Response(error: CovFBalError.expected))
    }
}

/// Account balance repository that reports every saved wrapper.
final class CovFBalBalanceRepository: DataProviderRepositoryProtocol {
    typealias Model = AccountInfoStorageWrapper

    private let lock = NSLock()
    private var storedSaved: [AccountInfoStorageWrapper] = []
    var onSave: (() -> Void)?

    var saved: [AccountInfoStorageWrapper] {
        lock.lock()
        defer { lock.unlock() }
        return storedSaved
    }

    func fetchOperation(by _: @escaping () throws -> [String], options _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { [] }
    }

    func fetchOperation(by _: @escaping () throws -> String, options _: RepositoryFetchOptions) -> BaseOperation<Model?> {
        ClosureOperation { nil }
    }

    func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { [] }
    }

    func fetchOperation(by _: RepositorySliceRequest, options _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { [] }
    }

    func saveOperation(_ updates: @escaping () throws -> [Model], _ deletes: @escaping () throws -> [String]) -> BaseOperation<Void> {
        ClosureOperation {
            _ = try deletes()
            let items = try updates()
            self.lock.lock()
            self.storedSaved.append(contentsOf: items)
            let callback = self.onSave
            self.lock.unlock()
            callback?()
        }
    }

    func saveBatchOperation(_ updates: @escaping () throws -> [Model], _ deletes: @escaping () throws -> [String]) -> BaseOperation<Void> {
        saveOperation(updates, deletes)
    }

    func replaceOperation(_ items: @escaping () throws -> [Model]) -> BaseOperation<Void> {
        saveOperation(items, { [] })
    }

    func fetchCountOperation() -> BaseOperation<Int> { ClosureOperation { 0 } }
    func deleteAllOperation() -> BaseOperation<Void> { ClosureOperation {} }
}

final class CovFBalEthereumHarness {
    static let contract = "0x2222222222222222222222222222222222222222"
    let provider = CovFBalWeb3Provider()
    let registry = CovFBalRegistry()
    let repository = CovFBalBalanceRepository()
    let logger = CovFBalLogger()
    lazy var web3 = Web3(provider: provider)
    let accountId = Data(repeating: 0x11, count: 20)

    lazy var service: EthereumWalletRemoteSubscriptionService = makeService()

    init(connected: Bool = true) {
        if connected {
            registry.ethereum = web3.eth
        }
    }

    private func makeService() -> EthereumWalletRemoteSubscriptionService {
        let anyRepository = AnyDataProviderRepository(repository)
        let wrapper = BalanceRepositoryCacheWrapper(logger: logger, repository: anyRepository, operationManager: OperationManager())
        return EthereumWalletRemoteSubscriptionService(
            chainRegistry: registry,
            logger: logger,
            repository: anyRepository,
            operationManager: OperationManager(),
            repositoryWrapper: wrapper
        )
    }

    static func chainAsset(type: EthereumAssetType?, assetId: String = CovFBalEthereumHarness.contract) -> ChainAsset {
        CovFBalChains.chainAsset(CovFBalChains.asset(id: assetId, type: nil, ethereumType: type), options: [.ethereum])
    }

    func localKey(for chainAsset: ChainAsset) throws -> String {
        try LocalStorageKeyFactory().createFromStoragePath(.account, chainAssetKey: chainAsset.uniqueKey(accountId: accountId))
    }
}

final class CovFBalEthereumSubscriptionTests: XCTestCase {
    func testNativeAttachSavesTheBalanceAndRefreshesItOnEveryNewHead() async throws {
        let harness = CovFBalEthereumHarness()
        let chainAsset = CovFBalEthereumHarness.chainAsset(type: .normal)
        let saved = expectation(description: "balance saved")
        harness.repository.onSave = { saved.fulfill() }

        let subscriptionId = await harness.service.attachToAccountInfo(
            of: harness.accountId, chainAsset: chainAsset, queue: nil, closure: nil
        )
        await fulfillment(of: [saved], timeout: 5)

        XCTAssertEqual(subscriptionId, CovFBalWeb3Provider.subscriptionId)
        XCTAssertEqual(harness.registry.ethereumRequests, [chainAsset.chain.chainId])
        XCTAssertEqual(harness.provider.methods, ["eth_getBalance"])
        let localKey = try harness.localKey(for: chainAsset)
        let wrapper = try XCTUnwrap(harness.repository.saved.first)
        let balance = try JSONDecoder().decode(AccountInfo.self, from: wrapper.data)
        XCTAssertEqual(wrapper.identifier, localKey)
        XCTAssertEqual(balance, AccountInfo(ethBalance: 100))

        let refreshed = expectation(description: "new balance saved")
        harness.repository.onSave = { refreshed.fulfill() }
        harness.provider.balanceHex = "0xc8"
        harness.provider.emitHead()
        await fulfillment(of: [refreshed], timeout: 5)

        XCTAssertEqual(harness.provider.methods, ["eth_getBalance", "eth_getBalance"])
        let refreshedWrapper = try XCTUnwrap(harness.repository.saved.last)
        let refreshedBalance = try JSONDecoder().decode(AccountInfo.self, from: refreshedWrapper.data)
        XCTAssertEqual(refreshedWrapper.identifier, localKey)
        XCTAssertEqual(refreshedBalance, AccountInfo(ethBalance: 200))
    }

    func testTokenAttachReadsTheContractBalance() async throws {
        for type in [EthereumAssetType.erc20, .bep20] {
            let harness = CovFBalEthereumHarness()
            let chainAsset = CovFBalEthereumHarness.chainAsset(type: type)
            let saved = expectation(description: "token balance saved")
            harness.repository.onSave = { saved.fulfill() }

            let subscriptionId = await harness.service.attachToAccountInfo(
                of: harness.accountId, chainAsset: chainAsset, queue: nil, closure: nil
            )
            await fulfillment(of: [saved], timeout: 5)

            XCTAssertEqual(subscriptionId, CovFBalWeb3Provider.subscriptionId)
            XCTAssertEqual(harness.provider.methods, ["eth_call"])
            let localKey = try harness.localKey(for: chainAsset)
            let wrapper = try XCTUnwrap(harness.repository.saved.first)
            let balance = try JSONDecoder().decode(AccountInfo.self, from: wrapper.data)
            XCTAssertEqual(wrapper.identifier, localKey)
            XCTAssertEqual(balance, AccountInfo(ethBalance: 512))
        }
    }

    func testUnreadableBalancesStillSubscribeWithoutSaving() async {
        let untyped = CovFBalEthereumHarness()
        let untypedId = await untyped.service.attachToAccountInfo(
            of: untyped.accountId, chainAsset: CovFBalEthereumHarness.chainAsset(type: nil), queue: nil, closure: nil
        )

        let badContract = CovFBalEthereumHarness()
        let badContractId = await badContract.service.attachToAccountInfo(
            of: badContract.accountId,
            chainAsset: CovFBalEthereumHarness.chainAsset(type: .erc20, assetId: "not-a-contract"),
            queue: nil,
            closure: nil
        )

        let longAccount = CovFBalEthereumHarness()
        let longAccountId = await longAccount.service.attachToAccountInfo(
            of: Data(repeating: 0x22, count: 32), chainAsset: CovFBalEthereumHarness.chainAsset(type: .normal), queue: nil, closure: nil
        )

        let rejected = CovFBalEthereumHarness()
        rejected.provider.failsBalance = true
        let rejectedId = await rejected.service.attachToAccountInfo(
            of: rejected.accountId, chainAsset: CovFBalEthereumHarness.chainAsset(type: .normal), queue: nil, closure: nil
        )

        for subscriptionId in [untypedId, badContractId, longAccountId, rejectedId] {
            XCTAssertEqual(subscriptionId, CovFBalWeb3Provider.subscriptionId)
        }
        XCTAssertTrue(untyped.provider.methods.isEmpty)
        XCTAssertTrue(badContract.provider.methods.isEmpty)
        XCTAssertTrue(longAccount.provider.methods.isEmpty)
        XCTAssertEqual(rejected.provider.methods, ["eth_getBalance"])
        for harness in [untyped, badContract, longAccount, rejected] {
            XCTAssertTrue(harness.repository.saved.isEmpty)
        }
    }

    func testRejectedOrUnsupportedSubscriptionReturnsNoIdentifier() async {
        let rejected = CovFBalEthereumHarness()
        rejected.provider.subscriptionError = CovFBalError.expected
        let rejectedId = await rejected.service.attachToAccountInfo(
            of: rejected.accountId, chainAsset: CovFBalEthereumHarness.chainAsset(type: nil), queue: nil, closure: nil
        )

        let plain = CovFBalEthereumHarness(connected: false)
        plain.registry.ethereum = Web3(provider: CovFBalPlainWeb3Provider()).eth
        let plainId = await plain.service.attachToAccountInfo(
            of: plain.accountId, chainAsset: CovFBalEthereumHarness.chainAsset(type: nil), queue: nil, closure: nil
        )

        XCTAssertNil(rejectedId)
        XCTAssertNil(plainId)
        XCTAssertTrue(rejected.logger.errors.isEmpty)
        XCTAssertTrue(plain.logger.errors.contains { $0.contains("attachToAccountInfo") })
    }

    func testDetachUnsubscribesThroughTheConnectionAndIgnoresUnusableKeys() {
        let harness = CovFBalEthereumHarness()
        let chainAsset = CovFBalEthereumHarness.chainAsset(type: .normal)

        harness.service.detachFromAccountInfo(
            for: CovFBalWeb3Provider.subscriptionId,
            chainAssetKey: chainAsset.uniqueKey(accountId: harness.accountId),
            queue: nil,
            closure: nil
        )
        harness.service.detachFromAccountInfo(for: "other", chainAssetKey: "no-separators", queue: nil, closure: nil)

        XCTAssertEqual(harness.provider.unsubscribed, [CovFBalWeb3Provider.subscriptionId])
        XCTAssertEqual(harness.registry.ethereumRequests.count, 1)

        let disconnected = CovFBalEthereumHarness(connected: false)
        disconnected.service.detachFromAccountInfo(
            for: "any", chainAssetKey: chainAsset.uniqueKey(accountId: harness.accountId), queue: nil, closure: nil
        )
        XCTAssertTrue(disconnected.provider.unsubscribed.isEmpty)
        XCTAssertTrue(disconnected.logger.errors.isEmpty)

        let plain = CovFBalEthereumHarness(connected: false)
        plain.registry.ethereum = Web3(provider: CovFBalPlainWeb3Provider()).eth
        plain.service.detachFromAccountInfo(
            for: "any", chainAssetKey: chainAsset.uniqueKey(accountId: harness.accountId), queue: nil, closure: nil
        )
        XCTAssertTrue(plain.logger.errors.contains { $0.contains("detachFromAccountInfo") })
    }
}
