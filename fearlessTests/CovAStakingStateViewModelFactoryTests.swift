import BigInt
import SoraFoundation
import SSFModels
import SSFUtils
import XCTest
@testable import fearless

final class CovAStakingStateViewModelFactoryTests: XCTestCase {
    private typealias CovAFixtureAlias = CovAStakingMainFixtures
    private let locale = CovAFixtures.locale

    private func makeFactory() -> StakingStateViewModelFactory {
        StakingStateViewModelFactory(
            analyticsRewardsViewModelFactoryBuilder: { chainAsset, balanceViewModelFactory in
                AnalyticsRewardsViewModelFactory(
                    assetInfo: chainAsset.assetDisplayInfo,
                    balanceViewModelFactory: balanceViewModelFactory,
                    calendar: Calendar(identifier: .gregorian)
                )
            },
            logger: Logger.shared,
            selectedMetaAccount: CovAFixtures.wallet(),
            eventCenter: EventCenter.shared
        )
    }

    /// Puts a fresh machine into the common staking data every view model needs.
    private func makeMachine(
        minStake: BigUInt? = 2_000_000_000_000,
        nominators: [UInt8] = [7],
        subquery: Bool = true
    ) throws -> StakingStateMachine {
        let machine = StakingStateMachine()
        machine.state.process(chainAsset: CovAFixtures.chainAsset(price: 2))
        machine.state.process(address: CovAFixtureAlias.stashAddress)
        machine.state.process(accountInfo: WestendStub.accountInfo.item)
        machine.state.process(calculator: CovARewardCalculatorStub())
        try machine.state.process(eraStakersInfo: CovAFixtureAlias.eraStakers(activeEra: 10, nominators: nominators))
        machine.state.process(minStake: minStake)
        machine.state.process(maxNominatorsPerValidator: 1)
        machine.state.process(eraCountdown: CovAFixtureAlias.eraCountdown())
        if subquery {
            let reward = SubqueryRewardItemData(
                eventId: "1", timestamp: Int64(Date().timeIntervalSince1970), validatorAddress: CovAFixtures.address(1),
                era: 9, stashAddress: CovAFixtureAlias.stashAddress, amount: BigUInt(1_000_000_000_000), isReward: true
            )
            machine.state.process(subqueryRewards: ([reward], .week))
        }
        return machine
    }

    func testUndefinedForStatesWithoutViewModels() throws {
        let factory = makeFactory()
        let emptyMachine = StakingStateMachine()
        guard case .undefined = factory.createViewModel(from: emptyMachine.state) else { return XCTFail("initial without asset") }

        let machine = try makeMachine()
        guard case .undefined = factory.createViewModel(from: machine.state) else { return XCTFail("initial") }
        machine.state.process(stashItem: CovAFixtureAlias.stash())
        guard case .undefined = factory.createViewModel(from: machine.state) else { return XCTFail("stash") }
        try machine.state.process(nomination: CovAFixtureAlias.nomination())
        guard case .undefined = factory.createViewModel(from: machine.state) else { return XCTFail("pending nominator") }

        let second = try makeMachine()
        second.state.process(stashItem: CovAFixtureAlias.stash())
        second.state.process(nomination: nil)
        guard case .undefined = factory.createViewModel(from: second.state) else { return XCTFail("pending validator") }
        second.state.process(validatorPrefs: nil)
        guard case .undefined = factory.createViewModel(from: second.state) else { return XCTFail("pending bonded") }
    }

    func testNoStashEstimationWithRewards() throws {
        let factory = makeFactory()
        let machine = try makeMachine()
        machine.state.process(stashItem: nil)
        machine.state.process(rewardEstimationAmount: 10)
        guard case let .noStash(viewModel, alerts) = factory.createViewModel(from: machine.state) else {
            return XCTFail("no stash expected")
        }
        XCTAssertTrue(alerts.isEmpty)
        XCTAssertEqual(viewModel.amount, 10)
        XCTAssertEqual(viewModel.inputLimit, StakingConstants.maxAmount)
        let balance = viewModel.assetBalance.value(for: locale)
        XCTAssertEqual(balance.symbol.uppercased(), "COV")
        XCTAssertNotNil(balance.balance)
        let rewards = try XCTUnwrap(viewModel.rewardViewModel?.value(for: locale))
        XCTAssertTrue(rewards.yearlyReward.amount.contains("1.2"), rewards.yearlyReward.amount)
        XCTAssertNotNil(rewards.monthlyReward.increase)

        let withoutCalculator = StakingStateMachine()
        withoutCalculator.state.process(chainAsset: CovAFixtures.chainAsset())
        withoutCalculator.state.process(stashItem: nil)
        guard case let .noStash(plain, _) = factory.createViewModel(from: withoutCalculator.state) else {
            return XCTFail("no stash expected")
        }
        XCTAssertNil(plain.rewardViewModel)
    }

    func testActiveNominatorViewModel() throws {
        let factory = makeFactory()
        let machine = try makeMachine(minStake: 1)
        machine.state.process(stashItem: CovAFixtureAlias.stash())
        machine.state.process(totalReward: CovAFixtureAlias.totalReward())
        try machine.state.process(ledgerInfo: CovAFixtureAlias.ledger(unlocking: [("500000000000", "3")]))
        try machine.state.process(nomination: CovAFixtureAlias.nomination())

        let nominator = try XCTUnwrap(machine.state as? NominatorState)
        guard case let .active(era) = nominator.status else { return XCTFail("active nominator") }
        XCTAssertEqual(era, 10)
        XCTAssertFalse(nominator.allValidatorsWithoutReward)
        XCTAssertNotNil(nominator.createStatusPresentableViewModel(locale: locale))

        guard case let .nominator(viewModel, alerts, analytics) = factory.createViewModel(from: machine.state) else {
            return XCTFail("nominator expected")
        }
        let content = viewModel.value(for: locale)
        XCTAssertTrue(content.totalStakedAmount.contains("1"))
        XCTAssertTrue(content.totalRewardAmount.contains("12"), content.totalRewardAmount)
        guard case .active = content.status else { return XCTFail("active status") }
        XCTAssertEqual(alerts.count, 1)
        guard case let .redeemUnbonded(amount) = alerts[0] else { return XCTFail("redeem alert") }
        XCTAssertTrue(amount.value(for: locale).contains("0.5"))
        XCTAssertNotNil(analytics?.value(for: locale))
    }

    func testInactiveNominatorAlertsAndStatusSheets() throws {
        let factory = makeFactory()

        // low stake: the ledger is below the minimum stake
        let lowStake = try makeMachine(nominators: [9], subquery: false)
        lowStake.state.process(stashItem: CovAFixtureAlias.stash())
        try lowStake.state.process(ledgerInfo: CovAFixtureAlias.ledger())
        try lowStake.state.process(nomination: CovAFixtureAlias.nomination(submittedIn: 1))
        let lowState = try XCTUnwrap(lowStake.state as? NominatorState)
        guard case .inactive = lowState.status else { return XCTFail("inactive") }
        XCTAssertNotNil(lowState.createStatusPresentableViewModel(locale: locale)?.message)
        guard case let .nominator(_, alerts, analytics) = factory.createViewModel(from: lowStake.state) else {
            return XCTFail("nominator")
        }
        XCTAssertNil(analytics)
        guard case .nominatorLowStake = alerts.first else { return XCTFail("low stake alert") }

        // enough stake but nobody rewarded: change validators
        let change = try makeMachine(minStake: 1, nominators: [9], subquery: false)
        change.state.process(stashItem: CovAFixtureAlias.stash())
        try change.state.process(ledgerInfo: CovAFixtureAlias.ledger())
        try change.state.process(nomination: CovAFixtureAlias.nomination(submittedIn: 1))
        guard case let .nominator(_, changeAlerts, _) = factory.createViewModel(from: change.state) else {
            return XCTFail("nominator")
        }
        guard case .nominatorChangeValidators = changeAlerts.first else { return XCTFail("change validators") }
        XCTAssertNotNil((change.state as? NominatorState)?.createStatusPresentableViewModel(locale: locale))

        // the stash sits behind the rewarded slots: oversubscribed
        let oversubscribed = try makeMachine(minStake: 1, nominators: [9, 7], subquery: false)
        oversubscribed.state.process(stashItem: CovAFixtureAlias.stash())
        try oversubscribed.state.process(ledgerInfo: CovAFixtureAlias.ledger())
        try oversubscribed.state.process(nomination: CovAFixtureAlias.nomination(submittedIn: 1))
        XCTAssertTrue(try XCTUnwrap(oversubscribed.state as? NominatorState).allValidatorsWithoutReward)
        guard case let .nominator(_, overAlerts, _) = factory.createViewModel(from: oversubscribed.state) else {
            return XCTFail("nominator")
        }
        guard case .nominatorAllOversubscribed = overAlerts.first else { return XCTFail("oversubscribed alert") }

        // a fresh nomination waits for the next era
        let waiting = try makeMachine(minStake: 1, nominators: [9], subquery: false)
        waiting.state.process(stashItem: CovAFixtureAlias.stash())
        try waiting.state.process(ledgerInfo: CovAFixtureAlias.ledger())
        try waiting.state.process(nomination: CovAFixtureAlias.nomination(submittedIn: 10))
        let waitingState = try XCTUnwrap(waiting.state as? NominatorState)
        guard case .waiting = waitingState.status else { return XCTFail("waiting") }
        XCTAssertNotNil(waitingState.createStatusPresentableViewModel(locale: locale))
        guard case let .nominator(_, waitAlerts, _) = factory.createViewModel(from: waiting.state) else {
            return XCTFail("nominator")
        }
        guard case .waitingNextEra = waitAlerts.last else { return XCTFail("waiting alert") }
    }

    func testBondedAndValidatorViewModels() throws {
        let factory = makeFactory()
        let bonded = try makeMachine()
        bonded.state.process(stashItem: CovAFixtureAlias.stash())
        try bonded.state.process(ledgerInfo: CovAFixtureAlias.ledger(unlocking: [("100000000000", "1")]))
        bonded.state.process(nomination: nil)
        bonded.state.process(validatorPrefs: nil)
        let bondedState = try XCTUnwrap(bonded.state as? BondedState)
        guard case .inactive = bondedState.status else { return XCTFail("bonded is inactive") }
        XCTAssertNotNil(bondedState.createStatusPresentableViewModel(locale: locale))
        guard case let .nominator(viewModel, alerts, _) = factory.createViewModel(from: bonded.state) else {
            return XCTFail("bonded shows nomination")
        }
        guard case .inactive = viewModel.value(for: locale).status else { return XCTFail("inactive status") }
        XCTAssertEqual(alerts.count, 3)
        guard case .nominatorLowStake = alerts[0], case .bondedSetValidators = alerts[1], case .redeemUnbonded = alerts[2] else {
            return XCTFail("bonded alerts \(alerts)")
        }
        XCTAssertTrue(viewModel.value(for: locale).totalRewardAmount.isEmpty == false)

        let validator = try makeMachine(nominators: [7])
        validator.state.process(stashItem: StashItem(stash: CovAFixtures.address(1), controller: CovAFixtures.address(1)))
        try validator.state.process(ledgerInfo: CovAFixtureAlias.ledger(unlocking: [("100000000000", "1")]))
        validator.state.process(validatorPrefs: CovAFixtureAlias.prefs())
        validator.state.process(totalReward: CovAFixtureAlias.totalReward())
        let validatorState = try XCTUnwrap(validator.state as? ValidatorState)
        guard case .active = validatorState.status else { return XCTFail("elected validator is active") }
        XCTAssertNotNil(validatorState.createStatusPresentableViewModel(for: locale))
        guard case let .validator(validation, validatorAlerts, analytics) = factory.createViewModel(from: validator.state) else {
            return XCTFail("validator expected")
        }
        XCTAssertTrue(validation.value(for: locale).totalRewardAmount.contains("12"))
        XCTAssertEqual(validatorAlerts.count, 1)
        XCTAssertNotNil(analytics)

        let inactive = try makeMachine()
        inactive.state.process(stashItem: StashItem(stash: CovAFixtures.address(5), controller: CovAFixtures.address(5)))
        try inactive.state.process(ledgerInfo: CovAFixtureAlias.ledger())
        inactive.state.process(validatorPrefs: CovAFixtureAlias.prefs())
        let inactiveState = try XCTUnwrap(inactive.state as? ValidatorState)
        guard case .inactive = inactiveState.status else { return XCTFail("unelected validator is inactive") }
        XCTAssertNotNil(inactiveState.createStatusPresentableViewModel(for: locale))
    }

    func testStatusesAreUndefinedWithoutEraData() throws {
        let machine = StakingStateMachine()
        machine.state.process(chainAsset: CovAFixtures.chainAsset())
        machine.state.process(stashItem: CovAFixtureAlias.stash())
        try machine.state.process(ledgerInfo: CovAFixtureAlias.ledger())
        try machine.state.process(nomination: CovAFixtureAlias.nomination())
        let nominator = try XCTUnwrap(machine.state as? NominatorState)
        guard case .undefined = nominator.status else { return XCTFail("undefined") }
        XCTAssertFalse(nominator.allValidatorsWithoutReward)
        XCTAssertNil(nominator.createStatusPresentableViewModel(locale: locale))
        machine.state.process(validatorPrefs: CovAFixtureAlias.prefs())
        let validator = try XCTUnwrap(machine.state as? ValidatorState)
        guard case .undefined = validator.status else { return XCTFail("undefined") }
        machine.state.process(validatorPrefs: nil)
        let bonded = try XCTUnwrap(machine.state as? BondedState)
        guard case .undefined = bonded.status else { return XCTFail("undefined") }
        XCTAssertNil(bonded.createStatusPresentableViewModel(locale: locale))

        let factory = makeFactory()
        guard case let .nominator(viewModel, _, _) = factory.createViewModel(from: bonded) else { return XCTFail("bonded") }
        guard case .undefined = viewModel.value(for: locale).status else { return XCTFail("undefined status") }
        factory.processMetaAccountChanged(event: MetaAccountModelChangedEvent(account: CovAFixtures.wallet()))
    }
}
