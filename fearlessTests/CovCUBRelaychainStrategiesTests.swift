import XCTest
import BigInt
import RobinHood
import SSFModels
@testable import fearless

/// The redeem and redeem-confirmation relaychain strategies share one shape.
protocol CovCUBRedeemRelayStrategyDriving: AnyObject {
    func setup()
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?)
    func submit(builderClosure: ExtrinsicBuilderClosure?)
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId: AccountId, chainAsset: ChainAsset)
    func handleStashItem(result: Result<StashItem?, Error>, for address: AccountAddress)
    func handleLedgerInfo(result: Result<StakingLedger?, Error>, accountId: AccountId, chainId: ChainModel.Id)
    func handleActiveEra(result: Result<ActiveEraInfo?, Error>, chainId: ChainModel.Id)
    func didReceiveFee(result: Result<fearless.RuntimeDispatchInfo, Error>, for identifier: ExtrinsicFeeId)
}

extension StakingRedeemRelaychainStrategy: CovCUBRedeemRelayStrategyDriving {}
extension StakingRedeemConfirmationRelaychainStrategy: CovCUBRedeemRelayStrategyDriving {}

final class CovCUBRelaychainStrategiesTests: XCTestCase {
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

    private func controllerStash() throws -> StashItem {
        CovCUBFixture.stashItem(controller: try CovCUBFixture.address(for: chainAsset, wallet: wallet))
    }

    private var accountId: AccountId {
        get throws { try CovCUBFixture.account(for: chainAsset, wallet: wallet).accountId }
    }

    // MARK: - Unbond setup

    private func makeUnbondSetup(
        output: StakingUnbondSetupRelaychainStrategyOutput
    ) -> StakingUnbondSetupRelaychainStrategy {
        StakingUnbondSetupRelaychainStrategy(
            stakingLocalSubscriptionFactory: kit.subscriptions,
            accountInfoSubscriptionAdapter: kit.accountInfo,
            runtimeService: kit.runtime,
            operationManager: kit.operations,
            feeProxy: kit.feeProxy,
            wallet: wallet,
            chainAsset: chainAsset,
            connection: kit.engine,
            accountRepository: kit.walletRepository,
            output: output,
            extrinsicService: kit.extrinsicService,
            callFactory: kit.callFactory
        )
    }

    private func unbondSetupState(listener: StakingUnbondSetupModelStateListener) -> StakingUnbondSetupRelaychainViewModelState {
        let state = StakingUnbondSetupRelaychainViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            dataValidatingFactory: validatingFactory,
            callFactory: kit.callFactory
        )
        state.setStateListener(listener)
        return state
    }

    func testUnbondSetupStrategySetupSubscribesAndReportsConstantFailures() throws {
        let listener = CovCUBUnbondSetupListenerSpy()
        let state = unbondSetupState(listener: listener)
        let strategy = makeUnbondSetup(output: state)

        strategy.setup()

        XCTAssertEqual(kit.subscriptions.stashRequests, [try CovCUBFixture.address(for: chainAsset, wallet: wallet)])
        XCTAssertTrue(kit.feeProxy.delegate === strategy)
        CovCUBOperations.wait { listener.calls.count >= 2 }
        XCTAssertEqual(listener.calls, ["error", "error"])
        XCTAssertNil(state.bondingDuration)
        XCTAssertNil(state.minimalBalance)
    }

    func testUnbondSetupStrategyForwardsSubscriptionsToOutput() throws {
        let listener = CovCUBUnbondSetupListenerSpy()
        let state = unbondSetupState(listener: listener)
        let strategy = makeUnbondSetup(output: state)
        let accountId = try self.accountId

        strategy.handleNomination(result: .success(try CovCUBFixture.nomination()), accountId: accountId, chainId: "c")
        strategy.handleMinNominatorBond(result: .success(CovCUBFixture.planks(5)), chainId: "c")
        strategy.handlePayee(result: .success(.staked), accountId: accountId, chainId: "c")
        strategy.handleLedgerInfo(result: .success(try CovCUBFixture.ledger(active: 9)), accountId: accountId, chainId: "c")
        strategy.handleAccountInfo(result: .success(CovCUBFixture.accountInfo(free: 4)), accountId: accountId, chainAsset: chainAsset)
        XCTAssertEqual(state.balance, 4)
        strategy.handleAccountInfo(result: .success(CovCUBFixture.accountInfo(free: 6)), address: "addr")
        strategy.didReceiveFee(result: .success(CovCUBFixture.dispatchInfo(fee: 0.3)), for: "fee-id")

        XCTAssertNotNil(state.nomination)
        XCTAssertEqual(state.minNominatorBonded, 5)
        XCTAssertEqual(state.payee, .staked)
        XCTAssertEqual(state.bonded, 9)
        XCTAssertEqual(state.balance, 6)
        XCTAssertEqual(state.fee, 0.3)
        XCTAssertEqual(listener.calls, ["updateFee", "updateFee", "updateFee", "asset", "fee"])
    }

    func testUnbondSetupStrategyEstimatesOnlyWithBuilder() throws {
        let state = unbondSetupState(listener: CovCUBUnbondSetupListenerSpy())
        let strategy = makeUnbondSetup(output: state)

        strategy.estimateFee(builderClosure: nil, reuseIdentifier: "none")
        XCTAssertTrue(kit.feeProxy.reuseIdentifiers.isEmpty)

        strategy.estimateFee(builderClosure: state.builderClosure, reuseIdentifier: "unbond-id")
        XCTAssertEqual(kit.feeProxy.reuseIdentifiers, ["unbond-id"])
        XCTAssertEqual(try CovCUBBuilderSpy.callNames(of: kit.feeProxy.closures.first), ["unbond"])
    }

    func testUnbondSetupStrategyHandlesStashItems() throws {
        let listener = CovCUBUnbondSetupListenerSpy()
        let state = unbondSetupState(listener: listener)
        let strategy = makeUnbondSetup(output: state)

        strategy.handleStashItem(result: .failure(CovCUBTestError.failed), for: "addr")
        XCTAssertEqual(listener.calls, ["error", "error", "error"])

        listener.reset()
        strategy.handleStashItem(result: .success(nil), for: "addr")
        XCTAssertNil(state.stashItem)
        XCTAssertNil(state.bonded)
        XCTAssertNil(state.balance)
        XCTAssertEqual(listener.calls, ["asset"])

        let stash = try controllerStash()
        strategy.handleStashItem(result: .success(stash), for: stash.stash)
        XCTAssertEqual(state.stashItem, stash)
        CovCUBOperations.wait { state.controller != nil }
        XCTAssertEqual(state.controller, try CovCUBFixture.account(for: chainAsset, wallet: wallet))
        XCTAssertEqual(kit.accountInfo.subscribedAccounts, [try accountId])
        XCTAssertEqual(listener.calls.last, "updateFee")
    }

    // MARK: - Unbond confirm

    private func makeUnbondConfirm(
        output: StakingUnbondConfirmRelaychainStrategyOutput
    ) -> StakingUnbondConfirmRelaychainStrategy {
        StakingUnbondConfirmRelaychainStrategy(
            output: output,
            accountInfoSubscriptionAdapter: kit.accountInfo,
            stakingLocalSubscriptionFactory: kit.subscriptions,
            runtimeService: kit.runtime,
            operationManager: kit.operations,
            feeProxy: kit.feeProxy,
            chainAsset: chainAsset,
            wallet: wallet,
            connection: kit.engine,
            keystore: kit.keystore,
            accountRepository: kit.walletRepository,
            callFactory: kit.callFactory
        )
    }

    private func unbondConfirmState(listener: CovCUBUnbondConfirmListenerSpy) -> StakingUnbondConfirmRelaychainViewModelState {
        let state = StakingUnbondConfirmRelaychainViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            dataValidatingFactory: validatingFactory,
            inputAmount: 1,
            callFactory: kit.callFactory
        )
        state.setStateListener(listener)
        return state
    }

    func testUnbondConfirmStrategyWithoutControllerFailsFeeAndSubmit() throws {
        let listener = CovCUBUnbondConfirmListenerSpy()
        let state = unbondConfirmState(listener: listener)
        let strategy = makeUnbondConfirm(output: state)

        strategy.estimateFee(builderClosure: state.builderClosure, reuseIdentifier: "id")
        strategy.submit(builderClosure: state.builderClosure)

        XCTAssertEqual(listener.calls, ["error", "submit"])
        XCTAssertThrowsError(try listener.submissions.first?.get())
        XCTAssertTrue(kit.feeProxy.reuseIdentifiers.isEmpty)

        strategy.setup()
        XCTAssertEqual(kit.subscriptions.stashRequests.count, 1)
        XCTAssertTrue(kit.feeProxy.delegate === strategy)
        CovCUBOperations.wait { listener.calls.count >= 3 }
        XCTAssertEqual(listener.calls.last, "error")
    }

    func testUnbondConfirmStrategyForwardsSubscriptions() throws {
        let listener = CovCUBUnbondConfirmListenerSpy()
        let state = unbondConfirmState(listener: listener)
        let strategy = makeUnbondConfirm(output: state)
        let accountId = try self.accountId

        strategy.handleLedgerInfo(result: .success(try CovCUBFixture.ledger(active: 3)), accountId: accountId, chainId: "c")
        strategy.handlePayee(result: .success(.stash), accountId: accountId, chainId: "c")
        strategy.handleMinNominatorBond(result: .success(nil), chainId: "c")
        strategy.handleNomination(result: .success(nil), accountId: accountId, chainId: "c")
        strategy.handleAccountInfo(result: .success(CovCUBFixture.accountInfo(free: 2)), accountId: accountId, chainAsset: chainAsset)
        strategy.didReceiveFee(result: .success(CovCUBFixture.dispatchInfo(fee: 0.1)), for: "id")

        XCTAssertEqual(state.bonded, 3)
        XCTAssertEqual(state.payee, .stash)
        XCTAssertEqual(state.minNominatorBonded, 0)
        XCTAssertNil(state.nomination)
        XCTAssertEqual(state.balance, 2)
        XCTAssertEqual(state.fee, 0.1)
    }

    func testUnbondConfirmStrategyHandlesStashItemsAndResolvesController() throws {
        let listener = CovCUBUnbondConfirmListenerSpy()
        let state = unbondConfirmState(listener: listener)
        let strategy = makeUnbondConfirm(output: state)

        strategy.handleStashItem(result: .failure(CovCUBTestError.failed), for: "addr")
        XCTAssertEqual(listener.calls, Array(repeating: "error", count: 5))

        listener.reset()
        strategy.handleStashItem(result: .success(nil), for: "addr")
        XCTAssertNil(state.payee)
        XCTAssertEqual(listener.calls, ["asset", "refresh", "refresh", "confirmation", "refresh"])

        let stash = try controllerStash()
        strategy.handleStashItem(result: .success(stash), for: stash.stash)
        CovCUBOperations.wait { state.controller != nil }
        XCTAssertNotNil(state.controller)
        XCTAssertEqual(state.accountAddress, stash.controller)

        strategy.estimateFee(builderClosure: state.builderClosure, reuseIdentifier: "after-controller")
        XCTAssertEqual(kit.feeProxy.reuseIdentifiers, ["after-controller"])
    }

    // MARK: - Redeem (both modules)

    private func redeemPairs() -> [(CovCUBRedeemRelayStrategyDriving, CovCUBRedeemRelayDriving, CovCUBRedeemListenerSpy)] {
        let redeemListener = CovCUBRedeemListenerSpy()
        let redeemState = StakingRedeemRelaychainViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            dataValidatingFactory: validatingFactory,
            callFactory: kit.callFactory
        )
        redeemState.setStateListener(redeemListener)
        let redeem = StakingRedeemRelaychainStrategy(
            output: redeemState,
            accountInfoSubscriptionAdapter: kit.accountInfo,
            stakingLocalSubscriptionFactory: kit.subscriptions,
            chainAsset: chainAsset,
            wallet: wallet,
            extrinsicService: kit.extrinsicService,
            feeProxy: kit.feeProxy,
            slashesOperationFactory: kit.slashes,
            runtimeService: kit.runtime,
            engine: kit.engine,
            operationManager: kit.operations,
            keystore: kit.keystore,
            accountRepository: kit.walletRepository
        )

        let confirmListener = CovCUBRedeemListenerSpy()
        let confirmState = StakingRedeemConfirmationRelaychainViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            dataValidatingFactory: validatingFactory,
            callFactory: kit.callFactory
        )
        confirmState.setStateListener(confirmListener)
        let confirm = StakingRedeemConfirmationRelaychainStrategy(
            output: confirmState,
            accountInfoSubscriptionAdapter: kit.accountInfo,
            stakingLocalSubscriptionFactory: kit.subscriptions,
            chainAsset: chainAsset,
            wallet: wallet,
            extrinsicService: kit.extrinsicService,
            feeProxy: kit.feeProxy,
            slashesOperationFactory: kit.slashes,
            runtimeService: kit.runtime,
            engine: kit.engine,
            operationManager: kit.operations,
            keystore: kit.keystore,
            accountRepository: kit.walletRepository
        )
        return [(redeem, redeemState, redeemListener), (confirm, confirmState, confirmListener)]
    }

    func testRedeemStrategiesEstimateSubmitAndSetup() throws {
        let pairs = redeemPairs()
        for (strategy, state, listener) in pairs {
            strategy.estimateFee(builderClosure: nil, reuseIdentifier: "id")
            strategy.submit(builderClosure: nil)
            XCTAssertEqual(listener.calls, ["error", "submit"])

            state.didReceiveSlashingSpans(result: .success(nil))
            strategy.estimateFee(builderClosure: state.builderClosure, reuseIdentifier: state.reuseIdentifier)

            listener.reset()
            strategy.setup()
            CovCUBOperations.wait { listener.calls.contains("error") }
            XCTAssertEqual(listener.calls, ["error"])
        }
        XCTAssertEqual(kit.feeProxy.reuseIdentifiers, ["1", "1"])
        XCTAssertEqual(kit.subscriptions.stashRequests.count, 2)
    }

    func testRedeemStrategiesForwardSubscriptions() throws {
        let accountId = try self.accountId
        for (strategy, state, _) in redeemPairs() {
            strategy.handleLedgerInfo(
                result: .success(try CovCUBFixture.ledger(active: 1, unlocking: [(1, 1)])),
                accountId: accountId,
                chainId: "c"
            )
            strategy.handleActiveEra(result: .success(CovCUBFixture.activeEra(3)), chainId: "c")
            strategy.handleAccountInfo(result: .success(CovCUBFixture.accountInfo(free: 7)), accountId: accountId, chainAsset: chainAsset)
            strategy.didReceiveFee(result: .success(CovCUBFixture.dispatchInfo(fee: 0.2)), for: "id")

            XCTAssertNotNil(state.stakingLedger)
            XCTAssertEqual(state.activeEra, 3)
            XCTAssertEqual(state.balance, 7)
            XCTAssertEqual(state.fee, 0.2)
        }
    }

    func testRedeemStrategiesHandleStashItems() throws {
        kit.slashes.spans = try CovCUBFixture.slashingSpans(priorCount: 2)
        let stash = try controllerStash()
        for (strategy, state, listener) in redeemPairs() {
            strategy.handleStashItem(result: .failure(CovCUBTestError.failed), for: "addr")
            XCTAssertEqual(listener.calls, ["error", "error", "error"])

            listener.reset()
            strategy.handleStashItem(result: .success(nil), for: "addr")
            XCTAssertNil(state.stakingLedger)
            XCTAssertNil(state.balance)

            strategy.handleStashItem(result: .success(stash), for: stash.stash)
            XCTAssertEqual(state.address, stash.controller)
            CovCUBOperations.wait { state.controller != nil && state.numberOfSlashingSpans != nil }
            XCTAssertNotNil(state.controller)
            XCTAssertEqual(state.numberOfSlashingSpans, 3)
        }
        XCTAssertEqual(kit.accountInfo.resets, 4)
        XCTAssertEqual(kit.slashes.stashes, [stash.stash, stash.stash])
    }
}

final class CovCUBRebondStrategyTests: XCTestCase {
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

    private func controllerStash() throws -> StashItem {
        CovCUBFixture.stashItem(controller: try CovCUBFixture.address(for: chainAsset, wallet: wallet))
    }

    private var accountId: AccountId {
        get throws { try CovCUBFixture.account(for: chainAsset, wallet: wallet).accountId }
    }

    // MARK: - Rebond confirmation

    private func makeRebond(
        output: StakingRebondConfirmationRelaychainStrategyOutput
    ) -> StakingRebondConfirmationRelaychainStrategy {
        StakingRebondConfirmationRelaychainStrategy(
            stakingLocalSubscriptionFactory: kit.subscriptions,
            accountInfoSubscriptionAdapter: kit.accountInfo,
            chainAsset: chainAsset,
            wallet: wallet,
            extrinsicService: kit.extrinsicService,
            feeProxy: kit.feeProxy,
            runtimeService: kit.runtime,
            operationManager: kit.operations,
            keystore: kit.keystore,
            connection: kit.engine,
            accountRepository: kit.walletRepository,
            output: output,
            callFactory: kit.callFactory
        )
    }

    private func rebondState(_ listener: CovCUBRebondConfirmListenerSpy) -> StakingRebondConfirmationRelaychainViewModelState {
        let state = StakingRebondConfirmationRelaychainViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            logger: CovCUBLoggerSpy(),
            variant: .custom(amount: 1),
            dataValidatingFactory: validatingFactory,
            callFactory: kit.callFactory
        )
        state.setStateListener(listener)
        return state
    }

    func testRebondStrategySetupEstimateAndSubmitGuards() throws {
        let listener = CovCUBRebondConfirmListenerSpy()
        let state = rebondState(listener)
        let strategy = makeRebond(output: state)

        strategy.setup()
        XCTAssertEqual(kit.subscriptions.stashRequests.count, 1)
        XCTAssertTrue(kit.feeProxy.delegate === strategy)

        strategy.estimateFee(builderClosure: nil, reuseIdentifier: "x")
        strategy.estimateFee(builderClosure: state.builderClosure, reuseIdentifier: nil)
        strategy.estimateFee(builderClosure: state.builderClosure, reuseIdentifier: state.reuseIdentifier)
        XCTAssertEqual(kit.feeProxy.reuseIdentifiers, ["rebond"])

        strategy.submit(builderClosure: state.builderClosure)
        XCTAssertEqual(kit.extrinsicService.submissions, 0)
        XCTAssertTrue(listener.calls.isEmpty)
    }

    func testRebondStrategyForwardsSubscriptionsAndStashItems() throws {
        let listener = CovCUBRebondConfirmListenerSpy()
        let state = rebondState(listener)
        let strategy = makeRebond(output: state)
        let accountId = try self.accountId

        strategy.handleLedgerInfo(result: .success(try CovCUBFixture.ledger(active: 1, unlocking: [(2, 9)])), accountId: accountId, chainId: "c")
        strategy.handleActiveEra(result: .success(CovCUBFixture.activeEra(4)), chainId: "c")
        strategy.handleAccountInfo(result: .success(CovCUBFixture.accountInfo(free: 3)), accountId: accountId, chainAsset: chainAsset)
        strategy.didReceiveFee(result: .success(CovCUBFixture.dispatchInfo(fee: 0.1)), for: "id")
        XCTAssertEqual(state.unbonding, 2)
        XCTAssertEqual(state.balance, 3)
        XCTAssertEqual(state.fee, 0.1)

        strategy.handleStashItem(result: .failure(CovCUBTestError.failed), for: "addr")
        strategy.handleStashItem(result: .success(nil), for: "addr")
        XCTAssertNil(state.stakingLedger)
        XCTAssertNil(state.balance)

        let stash = try controllerStash()
        strategy.handleStashItem(result: .success(stash), for: stash.stash)
        XCTAssertEqual(state.selectableAccountAddress, stash.controller)
        CovCUBOperations.wait { state.controller != nil }
        XCTAssertEqual(state.controller, try CovCUBFixture.account(for: chainAsset, wallet: wallet))
        XCTAssertEqual(kit.accountInfo.subscribedAccounts, [accountId])
    }
}
