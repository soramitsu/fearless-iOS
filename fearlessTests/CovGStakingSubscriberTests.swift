import Foundation
import BigInt
import RobinHood
import SSFModels
import SSFUtils
import XCTest
@testable import fearless

final class CovGStakingSubscriberTests: XCTestCase {
    private let chainId = "1"
    private let accountId = Data(repeating: 7, count: 32)

    func testMinBondForwardsUpdatesDeletionAndFailure() throws {
        let chainAsset = try ChainAsset(chain: CovGOperationFixtures.chain(), asset: CovGOperationFixtures.asset)
        let factory = CovGStakingSubscriptionFactory()
        let subscriber = CovGStakingSubscriber(factory: factory)
        let provider = factory.minBond
        let result = subscriber.subscribeToMinNominatorBond(for: chainId)
        XCTAssertNotNil(result)
        XCTAssertTrue(provider.observer === subscriber)
        XCTAssertEqual(provider.queue?.label, DispatchQueue.main.label)
        XCTAssertEqual(provider.options?.alwaysNotifyOnRefresh, false)
        XCTAssertEqual(provider.options?.waitsInProgressSyncOnAdd, false)
        XCTAssertEqual(factory.lastChain, chainId)
        provider.update?([.insert(newItem: DecodedBigUInt(identifier: "key", item: nil))])
        XCTAssertNil(try XCTUnwrap(subscriber.minBond).get())
        XCTAssertEqual(subscriber.chainId, chainId)
        let value = try JSONDecoder().decode(fearless.StringScaleMapper<BigUInt>.self, from: Data(#""42""#.utf8))
        provider.update?([.update(newItem: DecodedBigUInt(identifier: "key", item: value))])
        XCTAssertEqual(try XCTUnwrap(subscriber.minBond).get(), value.value)
        provider.update?([.delete(deletedIdentifier: "key")])
        XCTAssertNil(try XCTUnwrap(subscriber.minBond).get())
        provider.failure?(NSError(domain: "CovG.subscriber", code: 51))
        XCTAssertThrowsError(try XCTUnwrap(subscriber.minBond).get()) { XCTAssertEqual(($0 as NSError).code, 51) }
        factory.shouldThrow = true
        XCTAssertNil(subscriber.subscribeToMinNominatorBond(for: chainId))
    }

    func testCounterForwardsUpdatesDeletionAndFailure() throws {
        let chainAsset = try ChainAsset(chain: CovGOperationFixtures.chain(), asset: CovGOperationFixtures.asset)
        let factory = CovGStakingSubscriptionFactory()
        let subscriber = CovGStakingSubscriber(factory: factory)
        let provider = factory.counter
        let result = subscriber.subscribeToCounterForNominators(for: chainId)
        XCTAssertNotNil(result)
        XCTAssertTrue(provider.observer === subscriber)
        XCTAssertEqual(provider.queue?.label, DispatchQueue.main.label)
        XCTAssertEqual(provider.options?.alwaysNotifyOnRefresh, false)
        XCTAssertEqual(provider.options?.waitsInProgressSyncOnAdd, false)
        XCTAssertEqual(factory.lastChain, chainId)
        provider.update?([.insert(newItem: DecodedU32(identifier: "key", item: nil))])
        XCTAssertNil(try XCTUnwrap(subscriber.counter).get())
        XCTAssertEqual(subscriber.chainId, chainId)
        let value = try JSONDecoder().decode(fearless.StringScaleMapper<UInt32>.self, from: Data(#""42""#.utf8))
        provider.update?([.update(newItem: DecodedU32(identifier: "key", item: value))])
        XCTAssertEqual(try XCTUnwrap(subscriber.counter).get(), value.value)
        provider.update?([.delete(deletedIdentifier: "key")])
        XCTAssertNil(try XCTUnwrap(subscriber.counter).get())
        provider.failure?(NSError(domain: "CovG.subscriber", code: 51))
        XCTAssertThrowsError(try XCTUnwrap(subscriber.counter).get()) { XCTAssertEqual(($0 as NSError).code, 51) }
        factory.shouldThrow = true
        XCTAssertNil(subscriber.subscribeToCounterForNominators(for: chainId))
    }

    func testMaximumForwardsUpdatesDeletionAndFailure() throws {
        let chainAsset = try ChainAsset(chain: CovGOperationFixtures.chain(), asset: CovGOperationFixtures.asset)
        let factory = CovGStakingSubscriptionFactory()
        let subscriber = CovGStakingSubscriber(factory: factory)
        let provider = factory.maximum
        let result = subscriber.subscribeMaxNominatorsCount(for: chainId)
        XCTAssertNotNil(result)
        XCTAssertTrue(provider.observer === subscriber)
        XCTAssertEqual(provider.queue?.label, DispatchQueue.main.label)
        XCTAssertEqual(provider.options?.alwaysNotifyOnRefresh, false)
        XCTAssertEqual(provider.options?.waitsInProgressSyncOnAdd, false)
        XCTAssertEqual(factory.lastChain, chainId)
        provider.update?([.insert(newItem: DecodedU32(identifier: "key", item: nil))])
        XCTAssertNil(try XCTUnwrap(subscriber.maximum).get())
        XCTAssertEqual(subscriber.chainId, chainId)
        let value = try JSONDecoder().decode(fearless.StringScaleMapper<UInt32>.self, from: Data(#""42""#.utf8))
        provider.update?([.update(newItem: DecodedU32(identifier: "key", item: value))])
        XCTAssertEqual(try XCTUnwrap(subscriber.maximum).get(), value.value)
        provider.update?([.delete(deletedIdentifier: "key")])
        XCTAssertNil(try XCTUnwrap(subscriber.maximum).get())
        provider.failure?(NSError(domain: "CovG.subscriber", code: 51))
        XCTAssertThrowsError(try XCTUnwrap(subscriber.maximum).get()) { XCTAssertEqual(($0 as NSError).code, 51) }
        factory.shouldThrow = true
        XCTAssertNil(subscriber.subscribeMaxNominatorsCount(for: chainId))
    }

    func testNominationForwardsUpdatesDeletionAndFailure() throws {
        let chainAsset = try ChainAsset(chain: CovGOperationFixtures.chain(), asset: CovGOperationFixtures.asset)
        let factory = CovGStakingSubscriptionFactory()
        let subscriber = CovGStakingSubscriber(factory: factory)
        let provider = factory.nomination
        let result = subscriber.subscribeNomination(for: accountId, chainAsset: chainAsset)
        XCTAssertNotNil(result)
        XCTAssertTrue(provider.observer === subscriber)
        XCTAssertEqual(provider.queue?.label, DispatchQueue.main.label)
        XCTAssertEqual(provider.options?.alwaysNotifyOnRefresh, false)
        XCTAssertEqual(provider.options?.waitsInProgressSyncOnAdd, false)
        XCTAssertEqual(factory.lastChain, chainId)
        XCTAssertEqual(factory.lastAccount, accountId)
        provider.update?([.insert(newItem: DecodedNomination(identifier: "key", item: nil))])
        XCTAssertNil(try XCTUnwrap(subscriber.nomination).get())
        XCTAssertEqual(subscriber.chainId, chainId)
        XCTAssertEqual(subscriber.accountId, accountId)
        let value = try JSONDecoder().decode(Nomination.self, from: Data(#"{"targets":[],"submittedIn":"7"}"#.utf8))
        provider.update?([.update(newItem: DecodedNomination(identifier: "key", item: value))])
        XCTAssertEqual(try XCTUnwrap(subscriber.nomination).get(), value)
        provider.update?([.delete(deletedIdentifier: "key")])
        XCTAssertNil(try XCTUnwrap(subscriber.nomination).get())
        provider.failure?(NSError(domain: "CovG.subscriber", code: 51))
        XCTAssertThrowsError(try XCTUnwrap(subscriber.nomination).get()) { XCTAssertEqual(($0 as NSError).code, 51) }
        factory.shouldThrow = true
        XCTAssertNil(subscriber.subscribeNomination(for: accountId, chainAsset: chainAsset))
    }

    func testValidatorForwardsUpdatesDeletionAndFailure() throws {
        let chainAsset = try ChainAsset(chain: CovGOperationFixtures.chain(), asset: CovGOperationFixtures.asset)
        let factory = CovGStakingSubscriptionFactory()
        let subscriber = CovGStakingSubscriber(factory: factory)
        let provider = factory.validator
        let result = subscriber.subscribeValidator(for: accountId, chainAsset: chainAsset)
        XCTAssertNotNil(result)
        XCTAssertTrue(provider.observer === subscriber)
        XCTAssertEqual(provider.queue?.label, DispatchQueue.main.label)
        XCTAssertEqual(provider.options?.alwaysNotifyOnRefresh, false)
        XCTAssertEqual(provider.options?.waitsInProgressSyncOnAdd, false)
        XCTAssertEqual(factory.lastChain, chainId)
        XCTAssertEqual(factory.lastAccount, accountId)
        provider.update?([.insert(newItem: DecodedValidator(identifier: "key", item: nil))])
        XCTAssertNil(try XCTUnwrap(subscriber.validator).get())
        XCTAssertEqual(subscriber.chainId, chainId)
        XCTAssertEqual(subscriber.accountId, accountId)
        let value = try JSONDecoder().decode(ValidatorPrefs.self, from: Data(#"{"commission":"12","blocked":true}"#.utf8))
        provider.update?([.update(newItem: DecodedValidator(identifier: "key", item: value))])
        XCTAssertEqual(try XCTUnwrap(subscriber.validator).get(), value)
        provider.update?([.delete(deletedIdentifier: "key")])
        XCTAssertNil(try XCTUnwrap(subscriber.validator).get())
        provider.failure?(NSError(domain: "CovG.subscriber", code: 51))
        XCTAssertThrowsError(try XCTUnwrap(subscriber.validator).get()) { XCTAssertEqual(($0 as NSError).code, 51) }
        factory.shouldThrow = true
        XCTAssertNil(subscriber.subscribeValidator(for: accountId, chainAsset: chainAsset))
    }
}

final class CovGStakingSubscriberMoreTests: XCTestCase {
    private let chainId = "1"
    private let accountId = Data(repeating: 7, count: 32)

    func testLedgerForwardsUpdatesDeletionAndFailure() throws {
        let chainAsset = try ChainAsset(chain: CovGOperationFixtures.chain(), asset: CovGOperationFixtures.asset)
        let factory = CovGStakingSubscriptionFactory()
        let subscriber = CovGStakingSubscriber(factory: factory)
        let provider = factory.ledger
        let result = subscriber.subscribeLedgerInfo(for: accountId, chainAsset: chainAsset)
        XCTAssertNotNil(result)
        XCTAssertTrue(provider.observer === subscriber)
        XCTAssertEqual(provider.queue?.label, DispatchQueue.main.label)
        XCTAssertEqual(provider.options?.alwaysNotifyOnRefresh, false)
        XCTAssertEqual(provider.options?.waitsInProgressSyncOnAdd, false)
        XCTAssertEqual(factory.lastChain, chainId)
        XCTAssertEqual(factory.lastAccount, accountId)
        provider.update?([.insert(newItem: DecodedLedgerInfo(identifier: "key", item: nil))])
        XCTAssertNil(try XCTUnwrap(subscriber.ledger).get())
        XCTAssertEqual(subscriber.chainId, chainId)
        XCTAssertEqual(subscriber.accountId, accountId)
        provider.update?([.delete(deletedIdentifier: "key")])
        XCTAssertNil(try XCTUnwrap(subscriber.ledger).get())
        provider.failure?(NSError(domain: "CovG.subscriber", code: 51))
        XCTAssertThrowsError(try XCTUnwrap(subscriber.ledger).get()) { XCTAssertEqual(($0 as NSError).code, 51) }
        factory.shouldThrow = true
        XCTAssertNil(subscriber.subscribeLedgerInfo(for: accountId, chainAsset: chainAsset))
    }

    func testActiveEraForwardsUpdatesDeletionAndFailure() throws {
        let chainAsset = try ChainAsset(chain: CovGOperationFixtures.chain(), asset: CovGOperationFixtures.asset)
        let factory = CovGStakingSubscriptionFactory()
        let subscriber = CovGStakingSubscriber(factory: factory)
        let provider = factory.activeEra
        let result = subscriber.subscribeActiveEra(for: chainId)
        XCTAssertNotNil(result)
        XCTAssertTrue(provider.observer === subscriber)
        XCTAssertEqual(provider.queue?.label, DispatchQueue.main.label)
        XCTAssertEqual(provider.options?.alwaysNotifyOnRefresh, false)
        XCTAssertEqual(provider.options?.waitsInProgressSyncOnAdd, false)
        XCTAssertEqual(factory.lastChain, chainId)
        provider.update?([.insert(newItem: DecodedActiveEra(identifier: "key", item: nil))])
        XCTAssertNil(try XCTUnwrap(subscriber.activeEra).get())
        XCTAssertEqual(subscriber.chainId, chainId)
        let value = try JSONDecoder().decode(ActiveEraInfo.self, from: Data(#"{"index":"7"}"#.utf8))
        provider.update?([.update(newItem: DecodedActiveEra(identifier: "key", item: value))])
        XCTAssertEqual(try XCTUnwrap(subscriber.activeEra).get(), value)
        provider.update?([.delete(deletedIdentifier: "key")])
        XCTAssertNil(try XCTUnwrap(subscriber.activeEra).get())
        provider.failure?(NSError(domain: "CovG.subscriber", code: 51))
        XCTAssertThrowsError(try XCTUnwrap(subscriber.activeEra).get()) { XCTAssertEqual(($0 as NSError).code, 51) }
        factory.shouldThrow = true
        XCTAssertNil(subscriber.subscribeActiveEra(for: chainId))
    }

    func testCurrentEraForwardsUpdatesDeletionAndFailure() throws {
        let chainAsset = try ChainAsset(chain: CovGOperationFixtures.chain(), asset: CovGOperationFixtures.asset)
        let factory = CovGStakingSubscriptionFactory()
        let subscriber = CovGStakingSubscriber(factory: factory)
        let provider = factory.currentEra
        let result = subscriber.subscribeCurrentEra(for: chainId)
        XCTAssertNotNil(result)
        XCTAssertTrue(provider.observer === subscriber)
        XCTAssertEqual(provider.queue?.label, DispatchQueue.main.label)
        XCTAssertEqual(provider.options?.alwaysNotifyOnRefresh, false)
        XCTAssertEqual(provider.options?.waitsInProgressSyncOnAdd, false)
        XCTAssertEqual(factory.lastChain, chainId)
        provider.update?([.insert(newItem: DecodedEraIndex(identifier: "key", item: nil))])
        XCTAssertNil(try XCTUnwrap(subscriber.currentEra).get())
        XCTAssertEqual(subscriber.chainId, chainId)
        let value = try JSONDecoder().decode(fearless.StringScaleMapper<EraIndex>.self, from: Data(#""42""#.utf8))
        provider.update?([.update(newItem: DecodedEraIndex(identifier: "key", item: value))])
        XCTAssertEqual(try XCTUnwrap(subscriber.currentEra).get(), value.value)
        provider.update?([.delete(deletedIdentifier: "key")])
        XCTAssertNil(try XCTUnwrap(subscriber.currentEra).get())
        provider.failure?(NSError(domain: "CovG.subscriber", code: 51))
        XCTAssertThrowsError(try XCTUnwrap(subscriber.currentEra).get()) { XCTAssertEqual(($0 as NSError).code, 51) }
        factory.shouldThrow = true
        XCTAssertNil(subscriber.subscribeCurrentEra(for: chainId))
    }

    func testPayeeForwardsUpdatesDeletionAndFailure() throws {
        let chainAsset = try ChainAsset(chain: CovGOperationFixtures.chain(), asset: CovGOperationFixtures.asset)
        let factory = CovGStakingSubscriptionFactory()
        let subscriber = CovGStakingSubscriber(factory: factory)
        let provider = factory.payee
        let result = subscriber.subscribePayee(for: accountId, chainAsset: chainAsset)
        XCTAssertNotNil(result)
        XCTAssertTrue(provider.observer === subscriber)
        XCTAssertEqual(provider.queue?.label, DispatchQueue.main.label)
        XCTAssertEqual(provider.options?.alwaysNotifyOnRefresh, false)
        XCTAssertEqual(provider.options?.waitsInProgressSyncOnAdd, false)
        XCTAssertEqual(factory.lastChain, chainId)
        XCTAssertEqual(factory.lastAccount, accountId)
        provider.update?([.insert(newItem: DecodedPayee(identifier: "key", item: nil))])
        XCTAssertNil(try XCTUnwrap(subscriber.payee).get())
        XCTAssertEqual(subscriber.chainId, chainId)
        XCTAssertEqual(subscriber.accountId, accountId)
        provider.update?([.delete(deletedIdentifier: "key")])
        XCTAssertNil(try XCTUnwrap(subscriber.payee).get())
        provider.failure?(NSError(domain: "CovG.subscriber", code: 51))
        XCTAssertThrowsError(try XCTUnwrap(subscriber.payee).get()) { XCTAssertEqual(($0 as NSError).code, 51) }
        factory.shouldThrow = true
        XCTAssertNil(subscriber.subscribePayee(for: accountId, chainAsset: chainAsset))
    }

    func testPoolMemberForwardsUpdatesDeletionAndFailure() throws {
        let chainAsset = try ChainAsset(chain: CovGOperationFixtures.chain(), asset: CovGOperationFixtures.asset)
        let factory = CovGStakingSubscriptionFactory()
        let subscriber = CovGStakingSubscriber(factory: factory)
        let provider = factory.poolMember
        let result = subscriber.subscribeToPoolMembers(for: accountId, chainAsset: chainAsset)
        XCTAssertNotNil(result)
        XCTAssertTrue(provider.observer === subscriber)
        XCTAssertEqual(provider.queue?.label, DispatchQueue.main.label)
        XCTAssertEqual(provider.options?.alwaysNotifyOnRefresh, false)
        XCTAssertEqual(provider.options?.waitsInProgressSyncOnAdd, false)
        XCTAssertEqual(factory.lastChain, chainId)
        XCTAssertEqual(factory.lastAccount, accountId)
        provider.update?([.insert(newItem: DecodedPoolMember(identifier: "key", item: nil))])
        XCTAssertNil(try XCTUnwrap(subscriber.poolMember).get())
        XCTAssertEqual(subscriber.chainId, chainId)
        XCTAssertEqual(subscriber.accountId, accountId)
        provider.update?([.delete(deletedIdentifier: "key")])
        XCTAssertNil(try XCTUnwrap(subscriber.poolMember).get())
        provider.failure?(NSError(domain: "CovG.subscriber", code: 51))
        XCTAssertThrowsError(try XCTUnwrap(subscriber.poolMember).get()) { XCTAssertEqual(($0 as NSError).code, 51) }
        factory.shouldThrow = true
        XCTAssertNil(subscriber.subscribeToPoolMembers(for: accountId, chainAsset: chainAsset))
    }
}

final class CovGStakingSubscriber: RelaychainStakingLocalStorageSubscriber, RelaychainStakingLocalSubscriptionHandler {
    let stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    var chainId: String?
    var accountId: Data?
    init(factory: RelaychainStakingLocalSubscriptionFactoryProtocol) {
        stakingLocalSubscriptionFactory = factory
    }

    var minBond: Result<BigUInt?, Error>?
    func handleMinNominatorBond(result: Result<BigUInt?, Error>, chainId: ChainModel.Id) {
        minBond = result
        self.chainId = chainId
    }

    var counter: Result<UInt32?, Error>?
    func handleCounterForNominators(result: Result<UInt32?, Error>, chainId: ChainModel.Id) {
        counter = result
        self.chainId = chainId
    }

    var maximum: Result<UInt32?, Error>?
    func handleMaxNominatorsCount(result: Result<UInt32?, Error>, chainId: ChainModel.Id) {
        maximum = result
        self.chainId = chainId
    }

    var nomination: Result<Nomination?, Error>?
    func handleNomination(result: Result<Nomination?, Error>, accountId: AccountId, chainId: ChainModel.Id) {
        nomination = result
        self.chainId = chainId
        self.accountId = accountId
    }

    var validator: Result<ValidatorPrefs?, Error>?
    func handleValidator(result: Result<ValidatorPrefs?, Error>, accountId: AccountId, chainId: ChainModel.Id) {
        validator = result
        self.chainId = chainId
        self.accountId = accountId
    }

    var ledger: Result<StakingLedger?, Error>?
    func handleLedgerInfo(result: Result<StakingLedger?, Error>, accountId: AccountId, chainId: ChainModel.Id) {
        ledger = result
        self.chainId = chainId
        self.accountId = accountId
    }

    var activeEra: Result<ActiveEraInfo?, Error>?
    func handleActiveEra(result: Result<ActiveEraInfo?, Error>, chainId: ChainModel.Id) {
        activeEra = result
        self.chainId = chainId
    }

    var currentEra: Result<EraIndex?, Error>?
    func handleCurrentEra(result: Result<EraIndex?, Error>, chainId: ChainModel.Id) {
        currentEra = result
        self.chainId = chainId
    }

    var payee: Result<RewardDestinationArg?, Error>?
    func handlePayee(result: Result<RewardDestinationArg?, Error>, accountId: AccountId, chainId: ChainModel.Id) {
        payee = result
        self.chainId = chainId
        self.accountId = accountId
    }

    var poolMember: Result<StakingPoolMember?, Error>?
    func handlePoolMember(result: Result<StakingPoolMember?, Error>, accountId: AccountId, chainId: ChainModel.Id) {
        poolMember = result
        self.chainId = chainId
        self.accountId = accountId
    }
}

final class CovGStakingSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol {
    var shouldThrow = false
    var lastChain: String?
    var lastAccount: Data?
    let minBond = CovGObservedProvider<DecodedBigUInt>()
    func getMinNominatorBondProvider(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedBigUInt> {
        if shouldThrow {
            throw NSError(domain: "CovG.factory", code: 1)
        }
        lastChain = chainId
        return AnyDataProvider(minBond)
    }

    let counter = CovGObservedProvider<DecodedU32>()
    func getCounterForNominatorsProvider(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedU32> {
        if shouldThrow {
            throw NSError(domain: "CovG.factory", code: 1)
        }
        lastChain = chainId
        return AnyDataProvider(counter)
    }

    let maximum = CovGObservedProvider<DecodedU32>()
    func getMaxNominatorsCountProvider(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedU32> {
        if shouldThrow {
            throw NSError(domain: "CovG.factory", code: 1)
        }
        lastChain = chainId
        return AnyDataProvider(maximum)
    }

    let nomination = CovGObservedProvider<DecodedNomination>()
    func getNominationProvider(for accountId: AccountId, chainAsset: ChainAsset) throws -> AnyDataProvider<DecodedNomination> {
        if shouldThrow {
            throw NSError(domain: "CovG.factory", code: 1)
        }
        lastChain = chainAsset.chain.chainId
        lastAccount = accountId
        return AnyDataProvider(nomination)
    }

    let validator = CovGObservedProvider<DecodedValidator>()
    func getValidatorProvider(for accountId: AccountId, chainAsset: ChainAsset) throws -> AnyDataProvider<DecodedValidator> {
        if shouldThrow {
            throw NSError(domain: "CovG.factory", code: 1)
        }
        lastChain = chainAsset.chain.chainId
        lastAccount = accountId
        return AnyDataProvider(validator)
    }

    let ledger = CovGObservedProvider<DecodedLedgerInfo>()
    func getLedgerInfoProvider(for accountId: AccountId, chainAsset: ChainAsset) throws -> AnyDataProvider<DecodedLedgerInfo> {
        if shouldThrow {
            throw NSError(domain: "CovG.factory", code: 1)
        }
        lastChain = chainAsset.chain.chainId
        lastAccount = accountId
        return AnyDataProvider(ledger)
    }

    let activeEra = CovGObservedProvider<DecodedActiveEra>()
    func getActiveEra(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedActiveEra> {
        if shouldThrow {
            throw NSError(domain: "CovG.factory", code: 1)
        }
        lastChain = chainId
        return AnyDataProvider(activeEra)
    }

    let currentEra = CovGObservedProvider<DecodedEraIndex>()
    func getCurrentEra(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedEraIndex> {
        if shouldThrow {
            throw NSError(domain: "CovG.factory", code: 1)
        }
        lastChain = chainId
        return AnyDataProvider(currentEra)
    }

    let payee = CovGObservedProvider<DecodedPayee>()
    func getPayee(for accountId: AccountId, chainAsset: ChainAsset) throws -> AnyDataProvider<DecodedPayee> {
        if shouldThrow {
            throw NSError(domain: "CovG.factory", code: 1)
        }
        lastChain = chainAsset.chain.chainId
        lastAccount = accountId
        return AnyDataProvider(payee)
    }

    let poolMember = CovGObservedProvider<DecodedPoolMember>()
    func getPoolMembersProvider(for chainAsset: ChainAsset, accountId: AccountId) throws -> AnyDataProvider<DecodedPoolMember> {
        if shouldThrow {
            throw NSError(domain: "CovG.factory", code: 1)
        }
        lastChain = chainAsset.chain.chainId
        lastAccount = accountId
        return AnyDataProvider(poolMember)
    }

    func getTotalReward(for _: AccountAddress, chain _: ChainModel, assetPrecision _: Int16) throws -> AnySingleValueProvider<TotalRewardItem> {
        throw NSError(domain: "CovG.unused", code: 1)
    }

    func getStashItemProvider(for _: AccountAddress) -> StreamableProvider<StashItem> {
        preconditionFailure("Stash subscriptions are not requested by these tests")
    }
}

final class CovGObservedProvider<T: RobinHood.Identifiable>: DataProviderProtocol {
    let executionQueue = OperationQueue()
    weak var observer: AnyObject?
    var queue: DispatchQueue?
    var options: DataProviderObserverOptions?
    var update: (([DataProviderChange<T>]) -> Void)?
    var failure: ((Error) -> Void)?
    func fetch(by _: String, completionBlock _: ((Result<T?, Error>?) -> Void)?) -> CompoundOperationWrapper<T?> {
        let operation = BaseOperation<T?>()
        operation.result = .success(nil)
        return CompoundOperationWrapper(targetOperation: operation)
    }

    func fetch(page _: UInt, completionBlock _: ((Result<[T], Error>?) -> Void)?) -> CompoundOperationWrapper<[T]> {
        let operation = BaseOperation<[T]>()
        operation.result = .success([])
        return CompoundOperationWrapper(targetOperation: operation)
    }

    func addObserver(
        _ observer: AnyObject, deliverOn queue: DispatchQueue?, executing updateBlock: @escaping ([DataProviderChange<T>]) -> Void,
        failing failureBlock: @escaping (Error) -> Void, options: DataProviderObserverOptions
    ) {
        self.observer = observer
        self.queue = queue
        self.options = options
        update = updateBlock
        failure = failureBlock
    }

    func removeObserver(_: AnyObject) {}
    func refresh() {}
}
