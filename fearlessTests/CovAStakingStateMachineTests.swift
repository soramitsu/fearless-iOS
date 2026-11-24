import BigInt
import SoraFoundation
import SSFModels
import SSFUtils
import XCTest
@testable import fearless

final class CovAStakingStateMachineTests: XCTestCase {
    private typealias CovAFixtureAlias = CovAStakingMainFixtures

    private func makeMachine() -> (StakingStateMachine, CovAStakingStateRecorder) {
        let machine = StakingStateMachine()
        let recorder = CovAStakingStateRecorder()
        machine.delegate = recorder
        machine.state.process(chainAsset: CovAFixtures.chainAsset())
        machine.state.process(address: CovAFixtureAlias.stashAddress)
        return (machine, recorder)
    }

    func testCommonDataIsSharedThroughEveryProcessCall() throws {
        let (machine, recorder) = makeMachine()
        XCTAssertEqual(recorder.visited, ["initial", "initial"])
        let state = machine.state
        state.process(accountInfo: WestendStub.accountInfo.item)
        state.process(calculator: CovARewardCalculatorStub())
        try state.process(eraStakersInfo: CovAFixtureAlias.eraStakers())
        state.process(minStake: BigUInt(10))
        state.process(maxNominatorsPerValidator: 64)
        state.process(minNominatorBond: BigUInt(20))
        state.process(counterForNominators: 5)
        state.process(maxNominatorsCount: 50)
        state.process(rewardChainAsset: CovAFixtures.chainAsset())
        state.process(rewardAssetPrice: nil)
        state.process(eraCountdown: CovAFixtureAlias.eraCountdown())
        state.process(subqueryRewards: ([], .month))
        state.process(rewardEstimationAmount: 5)
        try state.process(ledgerInfo: CovAFixtureAlias.ledger())
        try state.process(nomination: CovAFixtureAlias.nomination())
        state.process(validatorPrefs: CovAFixtureAlias.prefs())
        state.process(totalReward: CovAFixtureAlias.totalReward())
        state.process(payee: .staked)

        let base = try XCTUnwrap(machine.state as? BaseStakingState)
        XCTAssertEqual(base.commonData.address, CovAFixtureAlias.stashAddress)
        XCTAssertEqual(base.commonData.minStake, 10)
        XCTAssertEqual(base.commonData.maxNominatorsPerValidator, 64)
        XCTAssertEqual(base.commonData.minNominatorBond, 20)
        XCTAssertEqual(base.commonData.counterForNominators, 5)
        XCTAssertEqual(base.commonData.maxNominatorsCount, 50)
        XCTAssertEqual(base.commonData.eraStakersInfo?.activeEra, 10)
        XCTAssertNotNil(base.commonData.calculatorEngine)
        XCTAssertNotNil(base.commonData.accountInfo)
        XCTAssertNotNil(base.commonData.eraCountdown)
        XCTAssertEqual(base.commonData.subqueryRewards?.1, .month)
        XCTAssertNotNil(base.commonData.rewardChainAsset)
        XCTAssertEqual(recorder.visited.filter { $0 == "initial" }.count, recorder.visited.count, "the initial state only changes on a stash")

        // a new address resets the account data and restarts from the initial state
        state.process(address: CovAFixtures.address(8))
        let reset = try XCTUnwrap(machine.state as? BaseStakingState)
        XCTAssertNil(reset.commonData.accountInfo)
        XCTAssertNil(reset.commonData.subqueryRewards?.0)
        // a new chain asset resets everything
        machine.state.process(chainAsset: CovAFixtures.chainAsset(chainId: "cov-a-other"))
        let other = try XCTUnwrap(machine.state as? BaseStakingState)
        XCTAssertNil(other.commonData.minStake)
        XCTAssertEqual(other.commonData.chainAsset?.chain.chainId, "cov-a-other")
    }

    func testNoStashStashAndNominatorTransitions() throws {
        let (machine, recorder) = makeMachine()
        machine.state.process(stashItem: nil)
        XCTAssertEqual(recorder.last, "noStash")
        machine.state.process(rewardEstimationAmount: 7)
        XCTAssertEqual((machine.state as? NoStashState)?.rewardEstimationAmount, 7)
        machine.state.process(stashItem: nil)
        XCTAssertEqual(recorder.last, "noStash")

        machine.state.process(stashItem: CovAFixtureAlias.stash())
        XCTAssertEqual(recorder.last, "stash")
        machine.state.process(stashItem: CovAFixtureAlias.stash(controller: 8))
        XCTAssertEqual((machine.state as? StashState)?.stashItem.controller, CovAFixtures.address(8))
        machine.state.process(totalReward: CovAFixtureAlias.totalReward())
        machine.state.process(payee: .stash)
        try machine.state.process(ledgerInfo: CovAFixtureAlias.ledger())
        let stash = try XCTUnwrap(machine.state as? StashState)
        XCTAssertNotNil(stash.ledgerInfo)
        XCTAssertEqual(stash.payee, .stash)
        XCTAssertNotNil(stash.totalReward)

        try machine.state.process(nomination: CovAFixtureAlias.nomination())
        XCTAssertEqual(recorder.last, "nominator")
        let nominator = try XCTUnwrap(machine.state as? NominatorState)
        XCTAssertEqual(nominator.nomination.targets.count, 2)
        XCTAssertEqual(nominator.payee, .stash)

        // nominator keeps itself while data stays, then falls back
        try machine.state.process(ledgerInfo: CovAFixtureAlias.ledger(active: "5"))
        XCTAssertEqual(recorder.last, "nominator")
        try machine.state.process(nomination: CovAFixtureAlias.nomination(submittedIn: 3))
        XCTAssertEqual(recorder.last, "nominator")
        machine.state.process(validatorPrefs: nil)
        XCTAssertEqual(recorder.last, "nominator")
        machine.state.process(totalReward: nil)
        machine.state.process(payee: .controller)
        machine.state.process(stashItem: CovAFixtureAlias.stash(controller: 8))
        XCTAssertEqual(recorder.last, "nominator", "the same stash keeps the state")
        machine.state.process(nomination: nil)
        XCTAssertEqual(recorder.last, "bonded")
        try machine.state.process(nomination: CovAFixtureAlias.nomination())
        XCTAssertEqual(recorder.last, "nominator")
        machine.state.process(validatorPrefs: CovAFixtureAlias.prefs())
        XCTAssertEqual(recorder.last, "validator")
        machine.state.process(ledgerInfo: nil)
        XCTAssertEqual(recorder.last, "stash")
        machine.state.process(stashItem: nil)
        XCTAssertEqual(recorder.last, "noStash")
    }

    func testPendingStatesResolveWhenDataArrives() throws {
        let (machine, recorder) = makeMachine()
        machine.state.process(stashItem: CovAFixtureAlias.stash())
        try machine.state.process(nomination: CovAFixtureAlias.nomination())
        XCTAssertEqual(recorder.last, "pendingNominator")
        try machine.state.process(ledgerInfo: CovAFixtureAlias.ledger())
        XCTAssertEqual(recorder.last, "nominator")

        machine.state.process(stashItem: CovAFixtureAlias.stash(controller: 9))
        XCTAssertEqual(recorder.last, "stash", "a changed stash restarts from the stash state")
        machine.state.process(nomination: nil)
        XCTAssertEqual(recorder.last, "pendingValidator")
        machine.state.process(nomination: nil)
        XCTAssertEqual(recorder.last, "pendingValidator")
        machine.state.process(validatorPrefs: CovAFixtureAlias.prefs())
        XCTAssertEqual(recorder.last, "pendingValidator")
        try machine.state.process(ledgerInfo: CovAFixtureAlias.ledger())
        XCTAssertEqual(recorder.last, "validator")
        let validator = try XCTUnwrap(machine.state as? ValidatorState)
        XCTAssertEqual(validator.prefs.commission, 50_000_000)

        machine.state.process(validatorPrefs: CovAFixtureAlias.prefs(commission: 1))
        XCTAssertEqual(recorder.last, "validator")
        try machine.state.process(ledgerInfo: CovAFixtureAlias.ledger(active: "7"))
        machine.state.process(validatorPrefs: nil)
        XCTAssertEqual(recorder.last, "bonded")
        machine.state.process(validatorPrefs: CovAFixtureAlias.prefs())
        XCTAssertEqual(recorder.last, "validator")
        try machine.state.process(nomination: CovAFixtureAlias.nomination())
        XCTAssertEqual(recorder.last, "nominator")
    }

    func testPendingBondedAndBondedTransitions() throws {
        let (machine, recorder) = makeMachine()
        machine.state.process(stashItem: CovAFixtureAlias.stash())
        machine.state.process(validatorPrefs: nil)
        XCTAssertEqual(recorder.last, "pendingNominator")
        machine.state.process(validatorPrefs: nil)
        XCTAssertEqual(recorder.last, "pendingNominator")
        machine.state.process(nomination: nil)
        XCTAssertEqual(recorder.last, "pendingBonded")

        let (second, secondRecorder) = makeMachine()
        second.state.process(stashItem: CovAFixtureAlias.stash())
        second.state.process(nomination: nil)
        XCTAssertEqual(secondRecorder.last, "pendingValidator")
        second.state.process(validatorPrefs: nil)
        XCTAssertEqual(secondRecorder.last, "pendingBonded")
        second.state.process(nomination: nil)
        second.state.process(validatorPrefs: nil)
        second.state.process(ledgerInfo: nil)
        XCTAssertEqual(secondRecorder.last, "pendingBonded")
        try second.state.process(nomination: CovAFixtureAlias.nomination())
        XCTAssertEqual(secondRecorder.last, "pendingNominator")

        let (third, thirdRecorder) = makeMachine()
        third.state.process(stashItem: CovAFixtureAlias.stash())
        third.state.process(nomination: nil)
        third.state.process(validatorPrefs: nil)
        third.state.process(validatorPrefs: CovAFixtureAlias.prefs())
        XCTAssertEqual(thirdRecorder.last, "pendingValidator")

        let (fourth, fourthRecorder) = makeMachine()
        fourth.state.process(stashItem: CovAFixtureAlias.stash())
        fourth.state.process(nomination: nil)
        fourth.state.process(validatorPrefs: nil)
        try fourth.state.process(ledgerInfo: CovAFixtureAlias.ledger())
        XCTAssertEqual(fourthRecorder.last, "bonded")
        fourth.state.process(rewardEstimationAmount: 3)
        XCTAssertEqual((fourth.state as? BondedState)?.rewardEstimationAmount, 3)
        try fourth.state.process(ledgerInfo: CovAFixtureAlias.ledger(active: "9"))
        fourth.state.process(nomination: nil)
        fourth.state.process(validatorPrefs: nil)
        XCTAssertEqual(fourthRecorder.last, "bonded")
        fourth.state.process(validatorPrefs: CovAFixtureAlias.prefs())
        XCTAssertEqual(fourthRecorder.last, "validator")
        fourth.state.process(validatorPrefs: nil)
        fourth.state.process(ledgerInfo: nil)
        XCTAssertEqual(fourthRecorder.last, "stash")

        let (fifth, fifthRecorder) = makeMachine()
        fifth.state.process(stashItem: CovAFixtureAlias.stash())
        try fifth.state.process(ledgerInfo: CovAFixtureAlias.ledger())
        fifth.state.process(validatorPrefs: nil)
        fifth.state.process(nomination: nil)
        XCTAssertEqual(fifthRecorder.last, "bonded")
        try fifth.state.process(nomination: CovAFixtureAlias.nomination())
        XCTAssertEqual(fifthRecorder.last, "nominator")
        fifth.state.process(stashItem: nil)
        XCTAssertEqual(fifthRecorder.last, "noStash")
    }

    func testValidatorFromStashAndPendingValidatorBranches() throws {
        let (machine, recorder) = makeMachine()
        machine.state.process(stashItem: CovAFixtureAlias.stash())
        machine.state.process(validatorPrefs: CovAFixtureAlias.prefs())
        XCTAssertEqual(recorder.last, "pendingValidator")
        try machine.state.process(nomination: CovAFixtureAlias.nomination())
        XCTAssertEqual(recorder.last, "pendingNominator")

        let (second, secondRecorder) = makeMachine()
        second.state.process(stashItem: CovAFixtureAlias.stash())
        try second.state.process(ledgerInfo: CovAFixtureAlias.ledger())
        second.state.process(validatorPrefs: CovAFixtureAlias.prefs())
        XCTAssertEqual(secondRecorder.last, "validator")
        second.state.process(nomination: nil)
        XCTAssertEqual(secondRecorder.last, "validator")

        let (third, thirdRecorder) = makeMachine()
        third.state.process(stashItem: CovAFixtureAlias.stash())
        try third.state.process(ledgerInfo: CovAFixtureAlias.ledger())
        third.state.process(nomination: nil)
        XCTAssertEqual(thirdRecorder.last, "pendingValidator")
        try third.state.process(nomination: CovAFixtureAlias.nomination())
        XCTAssertEqual(thirdRecorder.last, "nominator")

        let (fourth, fourthRecorder) = makeMachine()
        fourth.state.process(stashItem: CovAFixtureAlias.stash())
        try fourth.state.process(ledgerInfo: CovAFixtureAlias.ledger())
        fourth.state.process(nomination: nil)
        fourth.state.process(validatorPrefs: nil)
        XCTAssertEqual(fourthRecorder.last, "bonded")

        let (fifth, fifthRecorder) = makeMachine()
        fifth.state.process(stashItem: CovAFixtureAlias.stash())
        try fifth.state.process(nomination: CovAFixtureAlias.nomination())
        fifth.state.process(stashItem: nil)
        XCTAssertEqual(fifthRecorder.last, "noStash")
    }

    func testStatesWithoutMachineIgnoreTransitions() {
        let common = StakingStateCommonData.empty.byReplacing(chainAsset: CovAFixtures.chainAsset())
        let initial = InitialRelaychainStakingState(stateMachine: nil, commonData: common)
        initial.process(stashItem: CovAFixtureAlias.stash())
        initial.process(chainAsset: CovAFixtures.chainAsset(chainId: "x"))
        initial.process(address: "y")
        XCTAssertEqual(initial.commonData.address, "y")
        XCTAssertEqual(initial.commonData.chainAsset?.chain.chainId, "x")
    }
}
