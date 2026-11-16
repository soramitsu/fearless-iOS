@testable import fearless
import Foundation
import RobinHood
import SSFModels
import SSFUtils
import XCTest

final class CovGSubscriptionFactoryTests: XCTestCase {
    func testStakingFactoryCachesEachProviderUnderCorrectStorageKey() throws {
        let factory = RelaychainStakingLocalSubscriptionFactory(
            chainRegistry: CovGHistoryRegistry(), storageFacade: SubstrateStorageTestFacade(),
            operationManager: OperationManager(), logger: Logger.shared
        )
        let chain = try CovGOperationFixtures.chain()
        let chainAsset = ChainAsset(chain: chain, asset: CovGOperationFixtures.asset)
        let account = Data(repeating: 1, count: 32)
        let keys = LocalStorageKeyFactory()
        func chainKey(_ path: fearless.StorageCodingPath) throws -> String {
            try keys.createFromStoragePath(path, chainId: chain.chainId)
        }
        func accountKey(_ path: fearless.StorageCodingPath) throws -> String {
            try keys.createFromStoragePath(path, chainAssetKey: chainAsset.uniqueKey(accountId: account))
        }
        try check(factory, key: chainKey(.minNominatorBond)) { try factory.getMinNominatorBondProvider(for: chain.chainId) }
        try check(factory, key: chainKey(.counterForNominators)) { try factory.getCounterForNominatorsProvider(for: chain.chainId) }
        try check(factory, key: chainKey(.maxNominatorsCount)) { try factory.getMaxNominatorsCountProvider(for: chain.chainId) }
        try check(factory, key: chainKey(.activeEra)) { try factory.getActiveEra(for: chain.chainId) }
        try check(factory, key: chainKey(.currentEra)) { try factory.getCurrentEra(for: chain.chainId) }
        try check(factory, key: accountKey(.nominators)) { try factory.getNominationProvider(for: account, chainAsset: chainAsset) }
        try check(factory, key: accountKey(.validatorPrefs)) { try factory.getValidatorProvider(for: account, chainAsset: chainAsset) }
        try check(factory, key: accountKey(.stakingLedger)) { try factory.getLedgerInfoProvider(for: account, chainAsset: chainAsset) }
        try check(factory, key: accountKey(.payee)) { try factory.getPayee(for: account, chainAsset: chainAsset) }
        try check(factory, key: accountKey(.stakingPoolMembers)) { try factory.getPoolMembersProvider(for: chainAsset, accountId: account) }
        let stash = factory.getStashItemProvider(for: "owner")
        XCTAssertTrue(stash === factory.getStashItemProvider(for: "owner"))
        XCTAssertFalse(stash === factory.getStashItemProvider(for: "other"))
        XCTAssertThrowsError(try factory.getTotalReward(for: "owner", chain: chain, assetPrecision: 12))
    }

    func testCrowdloanFactoryUsesParaSpecificCacheAndRequiresRuntimeAndConnection() throws {
        let registry = try CovGPoolRegistry()
        let factory = CrowdloanLocalSubscriptionFactory(
            chainRegistry: registry, storageFacade: SubstrateStorageTestFacade(), operationManager: OperationManager(), logger: Logger.shared
        )
        let keyFactory = LocalStorageKeyFactory()
        try check(factory, key: keyFactory.createFromStoragePath(.blockNumber, chainId: "1")) { try factory.getBlockNumberProvider(for: "1") }
        let key = try keyFactory.createFromStoragePath(fearless.StorageCodingPath.crowdloanFunds, encodableElement: UInt32(7), chainId: "1")
        try check(factory, key: key) { try factory.getCrowdloanFundsProvider(for: 7, chainId: "1") }
        registry.connection = nil
        XCTAssertThrowsError(try factory.getCrowdloanFundsProvider(for: 8, chainId: "1"))
        registry.connection = MockConnection()
        registry.provider = nil
        XCTAssertThrowsError(try factory.getCrowdloanFundsProvider(for: 9, chainId: "1"))
        XCTAssertThrowsError(try factory.getBlockNumberProvider(for: "missing"))
    }

    func testSubscriptionCacheKeepsOnlyLiveProvidersAndMissingRuntimeFails() throws {
        let registry = CovGHistoryRegistry()
        registry.provider = nil
        let factory = SubstrateLocalSubscriptionFactory(
            chainRegistry: registry, storageFacade: SubstrateStorageTestFacade(), operationManager: OperationManager(), logger: Logger.shared
        )
        var object: NSObject? = NSObject()
        try factory.saveProvider(XCTUnwrap(object), for: "test")
        XCTAssertTrue(factory.getProvider(for: "test") === object)
        object = nil
        factory.clearIfNeeded()
        XCTAssertNil(factory.getProvider(for: "test"))
        XCTAssertThrowsError(try factory.getDataProvider(
            for: "era", chainId: "missing", storageCodingPath: .currentEra, shouldUseFallback: false
        ) as AnyDataProvider<DecodedU32>)
    }

    private func check<T: RobinHood.Identifiable>(
        _ factory: SubstrateLocalSubscriptionFactory, key: String, create: () throws -> AnyDataProvider<T>
    ) throws {
        let first = try create()
        let cached = try XCTUnwrap(factory.getProvider(for: key))
        let second = try create()
        XCTAssertTrue(factory.getProvider(for: key) === cached)
        withExtendedLifetime([first, second]) { XCTAssertNotNil(factory.getProvider(for: key)) }
    }
}

final class CovGCrowdloanSubscriberTests: XCTestCase {
    func testBlockNumberSubscriptionForwardsLatestValueDeletionAndErrors() throws {
        let factory = CovGCrowdloanFactory()
        let subscriber = CovGCrowdloanSubscriber(factory: factory)
        XCTAssertNotNil(subscriber.subscribeToBlockNumber(for: "chain"))
        XCTAssertTrue(factory.block.observer === subscriber)
        XCTAssertTrue(factory.block.queue === DispatchQueue.main)
        XCTAssertEqual(factory.chain, "chain")
        factory.block.update?([.insert(newItem: DecodedBlockNumber(identifier: "block", item: fearless.StringScaleMapper(value: 42)))])
        XCTAssertEqual(try XCTUnwrap(subscriber.block).get(), 42)
        factory.block.update?([.delete(deletedIdentifier: "block")])
        XCTAssertNil(try XCTUnwrap(subscriber.block).get())
        factory.block.failure?(NSError(domain: "CovG.block", code: 92))
        XCTAssertThrowsError(try XCTUnwrap(subscriber.block).get()) { XCTAssertEqual(($0 as NSError).code, 92) }
        factory.error = NSError(domain: "CovG.factory", code: 1)
        XCTAssertNil(subscriber.subscribeToBlockNumber(for: "chain"))
    }

    func testFundSubscriptionPreservesParaAndChainAndForwardsFailure() throws {
        let factory = CovGCrowdloanFactory()
        let subscriber = CovGCrowdloanSubscriber(factory: factory)
        XCTAssertNotNil(subscriber.subscribeToCrowdloanFunds(for: 7, chainId: "chain"))
        XCTAssertEqual(factory.para, 7)
        XCTAssertEqual(factory.chain, "chain")
        factory.funds.update?([])
        XCTAssertNil(try XCTUnwrap(subscriber.funds).get())
        XCTAssertEqual(subscriber.para, 7)
        XCTAssertEqual(subscriber.chain, "chain")
        factory.funds.failure?(NSError(domain: "CovG.funds", code: 93))
        XCTAssertThrowsError(try XCTUnwrap(subscriber.funds).get()) { XCTAssertEqual(($0 as NSError).code, 93) }
        factory.error = NSError(domain: "CovG.factory", code: 1)
        XCTAssertNil(subscriber.subscribeToCrowdloanFunds(for: 7, chainId: "chain"))
    }
}

private final class CovGCrowdloanSubscriber: CrowdloanLocalStorageSubscriber, CrowdloanLocalSubscriptionHandler {
    let crowdloanLocalSubscriptionFactory: CrowdloanLocalSubscriptionFactoryProtocol
    var block: Result<BlockNumber?, Error>?
    var funds: Result<CrowdloanFunds?, Error>?
    var para: ParaId?
    var chain: String?
    init(factory: CrowdloanLocalSubscriptionFactoryProtocol) {
        crowdloanLocalSubscriptionFactory = factory
    }

    func handleBlockNumber(result: Result<BlockNumber?, Error>, chainId: ChainModel.Id) {
        block = result; chain = chainId
    }

    func handleCrowdloanFunds(result: Result<CrowdloanFunds?, Error>, for paraId: ParaId, chainId: ChainModel.Id) {
        funds = result; para = paraId; chain = chainId
    }
}

private final class CovGCrowdloanFactory: CrowdloanLocalSubscriptionFactoryProtocol {
    let block = CovGObservedProvider<DecodedBlockNumber>()
    let funds = CovGObservedProvider<DecodedCrowdloanFunds>()
    var error: Error?
    var chain: String?
    var para: ParaId?
    func getBlockNumberProvider(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedBlockNumber> {
        if let error {
            throw error
        }
        chain = chainId; return AnyDataProvider(block)
    }

    func getCrowdloanFundsProvider(for paraId: ParaId, chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedCrowdloanFunds> {
        if let error {
            throw error
        }
        chain = chainId; para = paraId; return AnyDataProvider(funds)
    }
}
