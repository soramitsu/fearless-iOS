import XCTest
import BigInt
import SoraFoundation
import SSFModels
@testable import fearless

final class CovBVmValidatorView: UIViewController, ControllerBackedProtocol, Localizable {
    func applyLocalization() {}
}

final class CovBVmWarningDelegate: DataValidatingDelegate {
    private(set) var completions = 0

    func didCompleteWarningHandling() {
        completions += 1
    }
}

final class CovBVmStakingPresentable: StakingErrorPresentable {
    private(set) var calls: [String] = []
    private(set) var values: [String] = []
    var runsActions = true

    private func record(_ name: String, _ action: (() -> Void)? = nil) {
        calls.append(name)
        if runsActions { action?() }
    }

    func presentAmountTooHigh(from _: ControllerBackedProtocol, locale _: Locale?) { record("amountTooHigh") }
    func presentFeeNotReceived(from _: ControllerBackedProtocol, locale _: Locale?) { record("feeNotReceived") }
    func presentExsitentialDepositNotReceived(from _: ControllerBackedProtocol, locale _: Locale?) { record("edNotReceived") }
    func presentFeeTooHigh(from _: ControllerBackedProtocol, locale _: Locale?) { record("feeTooHigh") }
    func presentExtrinsicFailed(from _: ControllerBackedProtocol, locale _: Locale?) { record("extrinsicFailed") }

    func presentExistentialDepositWarning(
        existentianDepositValue _: String,
        from _: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale _: Locale?
    ) {
        record("edWarning", action)
    }

    func presentExistentialDepositWarning(
        existentianDepositValue _: String,
        from _: ControllerBackedProtocol,
        proceedHandler: @escaping () -> Void,
        setMaxHandler _: @escaping () -> Void,
        cancelHandler _: @escaping () -> Void,
        locale _: Locale?
    ) {
        record("edWarningHandlers", proceedHandler)
    }

    func presentExistentialDepositError(existentianDepositValue _: String, from _: ControllerBackedProtocol, locale _: Locale?) {
        record("edError")
    }

    func presentSoraBridgeLowAmountError(from _: ControllerBackedProtocol, locale _: Locale, assetAmount _: String) {
        record("soraBridgeLow")
    }

    func presentWarning(for _: String, message _: String, action: @escaping () -> Void, view _: ControllerBackedProtocol, locale _: Locale?) {
        record("warning", action)
    }

    func presentDestinationExistentialDepositError(from _: ControllerBackedProtocol, locale _: Locale?) {
        record("destinationEd")
    }

    func presentAmountTooLow(value: String, from _: ControllerBackedProtocol, locale _: Locale?) {
        values.append(value)
        record("amountTooLow")
    }

    func presentMissingController(from _: ControllerBackedProtocol, address: AccountAddress, locale _: Locale?) {
        values.append(address)
        record("missingController")
    }

    func presentMissingStash(from _: ControllerBackedProtocol, address: AccountAddress, locale _: Locale?) {
        values.append(address)
        record("missingStash")
    }

    func presentUnbondingTooHigh(from _: ControllerBackedProtocol, locale _: Locale?) { record("unbondingTooHigh") }
    func presentRebondingTooHigh(from _: ControllerBackedProtocol, locale _: Locale?) { record("rebondingTooHigh") }

    func presentRewardIsLessThanFee(from _: ControllerBackedProtocol, action: @escaping () -> Void, locale _: Locale?) {
        record("rewardLessThanFee", action)
    }

    func presentControllerBalanceIsZero(from _: ControllerBackedProtocol, action: @escaping () -> Void, locale _: Locale?) {
        record("controllerBalanceZero", action)
    }

    func presentStashKilledAfterUnbond(from _: ControllerBackedProtocol, action: @escaping () -> Void, locale _: Locale?) {
        record("stashKilled", action)
    }

    func presentUnbondingLimitReached(from _: ControllerBackedProtocol?, locale _: Locale?) { record("unbondingLimit") }
    func presentNoRedeemables(from _: ControllerBackedProtocol?, locale _: Locale?) { record("noRedeemables") }
    func presentControllerIsAlreadyUsed(from _: ControllerBackedProtocol?, locale _: Locale?) { record("controllerUsed") }

    func presentDeselectValidatorsWarning(from _: ControllerBackedProtocol, action: @escaping () -> Void, locale _: Locale?) {
        record("deselect", action)
    }

    func presentMaxNumberOfNominatorsReached(from _: ControllerBackedProtocol?, locale _: Locale?) { record("maxNominators") }
    func presentMissingPoolName(from _: ControllerBackedProtocol?, locale _: Locale?) { record("missingPoolName") }

    func presentPoolRootUnbondingTooHigh(minimalBond: String, from _: ControllerBackedProtocol, locale _: Locale?) {
        values.append(minimalBond)
        record("poolRootUnbonding")
    }

    func presentMaximumPoolsCountReached(from _: ControllerBackedProtocol?, locale _: Locale?) { record("maxPools") }

    func dismiss(view _: ControllerBackedProtocol?) { record("dismiss") }
}

final class CovBVmStakingDataValidatorFactoryTests: XCTestCase {
    private let locale = Locale(identifier: "en")
    private var presentable: CovBVmStakingPresentable!
    private var view: CovBVmValidatorView!
    private var factory: StakingDataValidatingFactory!
    private var delegate: CovBVmWarningDelegate!

    override func setUp() {
        super.setUp()
        presentable = CovBVmStakingPresentable()
        view = CovBVmValidatorView()
        factory = StakingDataValidatingFactory(presentable: presentable, balanceFactory: StubBalanceViewModelFactory())
        factory.view = view
        delegate = CovBVmWarningDelegate()
    }

    override func tearDown() {
        factory = nil
        view = nil
        presentable = nil
        delegate = nil
        super.tearDown()
    }

    private func run(_ validator: DataValidating) -> DataValidationProblem? {
        validator.validate(notifying: delegate)
    }

    private func account(_ byte: UInt8) -> ChainAccountResponse {
        ChainAccountResponse(
            chainId: "covb",
            accountId: Data(repeating: byte, count: 32),
            publicKey: Data(repeating: byte, count: 32),
            name: "covb",
            cryptoType: .sr25519,
            addressPrefix: 42,
            isEthereumBased: false,
            isChainAccount: false,
            walletId: "covb-wallet"
        )
    }

    private func ledger(unlocking: [(value: String, era: String)]) throws -> StakingLedger {
        let chunks = unlocking.map { ["value": $0.value, "era": $0.era] }
        let json: [String: Any] = [
            "stash": Data(repeating: 7, count: 32).base64EncodedString(),
            "total": "100",
            "active": "50",
            "unlocking": chunks,
            "claimedRewards": []
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(StakingLedger.self, from: data)
    }

    func testBasePresentableIsTheStakingPresentable() {
        XCTAssertTrue(factory.basePresentable as? CovBVmStakingPresentable === presentable)
        XCTAssertTrue(factory.view === view)
    }

    func testCanUnbondPassesWithinBondedAndFailsOtherwise() {
        XCTAssertNil(run(factory.canUnbond(amount: 5, bonded: 5, locale: locale)))
        XCTAssertEqual(run(factory.canUnbond(amount: 6, bonded: 5, locale: locale)), .error)
        XCTAssertEqual(run(factory.canUnbond(amount: nil, bonded: 5, locale: locale)), .error)
        XCTAssertEqual(run(factory.canUnbond(amount: 1, bonded: nil, locale: locale)), .error)
        XCTAssertEqual(presentable.calls, ["unbondingTooHigh", "unbondingTooHigh", "unbondingTooHigh"])
    }

    func testCanRebondPassesWithinUnbondingAndFailsOtherwise() {
        XCTAssertNil(run(factory.canRebond(amount: 1, unbonding: 2, locale: locale)))
        XCTAssertEqual(run(factory.canRebond(amount: 3, unbonding: 2, locale: locale)), .error)
        XCTAssertEqual(run(factory.canRebond(amount: nil, unbonding: nil, locale: locale)), .error)
        XCTAssertEqual(presentable.calls, ["rebondingTooHigh", "rebondingTooHigh"])
    }

    func testControllerAndStashPresenceReportTheMissingAddress() {
        XCTAssertNil(run(factory.has(controller: account(1), for: "ctrl", locale: locale)))
        XCTAssertEqual(run(factory.has(controller: nil, for: "ctrl", locale: locale)), .error)
        XCTAssertNil(run(factory.has(stash: account(2), for: "stash", locale: locale)))
        XCTAssertEqual(run(factory.has(stash: nil, for: "stash", locale: locale)), .error)
        XCTAssertEqual(presentable.calls, ["missingController", "missingStash"])
        XCTAssertEqual(presentable.values, ["ctrl", "stash"])
    }

    func testUnbondingsLimitAllowsFewerThanTheMaximum() {
        XCTAssertNil(run(factory.unbondingsLimitNotReached(fearless.SubstrateConstants.maxUnbondingRequests - 1, locale: locale)))
        XCTAssertEqual(run(factory.unbondingsLimitNotReached(fearless.SubstrateConstants.maxUnbondingRequests, locale: locale)), .error)
        XCTAssertEqual(run(factory.unbondingsLimitNotReached(nil, locale: locale)), .error)
        XCTAssertEqual(presentable.calls, ["unbondingLimit", "unbondingLimit"])
    }

    func testRewardHigherThanFeeWarnsAndCompletesWarningHandling() {
        XCTAssertNil(run(factory.rewardIsHigherThanFee(reward: 2, fee: 1, locale: locale)))
        XCTAssertEqual(run(factory.rewardIsHigherThanFee(reward: 1, fee: 1, locale: locale)), .warning)
        XCTAssertEqual(run(factory.rewardIsHigherThanFee(reward: nil, fee: 1, locale: locale)), .warning)
        XCTAssertEqual(presentable.calls, ["rewardLessThanFee", "rewardLessThanFee"])
        XCTAssertEqual(delegate.completions, 2)
    }

    func testControllerBalanceWarningOnZeroOrMissingBalance() {
        XCTAssertNil(run(factory.controllerBalanceIsNotZero(1, locale: locale)))
        XCTAssertEqual(run(factory.controllerBalanceIsNotZero(0, locale: locale)), .warning)
        XCTAssertEqual(run(factory.controllerBalanceIsNotZero(nil, locale: locale)), .warning)
        XCTAssertEqual(presentable.calls, ["controllerBalanceZero", "controllerBalanceZero"])
        XCTAssertEqual(delegate.completions, 2)
    }

    func testStashNotKilledAfterUnbondingKeepsMinimum() {
        XCTAssertNil(run(factory.stashIsNotKilledAfterUnbonding(amount: 5, bonded: 10, minimumAmount: 5, locale: locale)))
        XCTAssertEqual(
            run(factory.stashIsNotKilledAfterUnbonding(amount: 6, bonded: 10, minimumAmount: 5, locale: locale)),
            .warning
        )
        XCTAssertEqual(
            run(factory.stashIsNotKilledAfterUnbonding(amount: 1, bonded: 10, minimumAmount: nil, locale: locale)),
            .warning
        )
        XCTAssertEqual(presentable.calls, ["stashKilled", "stashKilled"])
        XCTAssertEqual(delegate.completions, 2)
    }

    func testWarningWithoutCompletionLeavesDelegateUntouched() {
        presentable.runsActions = false
        XCTAssertEqual(run(factory.rewardIsHigherThanFee(reward: 0, fee: 1, locale: locale)), .warning)
        XCTAssertEqual(delegate.completions, 0)
    }

    func testHasRedeemableRequiresUnlockedChunkInEra() throws {
        let value = try ledger(unlocking: [("10", "5"), ("20", "9")])
        XCTAssertNil(run(factory.hasRedeemable(stakingLedger: value, in: 5, locale: locale)))
        XCTAssertEqual(run(factory.hasRedeemable(stakingLedger: value, in: 4, locale: locale)), .error)
        XCTAssertEqual(run(factory.hasRedeemable(stakingLedger: value, in: nil, locale: locale)), .error)
        XCTAssertEqual(run(factory.hasRedeemable(stakingLedger: nil, in: 9, locale: locale)), .error)
        XCTAssertEqual(presentable.calls, ["noRedeemables", "noRedeemables", "noRedeemables"])
    }

    func testLedgerNotExistFailsWhenControllerHasLedger() throws {
        XCTAssertNil(run(factory.ledgerNotExist(stakingLedger: nil, locale: locale)))
        XCTAssertEqual(run(factory.ledgerNotExist(stakingLedger: try ledger(unlocking: []), locale: locale)), .error)
        XCTAssertEqual(presentable.calls, ["controllerUsed"])
    }

    func testCanNominateUsesTheLargerMinimumAndFormatsIt() {
        XCTAssertNil(run(factory.canNominate(amount: 10, minimalBalance: 5, minNominatorBond: 10, locale: locale)))
        XCTAssertEqual(run(factory.canNominate(amount: 9, minimalBalance: 5, minNominatorBond: 10, locale: locale)), .error)
        XCTAssertEqual(run(factory.canNominate(amount: 9, minimalBalance: 12, minNominatorBond: 10, locale: locale)), .error)
        XCTAssertEqual(run(factory.canNominate(amount: 3, minimalBalance: nil, minNominatorBond: 4, locale: locale)), .error)
        XCTAssertEqual(run(factory.canNominate(amount: 1, minimalBalance: 2, minNominatorBond: nil, locale: locale)), .error)
        XCTAssertNil(run(factory.canNominate(amount: 1, minimalBalance: nil, minNominatorBond: nil, locale: locale)))
        XCTAssertEqual(run(factory.canNominate(amount: nil, minimalBalance: nil, minNominatorBond: nil, locale: locale)), .error)
        XCTAssertEqual(presentable.values, ["10", "12", "4", "2", ""])
        XCTAssertEqual(presentable.calls.count, 5)
    }

    func testMaxNominatorsCountOnlyAppliesToNewNominators() {
        XCTAssertNil(run(factory.maxNominatorsCountNotApplied(
            counterForNominators: 1, maxNominatorsCount: 2, hasExistingNomination: false, locale: locale
        )))
        XCTAssertEqual(run(factory.maxNominatorsCountNotApplied(
            counterForNominators: 2, maxNominatorsCount: 2, hasExistingNomination: false, locale: locale
        )), .error)
        XCTAssertNil(run(factory.maxNominatorsCountNotApplied(
            counterForNominators: 2, maxNominatorsCount: 2, hasExistingNomination: true, locale: locale
        )))
        XCTAssertNil(run(factory.maxNominatorsCountNotApplied(
            counterForNominators: nil, maxNominatorsCount: 2, hasExistingNomination: false, locale: locale
        )))
        XCTAssertEqual(presentable.calls, ["maxNominators"])
    }

    func testCreatePoolNameNeedsCompletion() {
        XCTAssertNil(run(factory.createPoolName(complite: true, locale: locale)))
        XCTAssertEqual(run(factory.createPoolName(complite: false, locale: locale)), .error)
        XCTAssertEqual(run(factory.createPoolName(complite: nil, locale: locale)), .error)
        XCTAssertEqual(presentable.calls, ["missingPoolName", "missingPoolName"])
    }

    func testPoolRootCanUnbondReportsMinimalBondWithSymbol() {
        let asset = AssetModel(
            id: "covb", name: "Coverage", symbol: "dot", precision: 10,
            isUtility: true, isNative: true, staking: .relayChain
        )
        XCTAssertNil(run(factory.stakingPoolRootCanUnbond(
            amount: 1, bonded: 10, minimalRootBond: 9, locale: locale, asset: asset
        )))
        XCTAssertEqual(run(factory.stakingPoolRootCanUnbond(
            amount: 2, bonded: 10, minimalRootBond: 9, locale: locale, asset: asset
        )), .error)
        XCTAssertEqual(run(factory.stakingPoolRootCanUnbond(
            amount: 2, bonded: 10, minimalRootBond: nil, locale: locale, asset: asset
        )), .error)
        XCTAssertEqual(presentable.calls, ["poolRootUnbonding"])
        XCTAssertEqual(presentable.values, ["9 DOT"])
    }

    func testPoolsLimitRequiresKnownCounts() {
        XCTAssertNil(run(factory.poolsLimitNotReached(existingPoolsCount: 1, maximumPoolsCount: 2, locale: locale)))
        XCTAssertEqual(run(factory.poolsLimitNotReached(existingPoolsCount: 2, maximumPoolsCount: 2, locale: locale)), .error)
        XCTAssertEqual(run(factory.poolsLimitNotReached(existingPoolsCount: nil, maximumPoolsCount: 2, locale: locale)), .error)
        XCTAssertEqual(presentable.calls, ["maxPools", "maxPools"])
    }

    func testIsNotAlreadyControllerComparesTheChosenAddress() throws {
        let chosen = account(3)
        let chosenAddress = try XCTUnwrap(chosen.toAddress())
        let other = StashItem(stash: "stash", controller: "someone-else")
        let same = StashItem(stash: "stash", controller: chosenAddress)
        XCTAssertNil(run(factory.isNotAlreadyController(stashItem: other, chosenAccount: chosen, locale: locale)))
        XCTAssertEqual(run(factory.isNotAlreadyController(stashItem: same, chosenAccount: chosen, locale: locale)), .error)
        XCTAssertNil(run(factory.isNotAlreadyController(stashItem: nil, chosenAccount: chosen, locale: locale)))
        XCTAssertNil(run(factory.isNotAlreadyController(stashItem: same, chosenAccount: nil, locale: locale)))
        XCTAssertEqual(presentable.calls, ["controllerUsed"])
    }

    func testFailuresWithoutViewPresentNothing() throws {
        factory.view = nil
        let validators: [DataValidating] = [
            factory.canUnbond(amount: 2, bonded: 1, locale: locale),
            factory.canRebond(amount: 2, unbonding: 1, locale: locale),
            factory.has(controller: nil, for: "a", locale: locale),
            factory.has(stash: nil, for: "a", locale: locale),
            factory.unbondingsLimitNotReached(nil, locale: locale),
            factory.rewardIsHigherThanFee(reward: nil, fee: nil, locale: locale),
            factory.controllerBalanceIsNotZero(nil, locale: locale),
            factory.stashIsNotKilledAfterUnbonding(amount: nil, bonded: nil, minimumAmount: nil, locale: locale),
            factory.hasRedeemable(stakingLedger: nil, in: nil, locale: locale),
            factory.ledgerNotExist(stakingLedger: try ledger(unlocking: []), locale: locale),
            factory.canNominate(amount: nil, minimalBalance: 1, minNominatorBond: nil, locale: locale),
            factory.maxNominatorsCountNotApplied(
                counterForNominators: 3, maxNominatorsCount: 1, hasExistingNomination: false, locale: locale
            ),
            factory.createPoolName(complite: nil, locale: locale),
            factory.poolsLimitNotReached(existingPoolsCount: nil, maximumPoolsCount: nil, locale: locale),
            factory.isNotAlreadyController(
                stashItem: StashItem(stash: "s", controller: try XCTUnwrap(account(4).toAddress())),
                chosenAccount: account(4),
                locale: locale
            )
        ]
        let problems = validators.map { run($0) }
        XCTAssertTrue(problems.allSatisfy { $0 != nil })
        XCTAssertEqual(problems.filter { $0 == .warning }.count, 3)
        XCTAssertTrue(presentable.calls.isEmpty)
        XCTAssertEqual(delegate.completions, 0)
    }
}
