import XCTest
import BigInt
import SSFModels
import SoraFoundation
@testable import fearless

final class CovCUBUnbondSetupListenerSpy: StakingUnbondSetupModelStateListener {
    private(set) var calls: [String] = []

    func didReceiveError(error _: Error) { calls.append("error") }
    func provideInputViewModel() { calls.append("input") }
    func provideFeeViewModel() { calls.append("fee") }
    func provideAssetViewModel() { calls.append("asset") }
    func provideBondingDuration() { calls.append("duration") }
    func provideAccountViewModel() { calls.append("account") }
    func updateFeeIfNeeded() { calls.append("updateFee") }

    func reset() { calls.removeAll() }
}

final class CovCUBUnbondSetupStateTests: XCTestCase {
    private var chainAsset: ChainAsset!
    private var wallet: fearless.MetaAccountModel!
    private var callFactory: CovCUBCallFactoryStub!
    private var errors: CovCUBStakingErrorSpy!
    private var validatingFactory: StakingDataValidatingFactory!
    private var listener: CovCUBUnbondSetupListenerSpy!
    private let validationView = CovCUBValidationView()

    override func setUp() {
        super.setUp()
        chainAsset = CovCUBFixture.chainAsset()
        wallet = CovCUBFixture.wallet()
        callFactory = CovCUBCallFactoryStub()
        errors = CovCUBStakingErrorSpy()
        validatingFactory = StakingDataValidatingFactory(presentable: errors)
        listener = CovCUBUnbondSetupListenerSpy()
    }

    override func tearDown() {
        chainAsset = nil
        wallet = nil
        callFactory = nil
        errors = nil
        validatingFactory = nil
        listener = nil
        super.tearDown()
    }

    private func makeRelaychain() -> StakingUnbondSetupRelaychainViewModelState {
        let state = StakingUnbondSetupRelaychainViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            dataValidatingFactory: validatingFactory,
            callFactory: callFactory
        )
        state.setStateListener(listener)
        return state
    }

    private func makePool() -> StakingUnbondSetupPoolViewModelState {
        let state = StakingUnbondSetupPoolViewModelState(
            chainAsset: chainAsset,
            wallet: wallet,
            dataValidatingFactory: validatingFactory,
            callFactory: callFactory
        )
        state.setStateListener(listener)
        return state
    }

    // MARK: - Relaychain

    func testRelaychainInitialStateBuildsPlainUnbond() throws {
        let state = makeRelaychain()

        XCTAssertNil(state.confirmationFlow)
        XCTAssertNil(state.amount)
        XCTAssertNil(state.bonded)
        XCTAssertNil(state.fee)
        XCTAssertEqual(state.reuseIdentifier, "0unbond")
        XCTAssertEqual(try CovCUBBuilderSpy.callNames(of: state.builderClosure), ["unbond"])
    }

    func testRelaychainLedgerAndAmountUpdatesNotifyListener() throws {
        let state = makeRelaychain()

        state.selectAmountPercentage(0.5)
        XCTAssertNil(state.inputAmount)
        XCTAssertTrue(listener.calls.isEmpty)

        state.didReceiveStakingLedger(result: .success(try CovCUBFixture.ledger(active: 10)))
        XCTAssertEqual(state.bonded, 10)
        XCTAssertEqual(listener.calls, ["asset"])

        listener.reset()
        state.selectAmountPercentage(0.5)
        XCTAssertEqual(state.inputAmount, 5)
        XCTAssertEqual(listener.calls, ["input", "asset", "updateFee"])

        listener.reset()
        state.updateAmount(3)
        XCTAssertEqual(state.amount, 3)
        XCTAssertEqual(listener.calls, ["asset", "updateFee"])
        guard case let .relaychain(amount) = state.confirmationFlow else {
            return XCTFail("expected relaychain flow")
        }
        XCTAssertEqual(amount, 3)

        state.didReceiveStakingLedger(result: .success(nil))
        XCTAssertNil(state.bonded)

        listener.reset()
        state.didReceiveStakingLedger(result: .failure(CovCUBTestError.failed))
        XCTAssertEqual(listener.calls, ["error"])
    }

    func testRelaychainChillsAndResetsPayeeWhenUnbondingEverything() throws {
        let state = makeRelaychain()
        state.didReceiveStakingLedger(result: .success(try CovCUBFixture.ledger(active: 10)))
        state.didReceiveMinBonded(result: .success(CovCUBFixture.planks(5)))
        state.didReceiveNomination(result: .success(try CovCUBFixture.nomination()))
        state.didReceivePayee(result: .success(.staked))
        state.didReceiveExistentialDeposit(result: .success(CovCUBFixture.planks(1)))
        XCTAssertEqual(listener.calls, ["asset", "updateFee", "updateFee", "updateFee"])
        XCTAssertEqual(state.minNominatorBonded, 5)
        XCTAssertEqual(state.minimalBalance, 1)
        XCTAssertEqual(state.payee, .staked)
        XCTAssertNotNil(state.nomination)

        state.updateAmount(10)
        XCTAssertEqual(try CovCUBBuilderSpy.callNames(of: state.builderClosure), ["chill", "unbond", "set_payee"])
        XCTAssertEqual(state.reuseIdentifier, "\(CovCUBFixture.planks(10))chillunbondset_payee")

        state.updateAmount(7)
        XCTAssertEqual(try CovCUBBuilderSpy.callNames(of: state.builderClosure), ["chill", "unbond"])

        state.updateAmount(2)
        XCTAssertEqual(try CovCUBBuilderSpy.callNames(of: state.builderClosure), ["unbond"])
        XCTAssertEqual(state.reuseIdentifier, "\(CovCUBFixture.planks(2))unbond")

        state.didReceivePayee(result: .success(.stash))
        state.updateAmount(10)
        XCTAssertEqual(try CovCUBBuilderSpy.callNames(of: state.builderClosure), ["chill", "unbond"])
    }

    func testRelaychainMissingMinBondDefaultsToZero() throws {
        let state = makeRelaychain()

        state.didReceiveMinBonded(result: .success(nil))
        XCTAssertEqual(state.minNominatorBonded, 0)
        XCTAssertEqual(listener.calls, ["updateFee"])

        listener.reset()
        state.didReceiveMinBonded(result: .failure(CovCUBTestError.failed))
        state.didReceiveNomination(result: .failure(CovCUBTestError.failed))
        state.didReceivePayee(result: .failure(CovCUBTestError.failed))
        state.didReceiveExistentialDeposit(result: .failure(CovCUBTestError.failed))
        XCTAssertEqual(listener.calls, ["error", "error", "error", "error"])
    }

    func testRelaychainReceivesFeeBalanceAccountsAndDurations() throws {
        let state = makeRelaychain()
        let account = try CovCUBFixture.account(for: chainAsset, wallet: wallet)

        state.didReceiveFee(result: .success(CovCUBFixture.dispatchInfo(fee: 0.25)))
        XCTAssertEqual(state.fee, 0.25)
        state.didReceiveAccountInfo(result: .success(CovCUBFixture.accountInfo(free: 20, frozen: 5)))
        XCTAssertEqual(state.balance, 15)
        state.didReceiveAccountInfo(result: .success(nil))
        XCTAssertNil(state.balance)
        state.didReceiveController(result: .success(account))
        XCTAssertEqual(state.controller, account)
        state.didReceiveController(result: .success(nil))
        XCTAssertEqual(state.controller, account)
        state.didReceiveStashItem(result: .success(CovCUBFixture.stashItem(controller: "stash")))
        XCTAssertEqual(state.stashItem?.controller, "stash")
        state.didReceiveUnbondingTime(result: .success(3600))
        XCTAssertEqual(state.unbondingTime, 3600)
        state.didReceiveBondingDuration(result: .success(28))
        XCTAssertEqual(state.bondingDuration, 28)
        state.didReceiveNewExtrinsicService()
        XCTAssertEqual(listener.calls, ["fee", "duration", "duration", "updateFee"])

        listener.reset()
        state.didReceiveFee(result: .failure(CovCUBTestError.failed))
        state.didReceiveAccountInfo(result: .failure(CovCUBTestError.failed))
        state.didReceiveController(result: .failure(CovCUBTestError.failed))
        state.didReceiveStashItem(result: .failure(CovCUBTestError.failed))
        state.didReceiveUnbondingTime(result: .failure(CovCUBTestError.failed))
        state.didReceiveBondingDuration(result: .failure(CovCUBTestError.failed))
        XCTAssertEqual(listener.calls, Array(repeating: "error", count: 6))
    }

    func testRelaychainValidatorsFailWithoutDataAndPresentErrors() throws {
        validatingFactory.view = validationView
        let state = makeRelaychain()

        let results = CovCUBFixture.validationResults(state.validators(using: CovCUBFixture.english))

        XCTAssertEqual(results, [.error, .error, .error, .error, .warning])
        XCTAssertEqual(errors.presented, ["unbondingTooHigh", "feeNotReceived", "feeTooHigh", "missingController", "stashKilled"])
        XCTAssertEqual(listener.calls, ["updateFee"])
    }

    func testRelaychainValidatorsPassWithCompleteData() throws {
        let state = makeRelaychain()
        state.didReceiveStakingLedger(result: .success(try CovCUBFixture.ledger(active: 10)))
        state.didReceiveFee(result: .success(CovCUBFixture.dispatchInfo(fee: 0.1)))
        state.didReceiveAccountInfo(result: .success(CovCUBFixture.accountInfo(free: 5)))
        state.didReceiveController(result: .success(try CovCUBFixture.account(for: chainAsset, wallet: wallet)))
        state.didReceiveExistentialDeposit(result: .success(CovCUBFixture.planks(1)))
        state.updateAmount(2)

        let results = CovCUBFixture.validationResults(state.validators(using: CovCUBFixture.english))

        XCTAssertEqual(results.count, 5)
        XCTAssertTrue(results.allSatisfy { $0 == nil })
        XCTAssertTrue(errors.presented.isEmpty)
    }

    // MARK: - Pool

}

extension CovCUBUnbondSetupStateTests {
    func testPoolBuilderAndIdentifiersUsePoolUnbond() throws {
        let state = makePool()

        XCTAssertEqual(try CovCUBBuilderSpy.callNames(of: state.builderClosure), ["pool_unbond"])
        XCTAssertEqual(state.reuseIdentifier, "pool_unbond-\(CovCUBFixture.planks(StakingConstants.maxAmount))")
        XCTAssertEqual(state.accountAddress, try CovCUBFixture.address(for: chainAsset, wallet: wallet))
        XCTAssertNil(state.confirmationFlow)

        state.updateAmount(4)
        XCTAssertEqual(state.amount, 4)
        guard case let .pool(amount) = state.confirmationFlow else {
            return XCTFail("expected pool flow")
        }
        XCTAssertEqual(amount, 4)
        XCTAssertEqual(listener.calls, ["asset", "updateFee"])
    }

    func testPoolStakeInfoAndPercentageSelection() throws {
        let state = makePool()

        state.selectAmountPercentage(0.5)
        state.didReceive(stakeInfo: nil)
        XCTAssertTrue(listener.calls.isEmpty)

        state.didReceive(stakeInfo: try CovCUBFixture.poolMember(points: 8))
        XCTAssertEqual(state.bonded, 8)
        state.selectAmountPercentage(0.25)
        XCTAssertEqual(state.inputAmount, 2)
        XCTAssertEqual(listener.calls, ["asset", "input", "asset"])
    }

    func testPoolStrategyOutputsUpdateState() throws {
        let state = makePool()

        state.didSetup()
        state.didReceive(error: CovCUBTestError.failed)
        state.didReceiveAccountInfo(result: .success(CovCUBFixture.accountInfo(free: 3)))
        XCTAssertEqual(state.balance, 3)
        state.didReceiveAccountInfo(result: .success(nil))
        XCTAssertNil(state.balance)
        state.didReceiveFee(result: .success(CovCUBFixture.dispatchInfo(fee: 0.5)))
        XCTAssertEqual(state.fee, 0.5)
        state.didReceiveExistentialDeposit(result: .success(CovCUBFixture.planks(2)))
        XCTAssertEqual(state.minimalBalance, 2)
        state.didReceive(stakingDuration: StakingDuration(session: 1, era: 2, unlocking: 3))
        XCTAssertEqual(state.stakingDuration?.unlocking, 3)
        XCTAssertEqual(listener.calls, ["updateFee", "error", "fee", "duration"])

        listener.reset()
        state.didReceiveAccountInfo(result: .failure(CovCUBTestError.failed))
        state.didReceiveFee(result: .failure(CovCUBTestError.failed))
        state.didReceiveExistentialDeposit(result: .failure(CovCUBTestError.failed))
        XCTAssertEqual(listener.calls, ["error", "error", "error"])
    }

    func testPoolValidatorsForMemberEndWithSucceedingCheck() throws {
        validatingFactory.view = validationView
        let state = makePool()

        let results = CovCUBFixture.validationResults(state.validators(using: CovCUBFixture.english))

        XCTAssertEqual(results.count, 4)
        XCTAssertEqual(results[0], .error)
        XCTAssertEqual(results[1], .error)
        XCTAssertEqual(results[2], .error)
        XCTAssertNil(results[3])
        XCTAssertEqual(errors.presented, ["unbondingTooHigh", "feeNotReceived", "feeTooHigh"])
        XCTAssertEqual(listener.calls, ["updateFee"])
    }

    func testPoolValidatorsForRootCheckMinimalRootBond() throws {
        validatingFactory.view = validationView
        let state = makePool()
        let accountId = try CovCUBFixture.account(for: chainAsset, wallet: wallet).accountId
        state.didReceive(stakingPool: try CovCUBFixture.stakingPool(depositor: accountId))
        state.didReceive(networkInfo: StakingPoolNetworkInfo(
            minJoinBond: CovCUBFixture.planks(1),
            minCreateBond: CovCUBFixture.planks(5),
            existingPoolsCount: 1,
            possiblePoolsCount: 10,
            maxMembersInPool: 100,
            maxPoolsMembers: 1000
        ))
        state.didReceive(stakeInfo: try CovCUBFixture.poolMember(points: 10))
        state.didReceiveFee(result: .success(CovCUBFixture.dispatchInfo(fee: 0.1)))
        state.didReceiveAccountInfo(result: .success(CovCUBFixture.accountInfo(free: 4)))
        state.updateAmount(8)

        let results = CovCUBFixture.validationResults(state.validators(using: CovCUBFixture.english))

        XCTAssertEqual(results.count, 4)
        XCTAssertNil(results[0])
        XCTAssertNil(results[1])
        XCTAssertNil(results[2])
        XCTAssertEqual(results[3], .error)
        XCTAssertEqual(errors.presented, ["poolRootUnbondingTooHigh"])
    }

    // MARK: - View model factories

    func testRelaychainFactoryBuildsDurationInHoursDaysAndEras() throws {
        let factory = StakingUnbondSetupRelaychainViewModelFactory()
        let en = ["en"]

        let empty = makeRelaychain()
        let emptyModel = try XCTUnwrap(factory.buildBondingDurationViewModel(viewModelState: empty)).value(for: CovCUBFixture.english)
        XCTAssertEqual(emptyModel, TitleWithSubtitleViewModel(title: ""))

        let hours = makeRelaychain()
        hours.didReceiveUnbondingTime(result: .success(2 * TimeInterval.secondsInHour))
        let hoursModel = try XCTUnwrap(factory.buildBondingDurationViewModel(viewModelState: hours)).value(for: CovCUBFixture.english)
        XCTAssertEqual(hoursModel.title, R.string.localizable.stakingUnstakingPeriod(preferredLanguages: en))
        XCTAssertEqual(hoursModel.subtitle, R.string.localizable.commonHoursFormat(format: 2, preferredLanguages: en))

        let days = makeRelaychain()
        days.didReceiveUnbondingTime(result: .success(2.5 * TimeInterval.secondsInDay))
        let daysModel = try XCTUnwrap(factory.buildBondingDurationViewModel(viewModelState: days)).value(for: CovCUBFixture.english)
        XCTAssertEqual(daysModel.subtitle, R.string.localizable.commonDaysFormat(format: 3, preferredLanguages: en))

        let zero = makeRelaychain()
        zero.didReceiveUnbondingTime(result: .success(0))
        let zeroModel = try XCTUnwrap(factory.buildBondingDurationViewModel(viewModelState: zero)).value(for: CovCUBFixture.english)
        XCTAssertEqual(zeroModel.title, "")

        let eras = makeRelaychain()
        eras.didReceiveBondingDuration(result: .success(28))
        let erasModel = try XCTUnwrap(factory.buildBondingDurationViewModel(viewModelState: eras)).value(for: CovCUBFixture.english)
        XCTAssertEqual(erasModel.subtitle, R.string.localizable.commonDaysFormat(format: 28, preferredLanguages: en))

        XCTAssertNil(factory.buildBondingDurationViewModel(viewModelState: makePool()))
        XCTAssertNil(factory.buildAccountViewModel(viewModelState: empty, locale: CovCUBFixture.english))
    }

    func testRelaychainFactoryTitleFeeAndHints() {
        let factory = StakingUnbondSetupRelaychainViewModelFactory()
        let en = ["en"]

        XCTAssertEqual(
            factory.buildTitleViewModel().value(for: CovCUBFixture.english),
            R.string.localizable.stakingUnbond_v190(preferredLanguages: en)
        )
        XCTAssertTrue(factory.buildHints().value(for: CovCUBFixture.english).isEmpty)

        let balance: LocalizableResource<BalanceViewModelProtocol> = LocalizableResource { _ in
            BalanceViewModel(amount: "1 DOT", price: "$2")
        }
        let fee = factory.buildNetworkFeeViewModel(from: balance).value(for: CovCUBFixture.english)
        XCTAssertEqual(fee.actionTitle.value(for: CovCUBFixture.english), R.string.localizable.commonContinue(preferredLanguages: en))
        XCTAssertEqual(fee.feeTitle.value(for: CovCUBFixture.english), R.string.localizable.commonNetworkFee(preferredLanguages: en))
        XCTAssertEqual(fee.balanceViewModel.value(for: CovCUBFixture.english).amount, "1 DOT")
    }

    func testPoolFactoryBuildsAccountTitleFeeAndHints() throws {
        let factory = StakingUnbondSetupPoolViewModelFactory(
            accountViewModelFactory: AccountViewModelFactory(iconGenerator: CovCUBIconGenerator())
        )
        let en = ["en"]
        let state = makePool()

        let account = try XCTUnwrap(factory.buildAccountViewModel(viewModelState: state, locale: CovCUBFixture.english))
        XCTAssertEqual(account.title, R.string.localizable.commonAccount(preferredLanguages: en))
        XCTAssertEqual(account.name, wallet.name)
        XCTAssertNil(factory.buildAccountViewModel(viewModelState: makeRelaychain(), locale: CovCUBFixture.english))
        XCTAssertNil(factory.buildBondingDurationViewModel(viewModelState: state))

        XCTAssertEqual(
            factory.buildTitleViewModel().value(for: CovCUBFixture.english),
            R.string.localizable.poolStakingUnstakeAmountTitle("", preferredLanguages: en)
        )
        XCTAssertTrue(factory.buildHints().value(for: CovCUBFixture.english).isEmpty)

        let balance: LocalizableResource<BalanceViewModelProtocol> = LocalizableResource { _ in
            BalanceViewModel(amount: "2 DOT", price: nil)
        }
        let fee = factory.buildNetworkFeeViewModel(from: balance).value(for: CovCUBFixture.english)
        XCTAssertEqual(fee.actionTitle.value(for: CovCUBFixture.english), R.string.localizable.commonContinue(preferredLanguages: en))
        XCTAssertEqual(fee.feeTitle.value(for: CovCUBFixture.english), R.string.localizable.commonNetworkFee(preferredLanguages: en))
        XCTAssertNil(fee.balanceViewModel.value(for: CovCUBFixture.english).price)
    }
}
