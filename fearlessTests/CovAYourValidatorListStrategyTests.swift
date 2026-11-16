import BigInt
import RobinHood
import SSFModels
import SSFUtils
import XCTest
@testable import fearless

final class CovAYourValidatorListStrategyTests: XCTestCase {
    private typealias CovAFixtureAlias = CovAYourValidatorFixtures

    private func relaychainStrategy(
        factory: CovAValidatorOperationFactoryStub,
        output: YourValidatorListRelaychainViewModelState
    ) -> YourValidatorListRelaychainStrategy {
        let facade = SubstrateStorageTestFacade()
        let repository = AccountRepositoryFactory(storageFacade: UserDataStorageTestFacade())
            .createMetaAccountRepository(for: nil, sortDescriptors: [])
        return YourValidatorListRelaychainStrategy(
            chainAsset: CovAFixtureAlias.chainAsset,
            wallet: CovAFixtureAlias.wallet,
            substrateProviderFactory: SubstrateDataProviderFactory(facade: facade, operationManager: OperationManager()),
            runtimeService: CovARuntimeCodingServiceStub(),
            eraValidatorService: EraValidatorServiceStub.westendStub(),
            validatorOperationFactory: factory,
            operationManager: OperationManager(),
            stakingLocalSubscriptionFactory: CovAYourValidatorSubscriptionFactory(),
            accountRepository: repository,
            output: output
        )
    }

    func testRelaychainStrategyLoadsCurrentAndPendingValidators() throws {
        let state = YourValidatorListRelaychainViewModelState(chainAsset: CovAFixtureAlias.chainAsset, wallet: CovAFixtureAlias.wallet)
        let listener = CovAYourValidatorListListenerSpy()
        state.setStateListener(listener)
        let factory = CovAValidatorOperationFactoryStub()
        factory.selectedResult = [CovAFixtures.validator(1), CovAFixtures.validator(2)]
        let strategy = relaychainStrategy(factory: factory, output: state)

        strategy.handleActiveEra(result: .success(ActiveEraInfo(index: 10)), chainId: CovAFixtures.chainId)
        strategy.handleStashItem(
            result: .success(StashItem(stash: CovAFixtures.address(7), controller: CovAFixtures.address(7))),
            for: CovAFixtures.address(7)
        )
        try strategy.handleLedgerInfo(result: .success(CovAFixtureAlias.ledger()), accountId: CovAFixtures.accountId(7), chainId: CovAFixtures.chainId)
        strategy.handlePayee(result: .success(.staked), accountId: CovAFixtures.accountId(7), chainId: CovAFixtures.chainId)

        // a nomination submitted in the active era waits: active and pending validators are merged
        try strategy.handleNomination(
            result: .success(CovAStakingMainFixtures.nomination(submittedIn: 10)),
            accountId: CovAFixtures.accountId(7),
            chainId: CovAFixtures.chainId
        )
        CovAViewInspector.spin(until: { state.validatorsModel?.pendingValidators.isEmpty == false })
        XCTAssertEqual(state.validatorsModel?.currentValidators.count, 2)
        XCTAssertEqual(state.validatorsModel?.pendingValidators.count, 2)
        XCTAssertEqual(factory.activeRequests, [CovAFixtures.address(7)])

        // an older nomination only lists the selected validators
        try strategy.handleNomination(
            result: .success(CovAStakingMainFixtures.nomination(submittedIn: 2)),
            accountId: CovAFixtures.accountId(7),
            chainId: CovAFixtures.chainId
        )
        CovAViewInspector.spin(until: { state.validatorsModel?.pendingValidators.isEmpty == true })
        XCTAssertEqual(state.validatorsModel?.pendingValidators.count, 0)
        XCTAssertGreaterThanOrEqual(listener.changes, 2)

        strategy.handlePayee(result: .failure(CovATestError.failed), accountId: CovAFixtures.accountId(7), chainId: CovAFixtures.chainId)
        strategy.handleNomination(result: .success(nil), accountId: CovAFixtures.accountId(7), chainId: CovAFixtures.chainId)
        strategy.handleStashItem(result: .success(nil), for: CovAFixtures.address(7))
        XCTAssertNil(state.validatorsModel, "no stash clears the list")
        strategy.setup()
        strategy.refresh()
        strategy.clearActiveEraSubscription()
        strategy.clearAllSubscriptions()
        strategy.fetchController(for: CovAFixtures.address(7))
        CovAViewInspector.spin(until: { false }, timeout: 0.3)
    }

    func testRelaychainStrategyReportsValidatorFailure() throws {
        let state = YourValidatorListRelaychainViewModelState(chainAsset: CovAFixtureAlias.chainAsset, wallet: CovAFixtureAlias.wallet)
        let factory = CovAValidatorOperationFactoryStub()
        factory.error = CovATestError.failed
        let strategy = relaychainStrategy(factory: factory, output: state)
        state.didReceiveValidators(result: .success(CovAFixtureAlias.model()))
        strategy.handleActiveEra(result: .success(ActiveEraInfo(index: 10)), chainId: CovAFixtures.chainId)
        strategy.handleStashItem(
            result: .success(StashItem(stash: CovAFixtures.address(7), controller: CovAFixtures.address(7))),
            for: CovAFixtures.address(7)
        )
        try strategy.handleNomination(
            result: .success(CovAStakingMainFixtures.nomination(submittedIn: 1)),
            accountId: CovAFixtures.accountId(7),
            chainId: CovAFixtures.chainId
        )
        CovAViewInspector.spin(until: { state.validatorsModel == nil })
        XCTAssertNil(state.validatorsModel, "a failed load clears the list")
    }

    func testPoolStrategyLoadsPoolAndReportsMissingPalletId() throws {
        let state = YourValidatorListPoolViewModelState(chainAsset: CovAFixtureAlias.chainAsset, wallet: CovAFixtureAlias.wallet)
        let listener = CovAYourValidatorListListenerSpy()
        state.setStateListener(listener)
        let poolFactory = CovAPoolOperationFactoryStub()
        let strategy = YourValidatorListPoolStrategy(
            stakingPoolOperationFactory: poolFactory,
            chainAsset: CovAFixtureAlias.chainAsset,
            wallet: CovAFixtureAlias.wallet,
            eraValidatorService: EraValidatorServiceStub.westendStub(),
            operationManager: OperationManager(),
            chainRegistry: ChainRegistryProtocolStub(),
            eraCountdownOperationFactory: EraCountdownOperationFactoryStub(eraCountdown: .testStub),
            stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryStub(),
            runtimeService: CovARuntimeCodingServiceStub(),
            validatorOperationFactory: CovAValidatorOperationFactoryStub(),
            output: state
        )
        strategy.setup()
        CovAViewInspector.spin(until: { !listener.errors.isEmpty })
        XCTAssertFalse(listener.errors.isEmpty, "the pallet id cannot be read from a runtime without metadata")

        try strategy.handlePoolMember(result: .success(CovAFixtureAlias.poolMember()), accountId: CovAFixtures.accountId(7), chainId: CovAFixtures.chainId)
        strategy.handleActiveEra(result: .success(ActiveEraInfo(index: 10)), chainId: CovAFixtures.chainId)
        strategy.handlePoolMember(result: .failure(CovATestError.failed), accountId: CovAFixtures.accountId(7), chainId: CovAFixtures.chainId)
        let errorsBefore = listener.errors.count
        CovAViewInspector.spin(until: { listener.errors.count > errorsBefore })
        XCTAssertGreaterThan(listener.errors.count, errorsBefore)
        strategy.refresh()
        CovAViewInspector.spin(until: { false }, timeout: 0.3)
    }
}

/// Handler tests deliver storage changes explicitly; no background stash snapshot should overwrite them.
final class CovAYourValidatorSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol {
    private let base = StakingLocalSubscriptionFactoryStub()
    private let facade = SubstrateStorageTestFacade()

    func getStashItemProvider(for address: AccountAddress) -> StreamableProvider<StashItem> {
        SubstrateDataProviderFactory(facade: facade, operationManager: CovAUndeliveredSnapshotManager())
            .createStashItemProvider(for: address)
    }

    func getMinNominatorBondProvider(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedBigUInt> {
        try base.getMinNominatorBondProvider(for: chainId)
    }

    func getCounterForNominatorsProvider(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedU32> {
        try base.getCounterForNominatorsProvider(for: chainId)
    }

    func getMaxNominatorsCountProvider(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedU32> {
        try base.getMaxNominatorsCountProvider(for: chainId)
    }

    func getNominationProvider(for accountId: AccountId, chainAsset: ChainAsset) throws -> AnyDataProvider<DecodedNomination> {
        try base.getNominationProvider(for: accountId, chainAsset: chainAsset)
    }

    func getValidatorProvider(for accountId: AccountId, chainAsset: ChainAsset) throws -> AnyDataProvider<DecodedValidator> {
        try base.getValidatorProvider(for: accountId, chainAsset: chainAsset)
    }

    func getLedgerInfoProvider(for accountId: AccountId, chainAsset: ChainAsset) throws -> AnyDataProvider<DecodedLedgerInfo> {
        try base.getLedgerInfoProvider(for: accountId, chainAsset: chainAsset)
    }

    func getActiveEra(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedActiveEra> {
        try base.getActiveEra(for: chainId)
    }

    func getCurrentEra(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedEraIndex> {
        try base.getCurrentEra(for: chainId)
    }

    func getPayee(for accountId: AccountId, chainAsset: ChainAsset) throws -> AnyDataProvider<DecodedPayee> {
        try base.getPayee(for: accountId, chainAsset: chainAsset)
    }

    func getTotalReward(for address: AccountAddress, chain: ChainModel, assetPrecision: Int16) throws -> AnySingleValueProvider<TotalRewardItem> {
        try base.getTotalReward(for: address, chain: chain, assetPrecision: assetPrecision)
    }

    func getPoolMembersProvider(for chainAsset: ChainAsset, accountId: AccountId) throws -> AnyDataProvider<DecodedPoolMember> {
        try base.getPoolMembersProvider(for: chainAsset, accountId: accountId)
    }
}

/// Leaves the stash snapshot undelivered so each test controls the storage events, without a suspended queue.
final class CovAUndeliveredSnapshotManager: OperationManagerProtocol {
    func enqueue(operations: [Operation], in _: OperationMode) {
        for operation in operations {
            operation.completionBlock = nil
        }
    }
}
