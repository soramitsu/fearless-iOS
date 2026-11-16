import Foundation
import RobinHood
import SSFModels
import SSFUtils
import XCTest
@testable import fearless

/// Records one subscription completion.
final class CovFBalCompletion {
    let expectation: XCTestExpectation
    private let lock = NSLock()
    private var stored: Result<Void, Error>?

    init(_ testCase: XCTestCase, _ description: String) {
        expectation = testCase.expectation(description: description)
    }

    var closure: RemoteSubscriptionClosure {
        { [self] result in
            lock.lock()
            stored = result
            lock.unlock()
            expectation.fulfill()
        }
    }

    var succeeded: Bool {
        lock.lock()
        defer { lock.unlock() }
        if case .success = stored {
            return true
        }
        return false
    }

    var error: Error? {
        lock.lock()
        defer { lock.unlock() }
        if case let .failure(error) = stored {
            return error
        }
        return nil
    }
}

final class CovFBalCapturingOperations: OperationManagerProtocol {
    private(set) var operations: [Operation] = []

    func enqueue(operations: [Operation], in _: OperationMode) {
        self.operations.append(contentsOf: operations)
    }
}

final class CovFBalRemoteHarness {
    let registry = CovFBalRegistry()
    let engine = CovFBalEngine()
    let logger = CovFBalLogger()
    let queue = DispatchQueue(label: "cov-f-bal.remote-subscription")

    init(connected: Bool = true) throws {
        registry.runtime = try CovFBalRuntime.make()
        if connected {
            registry.connection = engine
        }
    }

    func crowdloan(operationManager: OperationManagerProtocol = OperationManager()) -> CrowdloanRemoteSubscriptionService {
        CrowdloanRemoteSubscriptionService(
            chainRegistry: registry,
            repository: AnyDataProviderRepository(CovFRepository<ChainStorageItem>()),
            operationManager: operationManager,
            logger: logger
        )
    }

    func wallet() -> WalletRemoteSubscriptionService {
        WalletRemoteSubscriptionService(
            chainRegistry: registry,
            repository: AnyDataProviderRepository(CovFRepository<AccountInfoStorageWrapper>()),
            operationManager: OperationManager(),
            logger: logger
        )
    }

    func staking() -> StakingRemoteSubscriptionService {
        StakingRemoteSubscriptionService(
            chainRegistry: registry,
            repository: AnyDataProviderRepository(CovFRepository<ChainStorageItem>()),
            operationManager: OperationManager(),
            logger: logger
        )
    }
}

final class CovFBalRemoteSubscriptionTests: XCTestCase {
    func testCrowdloanSharesOneBlockNumberSubscriptionUntilTheLastSubscriberLeaves() throws {
        let harness = try CovFBalRemoteHarness()
        let service = harness.crowdloan()
        let chainId = covFBalChainId()
        let blockNumberKey = try CovFBalRuntime.prefix("System", "Number")

        let first = try XCTUnwrap(service.attach(for: chainId))
        let attached = CovFBalCompletion(self, "second subscriber attached")
        let second = try XCTUnwrap(service.attach(for: chainId, runningCompletionIn: .main, completion: attached.closure))
        wait(for: [attached.expectation], timeout: 5)

        XCTAssertTrue(attached.succeeded)
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(harness.engine.subscribedKeys, [[blockNumberKey]])

        service.detach(for: first, chainId: chainId)
        XCTAssertTrue(harness.engine.unsubscribed.isEmpty)

        let detached = CovFBalCompletion(self, "last subscriber detached")
        service.detach(for: second, chainId: chainId, runningCompletionIn: .main, completion: detached.closure)
        let unknown = CovFBalCompletion(self, "unknown subscriber detached")
        service.detach(for: UUID(), chainId: chainId, runningCompletionIn: .main, completion: unknown.closure)
        wait(for: [detached.expectation, unknown.expectation], timeout: 5)

        XCTAssertTrue(detached.succeeded)
        XCTAssertTrue(unknown.succeeded)
        XCTAssertTrue(covFBalEventually { harness.engine.unsubscribed.count == 1 })

        let reattached = CovFBalCompletion(self, "fresh subscription")
        _ = service.attach(for: chainId, runningCompletionIn: .main, completion: reattached.closure)
        wait(for: [reattached.expectation], timeout: 5)

        XCTAssertTrue(reattached.succeeded)
        XCTAssertEqual(harness.engine.subscribedKeys, [[blockNumberKey], [blockNumberKey]])

        service.handleSubscriptionInitResult(nil, cacheKey: "cov-f-bal-missing")
        XCTAssertEqual(harness.engine.subscribedKeys.count, 2)
    }

    func testMissingConnectionFailsTheSubscriptionAndAllowsARetry() throws {
        let harness = try CovFBalRemoteHarness(connected: false)
        let service = harness.crowdloan()
        let chainId = covFBalChainId()

        let failed = CovFBalCompletion(self, "connection missing")
        _ = service.attach(for: chainId, runningCompletionIn: .main, completion: failed.closure)
        wait(for: [failed.expectation], timeout: 5)

        guard case .connectionUnavailable? = failed.error as? ChainRegistryError else {
            return XCTFail("Expected a missing connection, got \(String(describing: failed.error))")
        }
        XCTAssertTrue(harness.logger.errors.contains { $0.contains(chainId) })

        harness.registry.connection = harness.engine
        let retried = CovFBalCompletion(self, "retry after the connection appears")
        _ = service.attach(for: chainId, runningCompletionIn: .main, completion: retried.closure)
        wait(for: [retried.expectation], timeout: 5)

        XCTAssertTrue(retried.succeeded)
        XCTAssertEqual(harness.engine.subscribedKeys.count, 1)
    }

    func testReleasedServiceNeverBuildsItsContainer() throws {
        let harness = try CovFBalRemoteHarness()
        let operations = CovFBalCapturingOperations()
        var service: CrowdloanRemoteSubscriptionService? = harness.crowdloan(operationManager: operations)
        let answered = expectation(description: "a released service never answers")
        answered.isInverted = true

        _ = service?.attach(for: covFBalChainId(), runningCompletionIn: .main) { _ in answered.fulfill() }
        service = nil
        let queue = OperationQueue()
        queue.addOperations(operations.operations, waitUntilFinished: true)

        let target = try XCTUnwrap(operations.operations.last as? BaseOperation<StorageSubscriptionContainer>)
        guard case let .failure(error)? = target.result, case .unexpectedDependentResult? = error as? BaseOperationError else {
            return XCTFail("Expected the released service to fail the container, got \(String(describing: target.result))")
        }
        wait(for: [answered], timeout: 0.3)
        XCTAssertTrue(harness.engine.subscribedKeys.isEmpty)
    }

    func testRelaychainGlobalDataSubscribesToSixStakingItemsAndDetaches() throws {
        let harness = try CovFBalRemoteHarness()
        let service = harness.staking()
        let chainId = covFBalChainId()
        let expectedKeys = try [
            CovFBalRuntime.prefix("Staking", "ActiveEra"),
            CovFBalRuntime.prefix("Staking", "CurrentEra"),
            CovFBalRuntime.prefix("Balances", "TotalIssuance"),
            CovFBalRuntime.prefix("Staking", "MinNominatorBond"),
            CovFBalRuntime.prefix("Staking", "MaxNominatorsCount"),
            CovFBalRuntime.prefix("Staking", "CounterForNominators")
        ]

        let attached = CovFBalCompletion(self, "global data attached")
        let subscriptionId = try XCTUnwrap(
            service.attachToGlobalData(for: chainId, queue: .main, closure: attached.closure, stakingType: .relaychain)
        )
        wait(for: [attached.expectation], timeout: 5)

        XCTAssertTrue(attached.succeeded)
        XCTAssertEqual(harness.engine.subscribedKeys, [expectedKeys])

        let detached = CovFBalCompletion(self, "global data detached")
        service.detachFromGlobalData(for: subscriptionId, chainId: chainId, queue: .main, closure: detached.closure, stakingType: .relaychain)
        wait(for: [detached.expectation], timeout: 5)

        XCTAssertTrue(detached.succeeded)
        XCTAssertTrue(covFBalEventually { harness.engine.unsubscribed.count == 1 })
    }

    func testGlobalDataWithoutStakingTypeStillCompletes() throws {
        let harness = try CovFBalRemoteHarness()
        let service = harness.staking()

        let attached = CovFBalCompletion(self, "untyped global data attached")
        let subscriptionId = service.attachToGlobalData(for: covFBalChainId(), queue: .main, closure: attached.closure, stakingType: nil)
        wait(for: [attached.expectation], timeout: 5)

        XCTAssertNotNil(subscriptionId)
        XCTAssertTrue(attached.succeeded)
        XCTAssertNil(attached.error)
    }
}

final class CovFBalWalletRemoteSubscriptionTests: XCTestCase {
    private let accountId = Data(repeating: 3, count: 32)
    private let soraCurrency = "0x0200000000000000000000000000000000000000000000000000000000000000"

    func testSystemAccountAssetsSubscribeToTheAccountsStorageKey() async throws {
        let harness = try CovFBalRemoteHarness()
        let service = harness.wallet()
        let accountPrefix = try CovFBalRuntime.prefix("System", "Account")
        let assets = [
            CovFBalChains.chainAsset(CovFBalChains.asset(type: .normal)),
            CovFBalChains.chainAsset(CovFBalChains.asset(type: .equilibrium, currencyId: "0")),
            CovFBalChains.chainAsset(CovFBalChains.asset(type: .soraAsset, utility: true, currencyId: soraCurrency))
        ]

        for (index, chainAsset) in assets.enumerated() {
            let attached = CovFBalCompletion(self, "account asset \(index)")
            let subscriptionId = await service.attachToAccountInfo(
                of: accountId, chainAsset: chainAsset, queue: harness.queue, closure: attached.closure
            )
            await fulfillment(of: [attached.expectation], timeout: 5)

            XCTAssertNotNil(UUID(uuidString: subscriptionId ?? ""))
            XCTAssertTrue(attached.succeeded, "asset \(index): \(String(describing: attached.error))")
            let key = try XCTUnwrap(harness.engine.subscribedKeys.last?.first)
            XCTAssertTrue(key.hasPrefix(accountPrefix))
            XCTAssertTrue(key.hasSuffix(accountId.toHex()))
        }
        XCTAssertEqual(harness.engine.subscribedKeys.count, assets.count)
    }

    func testTokenAndAssetPalletAssetsFailWhenTheRuntimeLacksTheirStorage() async throws {
        let harness = try CovFBalRemoteHarness()
        let service = harness.wallet()
        let assets = [
            CovFBalChains.chainAsset(CovFBalChains.asset(type: .soraAsset, utility: false, currencyId: soraCurrency)),
            CovFBalChains.chainAsset(CovFBalChains.asset(type: .assets, currencyId: "1984")),
            CovFBalChains.chainAsset(CovFBalChains.asset(type: .ormlAsset, currencyId: "KAR"))
        ]

        for (index, chainAsset) in assets.enumerated() {
            let failed = CovFBalCompletion(self, "token asset \(index)")
            let subscriptionId = await service.attachToAccountInfo(
                of: accountId, chainAsset: chainAsset, queue: harness.queue, closure: failed.closure
            )
            await fulfillment(of: [failed.expectation], timeout: 5)

            XCTAssertNotNil(subscriptionId)
            XCTAssertEqual(failed.error as? fearless.StorageKeyEncodingOperationError, .invalidStoragePath, "asset \(index)")
        }
        XCTAssertTrue(harness.engine.subscribedKeys.isEmpty)
    }

    func testDetachEndsTheAccountSubscriptionAndIgnoresMalformedIdentifiers() async throws {
        let harness = try CovFBalRemoteHarness()
        let service = harness.wallet()
        let chainAsset = CovFBalChains.chainAsset()
        let key = chainAsset.uniqueKey(accountId: accountId)

        let attached = CovFBalCompletion(self, "attached")
        let maybeSubscriptionId = await service.attachToAccountInfo(
            of: accountId, chainAsset: chainAsset, queue: harness.queue, closure: attached.closure
        )
        await fulfillment(of: [attached.expectation], timeout: 5)
        let subscriptionId = try XCTUnwrap(maybeSubscriptionId)

        let ignored = expectation(description: "malformed identifier is ignored")
        ignored.isInverted = true
        service.detachFromAccountInfo(for: "not-a-uuid", chainAssetKey: key, queue: harness.queue) { _ in ignored.fulfill() }
        await fulfillment(of: [ignored], timeout: 0.3)

        let detached = CovFBalCompletion(self, "detached")
        service.detachFromAccountInfo(for: subscriptionId, chainAssetKey: key, queue: harness.queue, closure: detached.closure)
        await fulfillment(of: [detached.expectation], timeout: 5)

        XCTAssertTrue(attached.succeeded)
        XCTAssertTrue(detached.succeeded)
        XCTAssertEqual(harness.engine.subscribedKeys.count, 1)

        let reattached = CovFBalCompletion(self, "reattached")
        _ = await service.attachToAccountInfo(of: accountId, chainAsset: chainAsset, queue: harness.queue, closure: reattached.closure)
        await fulfillment(of: [reattached.expectation], timeout: 5)

        XCTAssertTrue(reattached.succeeded)
        XCTAssertEqual(harness.engine.subscribedKeys.count, 2)
    }
}
