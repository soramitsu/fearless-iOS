import XCTest
import BigInt
import SSFModels
import SoraFoundation
@testable import fearless

final class CovCUBUnbondConfirmListenerSpy: StakingUnbondConfirmModelStateListener {
    private(set) var calls: [String] = []
    private(set) var submissions: [Result<String, Error>] = []

    func didReceiveError(error _: Error) { calls.append("error") }
    func didSubmitUnbonding(result: Result<String, Error>) {
        calls.append("submit")
        submissions.append(result)
    }

    func provideFeeViewModel() { calls.append("fee") }
    func provideAssetViewModel() { calls.append("asset") }
    func provideConfirmationViewModel() { calls.append("confirmation") }
    func refreshFeeIfNeeded() { calls.append("refresh") }
    func didReceiveFeeError() { calls.append("feeError") }

    func reset() { calls.removeAll() }
}

final class CovCUBUnbondConfirmStateTests: XCTestCase {
    private var chainAsset: ChainAsset!
    private var wallet: fearless.MetaAccountModel!
    private var errors: CovCUBStakingErrorSpy!
    private var validatingFactory: StakingDataValidatingFactory!
    private var listener: CovCUBUnbondConfirmListenerSpy!
    private let validationView = CovCUBValidationView()
    private let en = ["en"]

    override func setUp() {
        super.setUp()
        chainAsset = CovCUBFixture.chainAsset(color: "#E6007A")
        wallet = CovCUBFixture.wallet()
        errors = CovCUBStakingErrorSpy()
        validatingFactory = StakingDataValidatingFactory(presentable: errors)
        listener = CovCUBUnbondConfirmListenerSpy()
    }

    override func tearDown() {
        chainAsset = nil
        wallet = nil
        errors = nil
        validatingFactory = nil
        listener = nil
        super.tearDown()
    }

    private func makeRelaychain(amount: Decimal) -> StakingUnbondConfirmRelaychainViewModelState {
        let state = StakingUnbondConfirmRelaychainViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            dataValidatingFactory: validatingFactory,
            inputAmount: amount,
            callFactory: CovCUBCallFactoryStub()
        )
        state.setStateListener(listener)
        return state
    }

    private func makePool(amount: Decimal) -> StakingUnbondConfirmPoolViewModelState {
        let state = StakingUnbondConfirmPoolViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            dataValidatingFactory: validatingFactory,
            inputAmount: amount,
            callFactory: CovCUBCallFactoryStub()
        )
        state.setStateListener(listener)
        return state
    }

    private func tokenString(_ value: Decimal) -> String {
        AssetBalanceFormatterFactory()
            .createTokenFormatter(for: chainAsset.asset.displayInfo, usageCase: .detailsCrypto)
            .value(for: CovCUBFixture.english)
            .stringFromDecimal(value) ?? ""
    }

    // MARK: - Relaychain state

    func testRelaychainDefaultsBuildUnbondOnly() throws {
        let state = makeRelaychain(amount: 4)

        XCTAssertNil(state.builderClosureOld)
        XCTAssertNil(state.accountAddress)
        XCTAssertFalse(state.shouldResetRewardDestination)
        XCTAssertEqual(state.reuseIdentifier, "4false")
        XCTAssertEqual(try CovCUBBuilderSpy.callNames(of: state.builderClosure), ["unbond"])

        state.didReceiveStashItem(result: .success(CovCUBFixture.stashItem(controller: "ctrl")))
        XCTAssertEqual(state.accountAddress, "ctrl")
        XCTAssertTrue(listener.calls.isEmpty)
    }

    func testRelaychainFullUnbondChillsAndResetsPayee() throws {
        let state = makeRelaychain(amount: 10)

        state.didReceiveStakingLedger(result: .success(try CovCUBFixture.ledger(active: 10)))
        state.didReceiveExistentialDeposit(result: .success(CovCUBFixture.planks(1)))
        state.didReceiveMinBonded(result: .success(CovCUBFixture.planks(3)))
        state.didReceiveNomination(result: .success(try CovCUBFixture.nomination()))
        state.didReceivePayee(result: .success(.staked))
        XCTAssertEqual(
            listener.calls,
            ["asset", "refresh", "asset", "refresh", "refresh", "refresh", "refresh", "confirmation"]
        )

        XCTAssertEqual(state.bonded, 10)
        XCTAssertEqual(state.minimalBalance, 1)
        XCTAssertEqual(state.minNominatorBonded, 3)
        XCTAssertTrue(state.shouldResetRewardDestination)
        XCTAssertEqual(state.reuseIdentifier, "10true")
        XCTAssertEqual(try CovCUBBuilderSpy.callNames(of: state.builderClosure), ["chill", "unbond", "set_payee"])

        state.didReceivePayee(result: .success(.stash))
        XCTAssertFalse(state.shouldResetRewardDestination)
        XCTAssertEqual(try CovCUBBuilderSpy.callNames(of: state.builderClosure), ["chill", "unbond"])
    }

    func testRelaychainPartialUnbondKeepsNominationAndPayee() throws {
        let state = makeRelaychain(amount: 2)
        state.didReceiveStakingLedger(result: .success(try CovCUBFixture.ledger(active: 10)))
        state.didReceiveExistentialDeposit(result: .success(CovCUBFixture.planks(1)))
        state.didReceiveMinBonded(result: .success(nil))
        state.didReceiveNomination(result: .success(try CovCUBFixture.nomination()))
        state.didReceivePayee(result: .success(.staked))

        XCTAssertEqual(state.minNominatorBonded, 0)
        XCTAssertFalse(state.shouldResetRewardDestination)
        XCTAssertEqual(try CovCUBBuilderSpy.callNames(of: state.builderClosure), ["unbond"])

        state.didReceiveStakingLedger(result: .success(nil))
        XCTAssertNil(state.bonded)
        XCTAssertFalse(state.shouldResetRewardDestination)
    }

    func testRelaychainOutputsStoreValuesAndForwardSubmission() throws {
        let state = makeRelaychain(amount: 1)
        let account = try CovCUBFixture.account(for: chainAsset, wallet: wallet)

        state.didReceiveAccountInfo(result: .success(CovCUBFixture.accountInfo(free: 9)))
        XCTAssertEqual(state.balance, 9)
        state.didReceiveAccountInfo(result: .success(nil))
        XCTAssertNil(state.balance)
        state.didReceiveFee(result: .success(CovCUBFixture.dispatchInfo(fee: 0.2)))
        XCTAssertEqual(state.fee, 0.2)
        state.didReceiveController(result: .success(account))
        state.didReceiveController(result: .success(nil))
        XCTAssertEqual(state.controller, account)
        state.didSubmitUnbonding(result: .success("0xhash"))
        XCTAssertEqual(listener.calls, ["fee", "confirmation", "refresh", "confirmation", "refresh", "submit"])
        XCTAssertEqual(try listener.submissions.first?.get(), "0xhash")

        listener.reset()
        state.didReceiveAccountInfo(result: .failure(CovCUBTestError.failed))
        state.didReceiveStakingLedger(result: .failure(CovCUBTestError.failed))
        state.didReceiveFee(result: .failure(CovCUBTestError.failed))
        state.didReceiveExistentialDeposit(result: .failure(CovCUBTestError.failed))
        state.didReceiveController(result: .failure(CovCUBTestError.failed))
        state.didReceiveStashItem(result: .failure(CovCUBTestError.failed))
        state.didReceivePayee(result: .failure(CovCUBTestError.failed))
        state.didReceiveMinBonded(result: .failure(CovCUBTestError.failed))
        state.didReceiveNomination(result: .failure(CovCUBTestError.failed))
        XCTAssertEqual(listener.calls, Array(repeating: "error", count: 9))
    }

    func testRelaychainValidators() throws {
        validatingFactory.view = validationView
        let state = makeRelaychain(amount: 2)

        XCTAssertEqual(
            CovCUBFixture.validationResults(state.validators(using: CovCUBFixture.english)),
            [.error, .error, .error, .error]
        )
        XCTAssertEqual(errors.presented, ["unbondingTooHigh", "feeNotReceived", "feeTooHigh", "missingController"])
        XCTAssertEqual(listener.calls, ["refresh"])

        state.didReceiveStakingLedger(result: .success(try CovCUBFixture.ledger(active: 5)))
        state.didReceiveFee(result: .success(CovCUBFixture.dispatchInfo(fee: 0.1)))
        state.didReceiveAccountInfo(result: .success(CovCUBFixture.accountInfo(free: 1)))
        state.didReceiveController(result: .success(try CovCUBFixture.account(for: chainAsset, wallet: wallet)))
        XCTAssertEqual(
            CovCUBFixture.validationResults(state.validators(using: CovCUBFixture.english)),
            [nil, nil, nil, nil]
        )
    }

    // MARK: - Pool state

    func testPoolClosuresAndIdentifiers() throws {
        let state = makePool(amount: 3)

        XCTAssertEqual(try CovCUBBuilderSpy.callNames(of: state.builderClosure), ["pool_unbond"])
        XCTAssertEqual(try CovCUBBuilderSpy.callNames(of: state.builderClosureOld), ["pool_unbond_old"])
        XCTAssertEqual(state.reuseIdentifier, "pool_unbond")
        XCTAssertEqual(state.accountAddress, try CovCUBFixture.address(for: chainAsset, wallet: wallet))
    }

    func testPoolOutputsUpdateStateAndListener() throws {
        let state = makePool(amount: 3)

        state.didReceive(stakeInfo: nil)
        state.didReceive(stakeInfo: try CovCUBFixture.poolMember(points: 6))
        XCTAssertEqual(state.bonded, 6)
        state.didReceive(error: CovCUBTestError.failed)
        state.didReceiveAccountInfo(result: .success(CovCUBFixture.accountInfo(free: 2)))
        XCTAssertEqual(state.balance, 2)
        state.didReceiveAccountInfo(result: .success(nil))
        XCTAssertNil(state.balance)
        state.didReceiveFee(result: .success(CovCUBFixture.dispatchInfo(fee: 0.3)))
        XCTAssertEqual(state.fee, 0.3)
        state.didReceiveExistentialDeposit(result: .success(CovCUBFixture.planks(1)))
        XCTAssertEqual(state.minimalBalance, 1)
        state.didReceiveMinBonded(result: .success(CovCUBFixture.planks(4)))
        XCTAssertEqual(state.minNominatorBonded, 4)
        state.didReceiveMinBonded(result: .success(nil))
        XCTAssertNil(state.minNominatorBonded)
        state.didSubmitUnbonding(result: .failure(CovCUBTestError.failed))

        XCTAssertEqual(listener.calls, ["asset", "error", "fee", "asset", "refresh", "refresh", "refresh", "submit"])
        XCTAssertThrowsError(try listener.submissions.first?.get())

        listener.reset()
        state.didReceiveFee(result: .failure(CovCUBTestError.failed))
        state.didReceiveAccountInfo(result: .failure(CovCUBTestError.failed))
        state.didReceiveExistentialDeposit(result: .failure(CovCUBTestError.failed))
        state.didReceiveMinBonded(result: .failure(CovCUBTestError.failed))
        XCTAssertEqual(listener.calls, ["error", "feeError", "error", "error", "error"])
    }

    func testPoolValidators() throws {
        validatingFactory.view = validationView
        let state = makePool(amount: 3)

        XCTAssertEqual(
            CovCUBFixture.validationResults(state.validators(using: CovCUBFixture.english)),
            [.error, .error, .error]
        )
        XCTAssertEqual(errors.presented, ["unbondingTooHigh", "feeNotReceived", "feeTooHigh"])

        state.didReceive(stakeInfo: try CovCUBFixture.poolMember(points: 3))
        state.didReceiveFee(result: .success(CovCUBFixture.dispatchInfo(fee: 0.1)))
        state.didReceiveAccountInfo(result: .success(CovCUBFixture.accountInfo(free: 1)))
        XCTAssertEqual(
            CovCUBFixture.validationResults(state.validators(using: CovCUBFixture.english)),
            [nil, nil, nil]
        )
    }

    // MARK: - View model factories

    func testRelaychainFactoryNeedsController() throws {
        let icons = CovCUBIconGenerator()
        let factory = StakingUnbondConfirmRelaychainViewModelFactory(asset: chainAsset.asset, iconGenerator: icons)

        XCTAssertNil(factory.buildViewModel(viewModelState: makeRelaychain(amount: 1)))
        XCTAssertNil(factory.buildViewModel(viewModelState: makePool(amount: 1)))
        XCTAssertNil(factory.buildBondingDurationViewModel(viewModelState: makeRelaychain(amount: 1)))
        XCTAssertTrue(icons.addresses.isEmpty)
    }

    func testRelaychainFactoryBuildsConfirmationWithHints() throws {
        let icons = CovCUBIconGenerator()
        let factory = StakingUnbondConfirmRelaychainViewModelFactory(asset: chainAsset.asset, iconGenerator: icons)
        let state = makeRelaychain(amount: 4)
        let account = try CovCUBFixture.account(for: chainAsset, wallet: wallet)
        let address = try CovCUBFixture.address(for: chainAsset, wallet: wallet)
        state.didReceiveController(result: .success(account))

        let viewModel = try XCTUnwrap(factory.buildViewModel(viewModelState: state))
        XCTAssertEqual(viewModel.senderAddress, address)
        XCTAssertEqual(viewModel.senderName, wallet.name)
        XCTAssertNotNil(viewModel.senderIcon)
        XCTAssertEqual(icons.addresses, [address])
        XCTAssertEqual(viewModel.amountString.value(for: CovCUBFixture.english), tokenString(4))

        let hints = viewModel.hints.value(for: CovCUBFixture.english).map(\.title)
        XCTAssertEqual(hints, [
            R.string.localizable.stakingHintNoRewards(preferredLanguages: en),
            R.string.localizable.stakingHintRedeem(preferredLanguages: en)
        ])

        let staked = try XCTUnwrap(viewModel.stakeAmountViewModel?.value(for: CovCUBFixture.english))
        XCTAssertEqual(
            staked.amountTitle.string,
            R.string.localizable.poolStakingUnstakeAmountTitle(tokenString(4), preferredLanguages: en)
        )
        XCTAssertEqual(staked.color, "#E6007A")
        XCTAssertNil(staked.iconViewModel)

        state.didReceiveStakingLedger(result: .success(try CovCUBFixture.ledger(active: 4)))
        state.didReceiveExistentialDeposit(result: .success(CovCUBFixture.planks(1)))
        state.didReceivePayee(result: .success(.staked))
        let resetting = try XCTUnwrap(factory.buildViewModel(viewModelState: state))
        let resetHints = resetting.hints.value(for: CovCUBFixture.english).map(\.title)
        XCTAssertEqual(resetHints.count, 3)
        XCTAssertEqual(resetHints[1], R.string.localizable.stakingHintUnbondKillsStash(preferredLanguages: en))
    }

    func testPoolFactoryBuildsConfirmationFromWallet() throws {
        let icons = CovCUBIconGenerator()
        let factory = StakingUnbondConfirmPoolViewModelFactory(asset: chainAsset.asset, iconGenerator: icons)
        let address = try CovCUBFixture.address(for: chainAsset, wallet: wallet)

        XCTAssertNil(factory.buildViewModel(viewModelState: makeRelaychain(amount: 1)))
        XCTAssertNil(factory.buildBondingDurationViewModel(viewModelState: makePool(amount: 1)))

        let viewModel = try XCTUnwrap(factory.buildViewModel(viewModelState: makePool(amount: 5)))
        XCTAssertEqual(viewModel.senderAddress, address)
        XCTAssertEqual(viewModel.senderName, wallet.name)
        XCTAssertNotNil(viewModel.senderIcon)
        XCTAssertEqual(viewModel.amountString.value(for: CovCUBFixture.english), tokenString(5))
        XCTAssertEqual(viewModel.hints.value(for: CovCUBFixture.english).map(\.title), [
            R.string.localizable.stakingHintNoRewards(preferredLanguages: en),
            R.string.localizable.stakingHintRedeem(preferredLanguages: en)
        ])

        let staked = try XCTUnwrap(factory.createStakedAmountViewModel(5)?.value(for: CovCUBFixture.english))
        XCTAssertEqual(
            staked.amountTitle.string,
            R.string.localizable.poolStakingUnstakeAmountTitle(tokenString(5), preferredLanguages: en)
        )
        XCTAssertEqual(staked.color, "#E6007A")
    }
}
