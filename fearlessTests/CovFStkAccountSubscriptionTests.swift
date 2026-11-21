import Foundation
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import XCTest
@testable import fearless

final class CovFStkAccountSubscriptionTests: XCTestCase {
    private func stash(_ stash: Data, _ controller: Data) throws -> StashItem {
        try StashItem(stash: CovFStkFixtures.address(stash), controller: CovFStkFixtures.address(controller))
    }

    private func assertKeys(
        _ params: [String],
        match requests: [(fearless.StorageCodingPath, Data)],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        XCTAssertEqual(params.count, requests.count, file: file, line: line)
        for (hex, request) in zip(params, requests) {
            let key = try Data(hexStringSSF: hex)
            XCTAssertEqual(Data(key.prefix(32)), try CovFStkFixtures.storagePrefix(request.0), file: file, line: line)
            XCTAssertEqual(Data(key.suffix(32)), request.1, file: file, line: line)
        }
    }

    // MARK: Requests

    func testRequestsCoverForeignStashAndControllerBeforeStakingState() throws {
        let subscription = CovFStkHarness().makeBaseSubscription()
        let item = try stash(CovFStkFixtures.otherId, CovFStkFixtures.thirdId)

        let requests = try subscription.createRequest(for: item)

        let expectedPaths: [fearless.StorageCodingPath] = [
            .controller, .account, .stakingLedger, .account, .nominators, .validatorPrefs, .payee
        ]
        let other = CovFStkFixtures.otherId
        let third = CovFStkFixtures.thirdId
        XCTAssertEqual(requests.map { $0.0 }, expectedPaths)
        XCTAssertEqual(requests.map { $0.1 }, [other, other, third, third, other, other, other])
    }

    func testRequestsForOwnStashOnlyQueryStakingState() throws {
        let subscription = CovFStkHarness().makeBaseSubscription()
        let item = try stash(CovFStkFixtures.accountId, CovFStkFixtures.accountId)

        let requests = try subscription.createRequest(for: item)

        let expectedPaths: [fearless.StorageCodingPath] = [.nominators, .validatorPrefs, .payee]
        XCTAssertEqual(requests.map { $0.0 }, expectedPaths)
        XCTAssertEqual(requests.map { $0.1 }, Array(repeating: CovFStkFixtures.accountId, count: 3))
    }

    func testRequestsRejectAnInvalidStashAddress() {
        let subscription = CovFStkHarness().makeBaseSubscription()

        XCTAssertThrowsError(try subscription.createRequest(for: StashItem(stash: "not-an-address", controller: "nope")))
    }

    // MARK: Remote subscription

    func testSubscribeRemoteEncodesEveryKeyAndRoutesUpdatesToItsHandler() throws {
        let harness = CovFStkHarness(runtime: try CovFStkFixtures.assetHub())
        let created = covFStkExpectation("handlers", count: 7)
        harness.factory.onCreate = { created.fulfill() }
        let subscription = harness.makeBaseSubscription()
        let item = try stash(CovFStkFixtures.otherId, CovFStkFixtures.thirdId)
        let requests = try subscription.createRequest(for: item)

        subscription.subscribeRemote(for: item)
        wait(for: [created], timeout: 5)

        let params = try XCTUnwrap(harness.engine.params.first)
        try assertKeys(params, match: requests)
        let expectedLocalKeys = try requests.map { try CovFStkFixtures.localKey($0.0, accountId: $0.1) }
        XCTAssertEqual(harness.factory.children.map(\.localKey), expectedLocalKeys)

        let children = harness.factory.children
        guard params.count == 7, children.count == 7 else { return }
        try harness.engine.deliver(block: CovFStkFixtures.blockHash.toHex(includePrefix: true), changes: [
            [params[4], "0x0102"],
            ["0xbeef", "0x03"]
        ])
        XCTAssertEqual(children[4].updates, [Data([0x01, 0x02])])
        XCTAssertEqual(children[4].blockHashes, [CovFStkFixtures.blockHash])
        XCTAssertEqual(children.filter { !$0.updates.isEmpty }.count, 1)

        try harness.engine.fail(error: CovFStkError.stub("dropped"), unsubscribed: false)
        XCTAssertTrue(harness.logger.hasError(prefix: "Did receive subscription error"))

        subscription.unsubscribeRemote()
        XCTAssertEqual(harness.engine.unsubscribed, [1])
    }

    func testSubscribeRemoteWithoutRuntimeOrWithInvalidStashLogsUnexpectedError() throws {
        let foreignStash = try stash(CovFStkFixtures.otherId, CovFStkFixtures.otherId)
        let missingRuntime = CovFStkHarness()
        missingRuntime.makeBaseSubscription().subscribeRemote(for: foreignStash)

        let invalidStash = CovFStkHarness(runtime: try CovFStkFixtures.assetHub())
        invalidStash.makeBaseSubscription().subscribeRemote(for: StashItem(stash: "invalid", controller: "invalid"))

        for harness in [missingRuntime, invalidStash] {
            XCTAssertTrue(harness.logger.hasError(prefix: "Did receive unexpected error"))
            XCTAssertTrue(harness.engine.methods.isEmpty)
            XCTAssertEqual(harness.queue.operationCount, 0)
        }
    }

    func testCoderFailureAndMissingCoderAreLoggedAsKeyErrors() throws {
        let ownStash = try stash(CovFStkFixtures.accountId, CovFStkFixtures.accountId)
        let modes: [CovFStkRuntimeMode] = [.failure(CovFStkError.stub("coder")), .empty]
        for mode in modes {
            let harness = CovFStkHarness(runtime: CovFStkRuntime(mode))
            let logged = covFStkExpectation("key error logged")
            harness.logger.onError = { message in
                if message.hasPrefix("Did receive error") {
                    logged.fulfill()
                }
            }
            let subscription = harness.makeBaseSubscription()

            subscription.subscribeRemote(for: ownStash)
            withExtendedLifetime(subscription) {
                wait(for: [logged], timeout: 5)
            }

            XCTAssertTrue(harness.engine.methods.isEmpty)
            XCTAssertTrue(harness.factory.children.isEmpty)
        }
    }

    func testSubscribeToRemoteWithoutConnectionOrWhenRefusedIsLogged() {
        let keys = [SubscriptionStorageKeys(remote: Data([0x01]), local: "local")]
        let disconnected = CovFStkHarness(connected: false)
        disconnected.makeBaseSubscription().subscribeToRemote(with: keys)

        let refused = CovFStkHarness()
        refused.engine.subscribeError = CovFStkError.stub("refused")
        refused.makeBaseSubscription().subscribeToRemote(with: keys)

        for harness in [disconnected, refused] {
            XCTAssertTrue(harness.logger.hasError(prefix: "Can't subscribe to storage"))
            XCTAssertTrue(harness.factory.children.isEmpty)
            XCTAssertTrue(harness.engine.unsubscribeAttempts.isEmpty)
        }
    }

    func testResubscribingEndsTheReplacedSubscriptionAndUnsubscribeFailureIsLogged() throws {
        let harness = CovFStkHarness()
        let subscription = harness.makeBaseSubscription()
        let first = [SubscriptionStorageKeys(remote: Data([0x01]), local: "first")]
        let second = [SubscriptionStorageKeys(remote: Data([0x02]), local: "second")]

        subscription.subscribeToRemote(with: first)
        subscription.subscribeToRemote(with: second)
        XCTAssertEqual(harness.engine.unsubscribed, [1])
        XCTAssertEqual(harness.engine.params, [["0x01"], ["0x02"]])

        try harness.engine.deliver(1, changes: [["0x02", "0x09"], ["0x01", "0x08"]])
        let children = harness.factory.children
        XCTAssertEqual(children.map(\.localKey), ["first", "second"])
        XCTAssertEqual(children.last?.updates, [Data([0x09])])
        XCTAssertEqual(children.first?.updates, [], "the replaced handler no longer receives updates")

        harness.engine.unsubscribeError = CovFStkError.stub("gone")
        subscription.unsubscribeRemote()
        subscription.unsubscribeRemote()
        XCTAssertEqual(harness.engine.unsubscribeAttempts, [1, 2])
        XCTAssertTrue(harness.logger.hasError(prefix: "Can't unsubscribe from staking storage"))
    }

    func testUpdateWithoutSubscriptionIsOnlyWarned() {
        let harness = CovFStkHarness()
        let subscription = harness.makeBaseSubscription()

        subscription.handleUpdate(CovFStkFixtures.update(changes: [(Data([0x01]), Data([0x02]))]))

        XCTAssertEqual(harness.logger.warnings, ["Staking update received but subscription is missing"])
        XCTAssertTrue(harness.factory.children.isEmpty)
    }

    func testApplyHandlerOnlyDeliversTheMatchingChange() {
        let subscription = CovFStkHarness().makeBaseSubscription()
        let handler = CovFStkChild(keys: SubscriptionStorageKeys(remote: Data([0x05]), local: "local"))

        subscription.applyHandler(handler, for: fearless.StorageUpdateData(update: CovFStkFixtures.update(changes: [(Data([0x06]), nil)])))
        subscription.applyHandler(
            handler,
            for: fearless.StorageUpdateData(update: CovFStkFixtures.update(block: CovFStkFixtures.blockHash, changes: [(Data([0x05]), nil)]))
        )

        XCTAssertEqual(handler.updates, [nil])
        XCTAssertEqual(handler.blockHashes, [CovFStkFixtures.blockHash])
    }

    // MARK: Local stash observation

    func testProviderFailureIsLogged() {
        let harness = CovFStkHarness()
        harness.repository.fetchError = CovFStkError.stub("storage")
        let logged = covFStkExpectation("provider error logged")
        harness.logger.onError = { message in
            if message.hasPrefix("Did receive error") {
                logged.fulfill()
            }
        }
        let subscription = harness.makeBaseSubscription()

        subscription.resolveKeysAndSubscribe()
        withExtendedLifetime(subscription) {
            wait(for: [logged], timeout: 5)
        }

        XCTAssertTrue(harness.engine.methods.isEmpty)
    }

    func testDeletedStashEndsTheRemoteSubscriptionWithoutResubscribing() throws {
        let item = try stash(CovFStkFixtures.accountId, CovFStkFixtures.accountId)
        let harness = CovFStkHarness(runtime: try CovFStkFixtures.assetHub(), items: [item])
        let observing = covFStkExpectation("provider observes the repository")
        let created = covFStkExpectation("handlers", count: 3)
        harness.observable.onAdd = { observing.fulfill() }
        harness.factory.onCreate = { created.fulfill() }
        let subscription = harness.makeBaseSubscription()

        subscription.resolveKeysAndSubscribe()
        wait(for: [observing, created], timeout: 5)
        let requests = try subscription.createRequest(for: item)
        let params = try XCTUnwrap(harness.engine.params.first)
        try assertKeys(params, match: requests)

        let unsubscribed = covFStkExpectation("remote subscription ended")
        harness.engine.onUnsubscribe = { unsubscribed.fulfill() }
        harness.observable.emit([.delete(deletedIdentifier: item.stash)])
        withExtendedLifetime(subscription) {
            wait(for: [unsubscribed], timeout: 5)
        }

        XCTAssertEqual(harness.engine.unsubscribed, [1])
        XCTAssertEqual(harness.engine.methods.count, 1)
    }

    func testAssemblyBuildsTheV14Subscription() {
        let harness = CovFStkHarness()
        let subscription = StakingAccountSubscriptionAssembly.createSubscription(
            accountId: CovFStkFixtures.accountId,
            chainAsset: CovFStkFixtures.chainAsset,
            chainFormat: CovFStkFixtures.format,
            chainRegistry: harness.registry,
            provider: harness.provider,
            childSubscriptionFactory: harness.factory,
            operationQueue: harness.queue,
            logger: harness.logger
        )

        XCTAssertTrue(subscription is StakingAccountSubscriptionV14)
        XCTAssertTrue(harness.engine.methods.isEmpty, "nothing subscribes before the stash is resolved")
    }
}

final class CovFStkPoolSubscriptionTests: XCTestCase {
    func testPoolWithoutRuntimeLogsUnexpectedError() {
        let harness = CovFStkHarness()

        let pool = harness.makePool()

        XCTAssertTrue(harness.logger.hasError(prefix: "Did receive unexpected error"))
        XCTAssertTrue(harness.engine.methods.isEmpty)
        withExtendedLifetime(pool) {}
    }

    func testPoolKeyEncodingFailuresAreLogged() {
        let modes: [CovFStkRuntimeMode] = [.failure(CovFStkError.stub("coder")), .empty]
        for mode in modes {
            let harness = CovFStkHarness(runtime: CovFStkRuntime(mode))
            let logged = covFStkExpectation("key error logged")
            harness.logger.onError = { message in
                if message.hasPrefix("Did receive error") {
                    logged.fulfill()
                }
            }

            let pool = harness.makePool()
            withExtendedLifetime(pool) {
                wait(for: [logged], timeout: 5)
            }

            XCTAssertTrue(harness.engine.methods.isEmpty)
        }
    }

    func testPoolSubscriptionWithoutConnectionOrWhenRefusedIsLogged() throws {
        let disconnected = CovFStkHarness(runtime: try CovFStkFixtures.assetHub(), connected: false)
        let refused = CovFStkHarness(runtime: try CovFStkFixtures.assetHub())
        refused.engine.subscribeError = CovFStkError.stub("refused")

        for harness in [disconnected, refused] {
            let logged = covFStkExpectation("subscribe error logged")
            harness.logger.onError = { message in
                if message.hasPrefix("Can't subscribe to storage") {
                    logged.fulfill()
                }
            }

            let pool = harness.makePool()
            withExtendedLifetime(pool) {
                wait(for: [logged], timeout: 5)
            }

            XCTAssertTrue(harness.factory.children.isEmpty)
        }
    }

    func testPoolRoutesMemberUpdatesAndLogsSubscriptionAndUnsubscribeFailures() throws {
        let harness = CovFStkHarness(runtime: try CovFStkFixtures.assetHub())
        let created = covFStkExpectation("member handler")
        harness.factory.onCreate = { created.fulfill() }

        var pool: PoolStakingAccountSubscription? = harness.makePool()
        withExtendedLifetime(pool) {
            wait(for: [created], timeout: 5)
        }

        let params = try XCTUnwrap(harness.engine.params.first)
        XCTAssertEqual(params.count, 1)
        let key = try Data(hexStringSSF: try XCTUnwrap(params.first))
        XCTAssertEqual(Data(key.prefix(32)), try CovFStkFixtures.storagePrefix(.stakingPoolMembers))
        XCTAssertEqual(Data(key.suffix(32)), CovFStkFixtures.accountId)
        let member = try XCTUnwrap(harness.factory.children.first)
        XCTAssertEqual(member.localKey, try CovFStkFixtures.localKey(.stakingPoolMembers, accountId: CovFStkFixtures.accountId))

        try harness.engine.deliver(block: CovFStkFixtures.blockHash.toHex(includePrefix: true), changes: [
            [key.toHex(includePrefix: true), "0x2a"],
            ["0x0102", "0x03"]
        ])
        XCTAssertEqual(member.updates, [Data([0x2a])])
        XCTAssertEqual(member.blockHashes, [CovFStkFixtures.blockHash])

        try harness.engine.fail(error: CovFStkError.stub("dropped"), unsubscribed: true)
        XCTAssertTrue(harness.logger.hasError(prefix: "Did receive subscription error"))

        harness.engine.unsubscribeError = CovFStkError.stub("gone")
        let unsubscribeLogged = covFStkExpectation("unsubscribe failure logged")
        harness.logger.onError = { message in
            if message.hasPrefix("Can't unsubscribe from pool staking storage") {
                unsubscribeLogged.fulfill()
            }
        }
        XCTAssertNotNil(pool)
        pool = nil
        wait(for: [unsubscribeLogged], timeout: 5)

        XCTAssertEqual(harness.engine.unsubscribeAttempts, [1])
    }

    func testPoolUpdateAfterReleaseIsIgnored() throws {
        let harness = CovFStkHarness(runtime: try CovFStkFixtures.assetHub())
        let created = covFStkExpectation("member handler")
        harness.factory.onCreate = { created.fulfill() }

        var pool: PoolStakingAccountSubscription? = harness.makePool()
        withExtendedLifetime(pool) {
            wait(for: [created], timeout: 5)
        }
        let member = try XCTUnwrap(harness.factory.children.first)
        let unsubscribed = covFStkExpectation("released subscription ended")
        harness.engine.onUnsubscribe = { unsubscribed.fulfill() }
        XCTAssertNotNil(pool)
        pool = nil
        wait(for: [unsubscribed], timeout: 5)

        try harness.engine.deliver(changes: [[member.remoteStorageKey.toHex(includePrefix: true), "0x01"]])

        XCTAssertEqual(harness.engine.unsubscribed, [1])
        XCTAssertTrue(member.updates.isEmpty)
        XCTAssertTrue(harness.logger.warnings.isEmpty)
    }
}
