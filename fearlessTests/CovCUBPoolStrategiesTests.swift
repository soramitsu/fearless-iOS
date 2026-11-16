import XCTest
import BigInt
import RobinHood
import SSFModels
@testable import fearless

/// The redeem and redeem-confirmation pool strategies share one shape.
protocol CovCUBRedeemPoolStrategyDriving: AnyObject {
    func setup()
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?)
    func submit(builderClosure: ExtrinsicBuilderClosure?)
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId: AccountId, chainAsset: ChainAsset)
    func handlePoolMember(result: Result<StakingPoolMember?, Error>, accountId: AccountId, chainId: ChainModel.Id)
    func handleActiveEra(result: Result<ActiveEraInfo?, Error>, chainId: ChainModel.Id)
    func didReceiveFee(result: Result<fearless.RuntimeDispatchInfo, Error>, for identifier: ExtrinsicFeeId)
}

extension StakingRedeemPoolStrategy: CovCUBRedeemPoolStrategyDriving {}
extension StakingRedeemConfirmationPoolStrategy: CovCUBRedeemPoolStrategyDriving {}

final class CovCUBPoolStrategiesTests: XCTestCase {
    private var chainAsset: ChainAsset!
    private var wallet: fearless.MetaAccountModel!
    private var kit: CovCUBStrategyKit!
    private var validatingFactory: StakingDataValidatingFactory!

    override func setUp() {
        super.setUp()
        chainAsset = CovCUBFixture.chainAsset()
        wallet = CovCUBFixture.wallet()
        kit = CovCUBStrategyKit(chainAsset: chainAsset, wallet: wallet)
        validatingFactory = StakingDataValidatingFactory(presentable: CovCUBStakingErrorSpy())
    }

    override func tearDown() {
        chainAsset = nil
        wallet = nil
        kit = nil
        validatingFactory = nil
        super.tearDown()
    }

    private var accountId: AccountId {
        get throws { try CovCUBFixture.account(for: chainAsset, wallet: wallet).accountId }
    }

    // MARK: - Unbond setup

    private func makeUnbondSetup() -> (StakingUnbondSetupPoolStrategy, StakingUnbondSetupPoolViewModelState, CovCUBUnbondSetupListenerSpy) {
        let listener = CovCUBUnbondSetupListenerSpy()
        let state = StakingUnbondSetupPoolViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            dataValidatingFactory: validatingFactory,
            callFactory: kit.callFactory
        )
        state.setStateListener(listener)
        let strategy = StakingUnbondSetupPoolStrategy(
            stakingLocalSubscriptionFactory: kit.subscriptions,
            accountInfoSubscriptionAdapter: kit.accountInfo,
            operationManager: kit.operations,
            feeProxy: kit.feeProxy,
            wallet: wallet,
            chainAsset: chainAsset,
            output: state,
            extrinsicService: kit.extrinsicService,
            stakingPoolOperationFactory: kit.pools,
            stakingDurationOperationFactory: kit.durations,
            runtimeService: kit.runtime,
            callFactory: kit.callFactory
        )
        return (strategy, state, listener)
    }

    func testUnbondSetupPoolStrategySetupLoadsDurationAndNotifies() throws {
        let (strategy, state, listener) = makeUnbondSetup()

        strategy.setup()

        XCTAssertEqual(kit.accountInfo.subscribedAccounts, [try accountId])
        XCTAssertTrue(kit.feeProxy.delegate === strategy)
        XCTAssertEqual(listener.calls.first, "updateFee")
        CovCUBOperations.wait { state.stakingDuration != nil }
        XCTAssertEqual(state.stakingDuration?.unlocking, 7 * 86400)
        XCTAssertTrue(listener.calls.contains("duration"))
    }

    func testUnbondSetupPoolStrategyEstimatesWithCurrentAndOldCalls() throws {
        let (strategy, state, _) = makeUnbondSetup()

        strategy.estimateFee(builderClosure: nil, reuseIdentifier: "none")
        XCTAssertTrue(kit.feeProxy.reuseIdentifiers.isEmpty)

        strategy.estimateFee(builderClosure: state.builderClosure, reuseIdentifier: state.reuseIdentifier)
        strategy.estimateFee()
        strategy.estimateFeeOld()

        XCTAssertEqual(kit.feeProxy.reuseIdentifiers, [state.reuseIdentifier, "pool_unbond", "pool_unbond_old"])
        XCTAssertEqual(try CovCUBBuilderSpy.callNames(of: kit.feeProxy.closures[1]), ["pool_unbond"])
        XCTAssertEqual(try CovCUBBuilderSpy.callNames(of: kit.feeProxy.closures[2]), ["pool_unbond_old"])
        XCTAssertTrue(kit.feeProxy.delegate === strategy)
    }

    func testUnbondSetupPoolStrategyForwardsFeesAndRetriesWithOldCall() throws {
        let (strategy, state, listener) = makeUnbondSetup()

        strategy.didReceiveFee(result: .success(CovCUBFixture.dispatchInfo(fee: 0.4)), for: "id")
        XCTAssertEqual(state.fee, 0.4)
        XCTAssertTrue(kit.feeProxy.reuseIdentifiers.isEmpty)

        strategy.didReceiveFee(result: .failure(CovCUBTestError.failed), for: "id")
        XCTAssertEqual(listener.calls, ["fee", "error"])
        XCTAssertEqual(kit.feeProxy.reuseIdentifiers, ["pool_unbond_old"])

        strategy.handleAccountInfo(result: .success(CovCUBFixture.accountInfo(free: 8)), accountId: try accountId, chainAsset: chainAsset)
        XCTAssertEqual(state.balance, 8)
    }

    func testUnbondSetupPoolStrategyHandlesPoolMembers() throws {
        let (strategy, state, listener) = makeUnbondSetup()
        let accountId = try self.accountId

        strategy.handlePoolMember(result: .success(nil), accountId: accountId, chainId: "c")
        XCTAssertTrue(kit.pools.requestedPoolIds.isEmpty)
        XCTAssertNil(state.bonded)

        kit.pools.bondedPool = try CovCUBFixture.stakingPool(depositor: accountId)
        strategy.handlePoolMember(result: .success(try CovCUBFixture.poolMember(points: 5)), accountId: accountId, chainId: "c")
        XCTAssertEqual(state.bonded, 5)
        XCTAssertEqual(kit.pools.requestedPoolIds, ["7"])

        strategy.handlePoolMember(result: .failure(CovCUBTestError.failed), accountId: accountId, chainId: "c")
        XCTAssertEqual(listener.calls, ["asset", "error"])
    }

    // MARK: - Unbond confirm

    private func makeUnbondConfirm(
        withService: Bool
    ) throws -> (StakingUnbondConfirmPoolStrategy, StakingUnbondConfirmPoolViewModelState, CovCUBUnbondConfirmListenerSpy) {
        let listener = CovCUBUnbondConfirmListenerSpy()
        let state = StakingUnbondConfirmPoolViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            dataValidatingFactory: validatingFactory,
            inputAmount: 2,
            callFactory: kit.callFactory
        )
        state.setStateListener(listener)
        let strategy = StakingUnbondConfirmPoolStrategy(
            output: state,
            accountInfoSubscriptionAdapter: kit.accountInfo,
            runtimeService: kit.runtime,
            operationManager: kit.operations,
            feeProxy: kit.feeProxy,
            chainAsset: chainAsset,
            wallet: wallet,
            connection: kit.engine,
            keystore: kit.keystore,
            extrinsicService: withService ? kit.extrinsicService : nil,
            signingWrapper: withService ? try kit.signingWrapper() : nil,
            eventCenter: kit.eventCenter,
            stakingLocalSubscriptionFactory: kit.subscriptions,
            callFactory: kit.callFactory
        )
        return (strategy, state, listener)
    }

    func testUnbondConfirmPoolStrategySetupAndGuards() throws {
        let (strategy, state, listener) = try makeUnbondConfirm(withService: false)

        strategy.estimateFee(builderClosure: state.builderClosure, reuseIdentifier: "id")
        strategy.submit(builderClosure: state.builderClosure)
        XCTAssertEqual(listener.calls, ["error", "feeError", "submit"])
        XCTAssertEqual(kit.extrinsicService.submissions, 0)

        listener.reset()
        strategy.setup()
        XCTAssertEqual(kit.accountInfo.subscribedAccounts, [try accountId])
        XCTAssertTrue(kit.feeProxy.delegate === strategy)
        CovCUBOperations.wait { listener.calls.contains("error") }
        XCTAssertEqual(listener.calls, ["error"])
    }

    func testUnbondConfirmPoolStrategyEstimatesSubmitsAndForwards() throws {
        let (strategy, state, listener) = try makeUnbondConfirm(withService: true)
        let accountId = try self.accountId

        strategy.estimateFee(builderClosure: state.builderClosure, reuseIdentifier: state.reuseIdentifier)
        XCTAssertEqual(kit.feeProxy.reuseIdentifiers, ["pool_unbond"])

        strategy.submit(builderClosure: state.builderClosure)
        XCTAssertEqual(kit.extrinsicService.submissions, 1)
        XCTAssertEqual(try listener.submissions.last?.get(), "0xsubmitted")
        XCTAssertEqual(kit.eventCenter.events.count, 1)
        XCTAssertTrue(kit.eventCenter.events.first is StakingUpdatedEvent)

        strategy.handleAccountInfo(result: .success(CovCUBFixture.accountInfo(free: 5)), accountId: accountId, chainAsset: chainAsset)
        strategy.didReceiveFee(result: .success(CovCUBFixture.dispatchInfo(fee: 0.2)), for: "id")
        strategy.handlePoolMember(result: .success(try CovCUBFixture.poolMember(points: 4)), accountId: accountId, chainId: "c")
        strategy.handlePoolMember(result: .failure(CovCUBTestError.failed), accountId: accountId, chainId: "c")

        XCTAssertEqual(state.balance, 5)
        XCTAssertEqual(state.fee, 0.2)
        XCTAssertEqual(state.bonded, 4)
        XCTAssertEqual(listener.calls, ["submit", "fee", "asset", "error"])
    }

    // MARK: - Redeem (both modules)

    private func redeemTriples(
    ) throws -> [(CovCUBRedeemPoolStrategyDriving, CovCUBRedeemPoolDriving, CovCUBRedeemListenerSpy)] {
        let redeemListener = CovCUBRedeemListenerSpy()
        let redeemState = StakingRedeemPoolViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            dataValidatingFactory: validatingFactory,
            callFactory: kit.callFactory
        )
        redeemState.setStateListener(redeemListener)
        let redeem = StakingRedeemPoolStrategy(
            output: redeemState,
            accountInfoSubscriptionAdapter: kit.accountInfo,
            chainAsset: chainAsset,
            wallet: wallet,
            extrinsicService: kit.extrinsicService,
            signingWrapper: try kit.signingWrapper(),
            feeProxy: kit.feeProxy,
            runtimeService: kit.runtime,
            engine: kit.engine,
            operationManager: kit.operations,
            keystore: kit.keystore,
            eventCenter: kit.eventCenter,
            slashesOperationFactory: kit.slashes,
            stakingLocalSubscriptionFactory: kit.subscriptions
        )

        let confirmListener = CovCUBRedeemListenerSpy()
        let confirmState = StakingRedeemConfirmationPoolViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            dataValidatingFactory: validatingFactory,
            callFactory: kit.callFactory
        )
        confirmState.setStateListener(confirmListener)
        let confirm = StakingRedeemConfirmationPoolStrategy(
            output: confirmState,
            accountInfoSubscriptionAdapter: kit.accountInfo,
            chainAsset: chainAsset,
            wallet: wallet,
            extrinsicService: kit.extrinsicService,
            signingWrapper: try kit.signingWrapper(),
            feeProxy: kit.feeProxy,
            runtimeService: kit.runtime,
            engine: kit.engine,
            operationManager: kit.operations,
            keystore: kit.keystore,
            eventCenter: kit.eventCenter,
            slashesOperationFactory: kit.slashes,
            stakingLocalSubscriptionFactory: kit.subscriptions
        )
        return [(redeem, redeemState, redeemListener), (confirm, confirmState, confirmListener)]
    }

    func testRedeemPoolStrategiesSetupLoadsSlashingSpans() throws {
        kit.slashes.spans = try CovCUBFixture.slashingSpans(priorCount: 1)
        let address = try CovCUBFixture.address(for: chainAsset, wallet: wallet)
        let triples = try redeemTriples()

        for (strategy, state, listener) in triples {
            strategy.setup()
            XCTAssertTrue(kit.feeProxy.delegate === strategy)
            CovCUBOperations.wait { state.numberOfSlashingSpans != nil && listener.calls.contains("error") }
            XCTAssertEqual(state.numberOfSlashingSpans, 2)
            XCTAssertTrue(listener.calls.contains("refresh"))
            XCTAssertTrue(listener.calls.contains("error"))
        }
        XCTAssertEqual(kit.slashes.stashes, [address, address])
        XCTAssertEqual(kit.accountInfo.subscribedAccounts, [try accountId, try accountId])
    }

    func testRedeemPoolStrategiesEstimateAndSubmit() throws {
        let triples = try redeemTriples()

        for (strategy, state, listener) in triples {
            strategy.estimateFee(builderClosure: nil, reuseIdentifier: "id")
            strategy.submit(builderClosure: nil)
            XCTAssertEqual(listener.calls, ["error", "submit"])

            state.didReceiveSlashingSpans(result: .success(nil))
            strategy.estimateFee(builderClosure: state.builderClosure, reuseIdentifier: state.reuseIdentifier)
            strategy.submit(builderClosure: state.builderClosure)
            XCTAssertEqual(try listener.submissions.last?.get(), "0xsubmitted")
        }
        XCTAssertEqual(kit.feeProxy.reuseIdentifiers, ["1", "1"])
        XCTAssertEqual(kit.extrinsicService.submissions, 2)
        XCTAssertEqual(kit.eventCenter.events.count, 2)
    }

    func testRedeemPoolStrategiesForwardSubscriptions() throws {
        let accountId = try self.accountId
        for (strategy, state, _) in try redeemTriples() {
            strategy.handleAccountInfo(result: .success(CovCUBFixture.accountInfo(free: 3)), accountId: accountId, chainAsset: chainAsset)
            strategy.didReceiveFee(result: .success(CovCUBFixture.dispatchInfo(fee: 0.3)), for: "id")
            strategy.handlePoolMember(
                result: .success(try CovCUBFixture.poolMember(points: 1, unbonding: [(1, 2)])),
                accountId: accountId,
                chainId: "c"
            )
            strategy.handleActiveEra(result: .success(CovCUBFixture.activeEra(6)), chainId: "c")

            XCTAssertEqual(state.balance, 3)
            XCTAssertEqual(state.fee, 0.3)
            XCTAssertEqual(state.stakeInfo?.unbondingEras.count, 1)
            XCTAssertEqual(state.activeEra, 6)
        }
    }
}
