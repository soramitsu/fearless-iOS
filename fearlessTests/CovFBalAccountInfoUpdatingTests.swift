import Foundation
import RobinHood
import SSFModels
import XCTest
@testable import fearless

final class CovFBalWalletSubscriptionStub: WalletRemoteSubscriptionServiceProtocol {
    var attachCallbackResult: Result<Void, Error>?
    var detachResult: Result<Void, Error> = .success(())
    var onAttach: (() -> Void)?
    var onDetach: (() -> Void)?

    private let lock = NSLock()
    private var storedAccountIds: [Data] = []
    private var storedChainAssets: [ChainAsset] = []
    private var storedDetachedIds: [String] = []
    private var storedDetachedKeys: [ChainAssetKey] = []

    var attachedAccountIds: [Data] {
        lock.lock()
        defer { lock.unlock() }
        return storedAccountIds
    }

    var attachedChainAssets: [ChainAsset] {
        lock.lock()
        defer { lock.unlock() }
        return storedChainAssets
    }

    var detachedIds: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storedDetachedIds
    }

    var detachedKeys: [ChainAssetKey] {
        lock.lock()
        defer { lock.unlock() }
        return storedDetachedKeys
    }

    func attachToAccountInfo(
        of accountId: Data,
        chainAsset: ChainAsset,
        queue _: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) async -> String? {
        lock.lock()
        storedAccountIds.append(accountId)
        storedChainAssets.append(chainAsset)
        let subscriptionId = "sub-\(storedChainAssets.count)"
        let callbackResult = attachCallbackResult
        let callback = onAttach
        lock.unlock()
        if let callbackResult {
            closure?(callbackResult)
        }
        callback?()
        return subscriptionId
    }

    func detachFromAccountInfo(
        for subscriptionId: String,
        chainAssetKey: ChainAssetKey,
        queue _: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) {
        lock.lock()
        storedDetachedIds.append(subscriptionId)
        storedDetachedKeys.append(chainAssetKey)
        let result = detachResult
        let callback = onDetach
        lock.unlock()
        closure?(result)
        callback?()
    }
}

final class CovFBalAccountInfoHarness {
    let registry = CovFBalRegistry()
    let substrate = CovFBalWalletSubscriptionStub()
    let ethereum = CovFBalWalletSubscriptionStub()
    let logger = CovFBalLogger()
    let events = CovFBalEventCenter()

    func makeService(wallet: fearless.MetaAccountModel) -> AccountInfoUpdatingService {
        AccountInfoUpdatingService(
            selectedAccount: wallet,
            chainRegistry: registry,
            remoteSubscriptionService: substrate,
            ethereumRemoteSubscriptionService: ethereum,
            logger: logger,
            eventCenter: events
        )
    }

    /// Sets the service up, inserts `chain` as an available chain and waits until its subscription is stored.
    func subscribe(_ service: AccountInfoUpdatingService, to chain: ChainModel, testCase: XCTestCase) {
        registry.availableIds = (registry.availableIds ?? []).union([chain.chainId])
        service.setup()
        let attached = testCase.expectation(description: "attached \(chain.chainId)")
        attached.expectedFulfillmentCount = chain.assets.count
        substrate.onAttach = { attached.fulfill() }
        registry.deliver([.insert(newItem: chain)])
        testCase.wait(for: [attached], timeout: 5)
        substrate.onAttach = nil
        covFBalSettle()
    }

    static func walletWithoutEthereum() -> fearless.MetaAccountModel {
        AccountGenerator.generateMetaAccount().replacingEthereumAddress(nil).replacingEthereumPublicKey(nil)
    }
}

final class CovFBalAccountInfoUpdatingTests: XCTestCase {
    func testSetupObservesChainsAndEventsAndThrottleStopsObservingChains() {
        let harness = CovFBalAccountInfoHarness()
        let service = harness.makeService(wallet: AccountGenerator.generateMetaAccount())

        service.setup()

        XCTAssertTrue(harness.registry.hasChainsSubscription)
        XCTAssertEqual(harness.events.addedObservers, 1)
        XCTAssertEqual(harness.registry.chainsUnsubscribeCount, 0)

        service.throttle()

        XCTAssertEqual(harness.registry.chainsUnsubscribeCount, 1)
    }

    func testInsertedAvailableChainAttachesTheWalletsSubstrateAccount() throws {
        let harness = CovFBalAccountInfoHarness()
        let wallet = AccountGenerator.generateMetaAccount()
        let chainAsset = CovFBalChains.chainAsset()
        let service = harness.makeService(wallet: wallet)

        let accountId = try XCTUnwrap(wallet.substrateAccountId)

        harness.subscribe(service, to: chainAsset.chain, testCase: self)

        XCTAssertEqual(harness.substrate.attachedAccountIds, [accountId])
        XCTAssertEqual(harness.substrate.attachedChainAssets, [chainAsset])
        XCTAssertTrue(harness.ethereum.attachedChainAssets.isEmpty)
        XCTAssertTrue(harness.logger.errors.isEmpty)
    }

    func testChainsWithoutVisibleAccountOrAvailabilityAreStoredUntilTheWalletChanges() throws {
        let harness = CovFBalAccountInfoHarness()
        let hidden = CovFBalChains.chainAsset()
        let unavailable = CovFBalChains.chainAsset()
        harness.registry.availableIds = [hidden.chain.chainId]
        let service = harness.makeService(wallet: CovFBalWallets.empty())
        service.setup()

        harness.registry.deliver([.insert(newItem: hidden.chain), .insert(newItem: unavailable.chain)])
        covFBalSettle()

        XCTAssertTrue(harness.substrate.attachedChainAssets.isEmpty)

        let wallet = AccountGenerator.generateMetaAccount()
        let accountId = try XCTUnwrap(wallet.substrateAccountId)
        let attached = expectation(description: "stored chains attach for the new wallet")
        attached.expectedFulfillmentCount = 2
        harness.substrate.onAttach = { attached.fulfill() }

        service.update(selectedMetaAccount: wallet)
        wait(for: [attached], timeout: 5)

        XCTAssertEqual(service.selectedMetaAccount, wallet)
        XCTAssertEqual(
            Set(harness.substrate.attachedChainAssets.map { $0.chain.chainId }),
            [hidden.chain.chainId, unavailable.chain.chainId]
        )
        XCTAssertEqual(Set(harness.substrate.attachedAccountIds), [accountId])
        XCTAssertTrue(harness.substrate.detachedIds.isEmpty)
    }

    func testUpdatedChainAttachesAndDeletionOfUnknownKeyIsReported() {
        let harness = CovFBalAccountInfoHarness()
        let chainAsset = CovFBalChains.chainAsset()
        let service = harness.makeService(wallet: AccountGenerator.generateMetaAccount())
        service.setup()
        let attached = expectation(description: "updated chain attaches")
        harness.substrate.onAttach = { attached.fulfill() }

        harness.registry.deliver([.update(newItem: chainAsset.chain)])
        wait(for: [attached], timeout: 5)

        XCTAssertEqual(harness.substrate.attachedChainAssets, [chainAsset])

        harness.registry.deliver([.delete(deletedIdentifier: "cov-f-bal-missing")])

        XCTAssertTrue(harness.logger.errors.contains { $0.contains("cov-f-bal-missing") })
        XCTAssertTrue(harness.substrate.detachedIds.isEmpty)
    }

    func testChainWithoutWalletAccountIsReportedAndEthereumChainsAreNotAttached() {
        let ethereumAsset = CovFBalChains.chainAsset(
            CovFBalChains.asset(type: nil, ethereumType: .normal), options: [.ethereum]
        )
        let harness = CovFBalAccountInfoHarness()
        let accountless = harness.makeService(wallet: CovFBalAccountInfoHarness.walletWithoutEthereum())
        accountless.setup()
        let reported = expectation(description: "missing account reported")
        reported.assertForOverFulfill = false
        harness.logger.onError = { message in
            if message.contains(ethereumAsset.chain.chainId) {
                reported.fulfill()
            }
        }

        harness.registry.deliver([.update(newItem: ethereumAsset.chain)])
        wait(for: [reported], timeout: 5)

        let ethereumHarness = CovFBalAccountInfoHarness()
        let ethereumService = ethereumHarness.makeService(wallet: AccountGenerator.generateMetaAccount())
        ethereumService.setup()
        ethereumHarness.registry.deliver([.update(newItem: ethereumAsset.chain)])
        covFBalSettle()

        XCTAssertTrue(harness.substrate.attachedChainAssets.isEmpty)
        XCTAssertTrue(harness.ethereum.attachedChainAssets.isEmpty)
        XCTAssertTrue(ethereumHarness.substrate.attachedChainAssets.isEmpty)
        XCTAssertTrue(ethereumHarness.ethereum.attachedChainAssets.isEmpty)
        XCTAssertTrue(ethereumHarness.logger.errors.isEmpty)
    }

    func testWalletChangeDetachesTheOldSubscriptionAndAttachesTheNewAccount() throws {
        let harness = CovFBalAccountInfoHarness()
        let first = AccountGenerator.generateMetaAccount()
        let second = AccountGenerator.generateMetaAccount()
        let chainAsset = CovFBalChains.chainAsset()
        let service = harness.makeService(wallet: first)
        harness.subscribe(service, to: chainAsset.chain, testCase: self)
        let reattached = expectation(description: "new wallet attached")
        harness.substrate.onAttach = { reattached.fulfill() }

        service.update(selectedMetaAccount: second)
        wait(for: [reattached], timeout: 5)

        let firstKey = chainAsset.uniqueKey(accountId: try XCTUnwrap(first.substrateAccountId))
        let secondAccountId = try XCTUnwrap(second.substrateAccountId)
        XCTAssertEqual(harness.substrate.detachedIds, ["sub-1"])
        XCTAssertEqual(harness.substrate.detachedKeys, [firstKey])
        XCTAssertTrue(harness.logger.infos.contains { $0.contains(firstKey) })
        XCTAssertEqual(harness.substrate.attachedAccountIds.last, secondAccountId)
    }

    func testFailedDetachWhileRemovingASubscriptionIsLogged() throws {
        let harness = CovFBalAccountInfoHarness()
        let wallet = AccountGenerator.generateMetaAccount()
        let chainAsset = CovFBalChains.chainAsset()
        let service = harness.makeService(wallet: wallet)
        harness.subscribe(service, to: chainAsset.chain, testCase: self)
        harness.substrate.detachResult = .failure(CovFBalError.expected)
        let key = chainAsset.uniqueKey(accountId: try XCTUnwrap(wallet.substrateAccountId))

        harness.registry.deliver([.delete(deletedIdentifier: key)])

        XCTAssertEqual(harness.substrate.detachedKeys, [key])
        XCTAssertTrue(harness.logger.errors.contains { $0.contains("Faced with error") })
        XCTAssertTrue(harness.logger.infos.isEmpty)
    }
}

final class CovFBalAccountInfoResubscriptionTests: XCTestCase {
    func testChainsUpdatedEventResubscribesAndPublishesTheUpdate() throws {
        let harness = CovFBalAccountInfoHarness()
        let chainAsset = CovFBalChains.chainAsset()
        let service = harness.makeService(wallet: AccountGenerator.generateMetaAccount())
        harness.subscribe(service, to: chainAsset.chain, testCase: self)
        harness.substrate.attachCallbackResult = .success(())
        let published = expectation(description: "update published")
        harness.events.onNotify = { _ in published.fulfill() }

        service.processChainsUpdated(event: ChainsUpdatedEvent(updatedChains: [chainAsset.chain]))
        wait(for: [published], timeout: 5)

        let event = try XCTUnwrap(harness.events.events.first as? WalletRemoteSubscriptionWasUpdatedEvent)
        XCTAssertEqual(event.chainAsset, chainAsset)
        XCTAssertEqual(harness.substrate.detachedIds, ["sub-1"])
        XCTAssertEqual(harness.substrate.attachedChainAssets.count, 2)
    }

    func testRuntimeSnapshotResubscriptionFailureIsLoggedWithoutPublishing() {
        let harness = CovFBalAccountInfoHarness()
        let chainAsset = CovFBalChains.chainAsset()
        let service = harness.makeService(wallet: AccountGenerator.generateMetaAccount())
        harness.subscribe(service, to: chainAsset.chain, testCase: self)
        harness.substrate.attachCallbackResult = .failure(CovFBalError.expected)
        let logged = expectation(description: "failure logged")
        logged.assertForOverFulfill = false
        harness.logger.onError = { message in
            if message.contains("Can't add subscription") {
                logged.fulfill()
            }
        }

        service.processRuntimeSnapshorReady(event: RuntimeSnapshotReady(chainModel: chainAsset.chain))
        wait(for: [logged], timeout: 5)

        XCTAssertTrue(harness.events.events.isEmpty)
        XCTAssertEqual(harness.substrate.detachedIds, ["sub-1"])
        XCTAssertEqual(harness.substrate.attachedChainAssets.count, 2)
    }

    func testUpdateWithoutStoredSubscriptionIsReportedAndAccountlessChainIsSkipped() {
        let harness = CovFBalAccountInfoHarness()
        let substrateAsset = CovFBalChains.chainAsset()
        let ethereumAsset = CovFBalChains.chainAsset(CovFBalChains.asset(type: nil, ethereumType: .normal), options: [.ethereum])
        let service = harness.makeService(wallet: CovFBalAccountInfoHarness.walletWithoutEthereum())

        service.processChainsUpdated(event: ChainsUpdatedEvent(updatedChains: [substrateAsset.chain, ethereumAsset.chain]))

        XCTAssertEqual(harness.logger.errors.count, 1)
        XCTAssertTrue(harness.logger.errors.first?.contains("Expected to update subscription") == true)
        XCTAssertTrue(harness.substrate.detachedIds.isEmpty)
        XCTAssertTrue(harness.ethereum.detachedIds.isEmpty)
    }

    func testSubscriptionOfAChainThatTurnedEthereumIsDetachedFromTheServiceThatAttachedIt() {
        let chainId = covFBalChainId()
        let accountId = Data(repeating: 7, count: 32)
        let asset = CovFBalChains.asset()
        let substrateChain = CovFBalChains.chain(id: chainId, assets: [asset])
        let ethereumChain = CovFBalChains.chain(id: chainId, assets: [asset], options: [.ethereum])
        let harness = CovFBalAccountInfoHarness()
        let service = harness.makeService(wallet: CovFBalWallets.withChainAccount(chainId: chainId, accountId: accountId))
        harness.subscribe(service, to: substrateChain, testCase: self)
        let detached = expectation(description: "the substrate service, which holds the subscription, detaches it")
        harness.substrate.onDetach = { detached.fulfill() }

        service.processChainsUpdated(event: ChainsUpdatedEvent(updatedChains: [ethereumChain]))
        wait(for: [detached], timeout: 5)
        covFBalSettle()

        let key = ChainAsset(chain: substrateChain, asset: asset).uniqueKey(accountId: accountId)
        XCTAssertEqual(harness.substrate.attachedAccountIds, [accountId])
        XCTAssertEqual(harness.substrate.detachedIds, ["sub-1"])
        XCTAssertEqual(harness.substrate.detachedKeys, [key])
        XCTAssertTrue(harness.ethereum.detachedIds.isEmpty)
        XCTAssertTrue(harness.ethereum.attachedChainAssets.isEmpty)
        XCTAssertEqual(harness.substrate.attachedChainAssets.count, 1)
    }

    func testReleasedServiceDetachesItsRemainingSubscriptions() throws {
        let harness = CovFBalAccountInfoHarness()
        let wallet = AccountGenerator.generateMetaAccount()
        let chainAsset = CovFBalChains.chainAsset()
        let key = chainAsset.uniqueKey(accountId: try XCTUnwrap(wallet.substrateAccountId))
        var service: AccountInfoUpdatingService? = harness.makeService(wallet: wallet)
        if let created = service {
            harness.subscribe(created, to: chainAsset.chain, testCase: self)
        }
        weak var weakService = service
        XCTAssertNotNil(weakService)

        service = nil

        XCTAssertTrue(covFBalEventually { weakService == nil })
        XCTAssertTrue(covFBalEventually { harness.substrate.detachedIds.count == 1 })
        XCTAssertEqual(harness.substrate.detachedIds, ["sub-1"])
        XCTAssertEqual(harness.substrate.detachedKeys, [key])
    }
}
