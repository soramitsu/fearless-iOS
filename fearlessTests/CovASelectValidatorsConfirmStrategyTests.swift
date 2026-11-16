import BigInt
import IrohaCrypto
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import XCTest
@testable import fearless

final class CovASignerStub: SigningWrapperProtocol {
    func sign(_: Data) throws -> IRSignatureProtocol {
        throw CovATestError.failed
    }
}

struct CovADurationFactoryStub: StakingDurationOperationFactoryProtocol {
    var duration = StakingDuration(session: 3600, era: 21600, unlocking: 604_800)

    func createDurationOperation(from _: RuntimeCodingServiceProtocol) -> CompoundOperationWrapper<StakingDuration> {
        let duration = self.duration
        return CompoundOperationWrapper(targetOperation: ClosureOperation { duration })
    }
}

final class CovAPoolOperationFactoryStub: StakingPoolOperationFactoryProtocol {
    var poolName: String? = "Cov Pool"
    var error: Error?

    private func wrapper<T>(_ value: T) -> CompoundOperationWrapper<T> {
        let error = self.error
        return CompoundOperationWrapper(targetOperation: ClosureOperation {
            if let error = error {
                throw error
            }
            return value
        })
    }

    func fetchBondedPoolsOperation() -> CompoundOperationWrapper<[StakingPool]> {
        wrapper([])
    }

    func fetchPoolMetadataOperation(poolId _: String) -> CompoundOperationWrapper<String?> {
        wrapper(poolName)
    }

    func fetchMinJoinBondOperation() -> CompoundOperationWrapper<BigUInt?> {
        wrapper(nil)
    }

    func fetchMinCreateBondOperation() -> CompoundOperationWrapper<BigUInt?> {
        wrapper(nil)
    }

    func fetchStakingPoolMembers(accountId _: AccountId) -> CompoundOperationWrapper<StakingPoolMember?> {
        wrapper(nil)
    }

    func fetchMaxStakingPoolsCount() -> CompoundOperationWrapper<UInt32?> {
        wrapper(nil)
    }

    func fetchMaxPoolMembers() -> CompoundOperationWrapper<UInt32?> {
        wrapper(nil)
    }

    func fetchCounterForBondedPools() -> CompoundOperationWrapper<UInt32?> {
        wrapper(nil)
    }

    func fetchMaxPoolMembersPerPool() -> CompoundOperationWrapper<UInt32?> {
        wrapper(nil)
    }

    func fetchBondedPoolOperation(poolId _: String) -> CompoundOperationWrapper<StakingPool?> {
        wrapper(nil)
    }

    func fetchPoolRewardsOperation(poolId _: String) -> CompoundOperationWrapper<StakingPoolRewards?> {
        wrapper(nil)
    }

    func fetchLastPoolId() -> CompoundOperationWrapper<UInt32?> {
        wrapper(nil)
    }

    func fetchPendingRewards(accountId _: AccountId) -> CompoundOperationWrapper<BigUInt?> {
        wrapper(nil)
    }
}

final class CovASelectValidatorsConfirmStrategyTests: XCTestCase {
    private typealias CovAFixtureAlias = CovAConfirmFixtures

    private func subscriptionFactory() -> StakingLocalSubscriptionFactoryStub {
        StakingLocalSubscriptionFactoryStub(
            minNominatorBond: BigUInt(1_000_000_000_000),
            counterForNominators: 3,
            maxNominatorsCount: 30
        )
    }

    private func extrinsics(success: Bool) -> ExtrinsicServiceStub {
        ExtrinsicServiceStub(
            dispatchInfo: success ? .success(RuntimeDispatchInfo(feeValue: BigUInt(10_000_000_000))) : .failure(CovATestError.failed),
            txHash: success ? .success("0xhash") : .failure(CovATestError.failed)
        )
    }

    private func closure() -> ExtrinsicBuilderClosure {
        { builder in builder }
    }

    /// Drives one strategy through setup, fee estimation, submission and the balance handler.
    private func exercise(
        _ strategy: SelectValidatorsConfirmStrategy,
        adapter: CovAAccountInfoAdapterStub,
        listener: CovAConfirmListenerSpy,
        expectsPoolName: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        strategy.setup()
        strategy.subscribeToBalance()
        strategy.estimateFee(closure: nil)
        strategy.submitNomination(closure: nil)
        strategy.estimateFee(closure: closure())
        strategy.submitNomination(closure: closure())
        let expectedHints = 1
        CovAViewInspector.spin(until: {
            listener.count("hints") >= expectedHints && listener.events.contains("complete:0xhash") && listener.count("fee") >= 1
                && (!expectsPoolName || listener.count("confirmation") >= 2)
        })
        XCTAssertEqual(listener.count("hints"), 1, file: file, line: line)
        XCTAssertEqual(listener.count("fee"), 1, file: file, line: line)
        XCTAssertTrue(listener.events.contains("start"), file: file, line: line)
        XCTAssertTrue(listener.events.contains("complete:0xhash"), file: file, line: line)
        XCTAssertEqual(adapter.subscribedAccountIds.count, 1, file: file, line: line)
        adapter.handler?.handleAccountInfo(
            result: .success(WestendStub.accountInfo.item),
            accountId: CovAFixtures.accountId(7),
            chainAsset: CovAFixtureAlias.chainAsset
        )
    }

    func testRelaychainInitiatedStrategy() {
        let state = CovAFixtureAlias.relaychainInitiated()
        let listener = CovAConfirmListenerSpy()
        state.setStateListener(listener)
        let adapter = CovAAccountInfoAdapterStub()
        let strategy = SelectValidatorsConfirmRelaychainInitiatedStrategy(
            accountInfoSubscriptionAdapter: adapter,
            balanceAccountId: CovAFixtures.accountId(7),
            stakingLocalSubscriptionFactory: subscriptionFactory(),
            extrinsicService: extrinsics(success: true),
            runtimeService: CovARuntimeCodingServiceStub(),
            durationOperationFactory: CovADurationFactoryStub(),
            operationManager: OperationManager(),
            signer: CovASignerStub(),
            chainAsset: CovAFixtureAlias.chainAsset,
            output: state
        )
        exercise(strategy, adapter: adapter, listener: listener, expectsPoolName: false)
        XCTAssertEqual(state.balance, 10)
        XCTAssertEqual(state.stakingDuration?.unlocking, 604_800)
        XCTAssertNotNil(state.confirmationModel)
        strategy.handleMinNominatorBond(result: .success(BigUInt(3_000_000_000_000)), chainId: CovAFixtures.chainId)
        strategy.handleCounterForNominators(result: .success(4), chainId: CovAFixtures.chainId)
        strategy.handleMaxNominatorsCount(result: .success(40), chainId: CovAFixtures.chainId)
        XCTAssertEqual(state.minNominatorBond, 3)
        XCTAssertEqual(state.counterForNominators, 4)
        XCTAssertEqual(state.maxNominatorsCount, 40)
    }

    func testRelaychainExistingStrategyFailures() {
        let state = CovAFixtureAlias.relaychainExisting()
        let listener = CovAConfirmListenerSpy()
        state.setStateListener(listener)
        let adapter = CovAAccountInfoAdapterStub()
        let strategy = SelectValidatorsConfirmRelaychainExistingStrategy(
            balanceAccountId: CovAFixtures.accountId(7),
            stakingLocalSubscriptionFactory: subscriptionFactory(),
            extrinsicService: extrinsics(success: false),
            runtimeService: CovARuntimeCodingServiceStub(),
            durationOperationFactory: CovADurationFactoryStub(),
            operationManager: OperationManager(),
            signer: CovASignerStub(),
            chainAsset: CovAFixtureAlias.chainAsset,
            output: state,
            accountInfoSubscriptionAdapter: adapter
        )
        strategy.setup()
        strategy.subscribeToBalance()
        strategy.estimateFee(closure: closure())
        strategy.submitNomination(closure: closure())
        CovAViewInspector.spin(until: { listener.events.contains("fail") && listener.count("confirmation") >= 1 })
        XCTAssertTrue(listener.events.contains("fail"))
        XCTAssertGreaterThanOrEqual(listener.count("error"), 1, "the fee error is reported")
        XCTAssertGreaterThanOrEqual(listener.count("confirmation"), 1)
        strategy.handleAccountInfo(result: .failure(CovATestError.failed), accountId: CovAFixtures.accountId(7), chainAsset: CovAFixtureAlias.chainAsset)
        strategy.handleMinNominatorBond(result: .failure(CovATestError.failed), chainId: CovAFixtures.chainId)
        strategy.handleCounterForNominators(result: .success(nil), chainId: CovAFixtures.chainId)
        strategy.handleMaxNominatorsCount(result: .success(nil), chainId: CovAFixtures.chainId)
        XCTAssertNil(state.maxNominatorsCount)
        XCTAssertEqual(adapter.subscribedAccountIds.count, 1)
    }

    func testPoolInitiatedStrategyFetchesPoolName() {
        let state = CovAFixtureAlias.poolInitiated()
        let listener = CovAConfirmListenerSpy()
        state.setStateListener(listener)
        let adapter = CovAAccountInfoAdapterStub()
        let strategy = SelectValidatorsConfirmPoolInitiatedStrategy(
            accountInfoSubscriptionAdapter: adapter,
            balanceAccountId: CovAFixtures.accountId(7),
            stakingLocalSubscriptionFactory: subscriptionFactory(),
            extrinsicService: extrinsics(success: true),
            runtimeService: CovARuntimeCodingServiceStub(),
            durationOperationFactory: CovADurationFactoryStub(),
            operationManager: OperationManager(),
            signer: CovASignerStub(),
            chainAsset: CovAFixtureAlias.chainAsset,
            output: state,
            stakingPoolOperationFactory: CovAPoolOperationFactoryStub(),
            poolId: 3
        )
        exercise(strategy, adapter: adapter, listener: listener, expectsPoolName: true)
        XCTAssertEqual(state.poolName, "Cov Pool")
        XCTAssertEqual(state.balance, 10)
        strategy.handleMinNominatorBond(result: .success(nil), chainId: CovAFixtures.chainId)
        strategy.handleCounterForNominators(result: .success(1), chainId: CovAFixtures.chainId)
        strategy.handleMaxNominatorsCount(result: .success(2), chainId: CovAFixtures.chainId)
        XCTAssertEqual(state.maxNominatorsCount, 2)
    }

    func testPoolExistingStrategyReportsMetadataFailure() {
        let state = CovAFixtureAlias.poolExisting()
        let listener = CovAConfirmListenerSpy()
        state.setStateListener(listener)
        let adapter = CovAAccountInfoAdapterStub()
        let poolFactory = CovAPoolOperationFactoryStub()
        poolFactory.error = CovATestError.failed
        let strategy = SelectValidatorsConfirmPoolExistingStrategy(
            accountInfoSubscriptionAdapter: adapter,
            balanceAccountId: CovAFixtures.accountId(7),
            stakingLocalSubscriptionFactory: subscriptionFactory(),
            extrinsicService: extrinsics(success: true),
            runtimeService: CovARuntimeCodingServiceStub(),
            durationOperationFactory: CovADurationFactoryStub(),
            operationManager: OperationManager(),
            signer: CovASignerStub(),
            chainAsset: CovAFixtureAlias.chainAsset,
            output: state,
            stakingPoolOperationFactory: poolFactory,
            poolId: 4
        )
        strategy.setup()
        strategy.subscribeToBalance()
        strategy.estimateFee(closure: closure())
        strategy.submitNomination(closure: closure())
        CovAViewInspector.spin(until: { listener.events.contains("complete:0xhash") && listener.count("error") >= 1 })
        XCTAssertGreaterThanOrEqual(listener.count("error"), 1, "the pool metadata failure is reported")
        XCTAssertEqual(listener.count("fee"), 1)
        strategy.handleAccountInfo(result: .success(nil), accountId: CovAFixtures.accountId(7), chainAsset: CovAFixtureAlias.chainAsset)
        XCTAssertEqual(state.balance, 0)
        strategy.handleMinNominatorBond(result: .success(BigUInt(1)), chainId: CovAFixtures.chainId)
        strategy.handleCounterForNominators(result: .failure(CovATestError.failed), chainId: CovAFixtures.chainId)
        strategy.handleMaxNominatorsCount(result: .failure(CovATestError.failed), chainId: CovAFixtures.chainId)
        XCTAssertGreaterThanOrEqual(listener.count("error"), 3)
    }
}
