import BigInt
import SoraFoundation
import SSFModels
import SSFUtils
import UIKit
import XCTest
@testable import fearless

final class CovAStakingMainPresenterSpy: StakingMainPresenterProtocol {
    private(set) var calls: [String] = []

    func didTriggerViewWillAppear() {
        calls.append("willAppear")
    }

    func didTriggerViewWillDisappear() {
        calls.append("willDisappear")
    }

    func setup() {
        calls.append("setup")
    }

    func performAssetSelection() {
        calls.append("asset")
    }

    func performMainAction() {
        calls.append("main")
    }

    func performAccountAction() {
        calls.append("account")
    }

    func performManageStakingAction() {
        calls.append("manage")
    }

    func performNominationStatusAction() {
        calls.append("nominationStatus")
    }

    func performValidationStatusAction() {
        calls.append("validationStatus")
    }

    func performRewardInfoAction() {
        calls.append("rewardInfo")
    }

    func performChangeValidatorsAction() {
        calls.append("changeValidators")
    }

    func performSetupValidatorsForBondedAction() {
        calls.append("setupValidators")
    }

    func performBondMoreAction() {
        calls.append("bondMore")
    }

    func performRedeemAction() {
        calls.append("redeem")
    }

    func performAnalyticsAction() {
        calls.append("analytics")
    }

    func updateAmount(_ newValue: Decimal) {
        calls.append("amount:\(newValue)")
    }

    func selectAmountPercentage(_ percentage: Float) {
        calls.append("percentage:\(percentage)")
    }

    func selectStory(at index: Int) {
        calls.append("story:\(index)")
    }

    func networkInfoViewDidChangeExpansion(isExpanded: Bool) {
        calls.append("expanded:\(isExpanded)")
    }
}

final class CovAStakingMainViewTests: XCTestCase {
    private typealias CovAFixtureAlias = CovAStakingMainFixtures
    private let locale = CovAFixtures.locale

    private func stateFactory() -> StakingStateViewModelFactory {
        StakingStateViewModelFactory(
            analyticsRewardsViewModelFactoryBuilder: { chainAsset, balance in
                AnalyticsRewardsViewModelFactory(
                    assetInfo: chainAsset.assetDisplayInfo,
                    balanceViewModelFactory: balance,
                    calendar: Calendar(identifier: .gregorian)
                )
            },
            selectedMetaAccount: CovAFixtures.wallet(),
            eventCenter: EventCenter.shared
        )
    }

    private func machine() throws -> StakingStateMachine {
        let machine = StakingStateMachine()
        machine.state.process(chainAsset: CovAFixtures.chainAsset())
        machine.state.process(address: CovAFixtureAlias.stashAddress)
        machine.state.process(accountInfo: WestendStub.accountInfo.item)
        machine.state.process(calculator: CovARewardCalculatorStub())
        try machine.state.process(eraStakersInfo: CovAFixtureAlias.eraStakers())
        machine.state.process(minStake: 2_000_000_000_000)
        machine.state.process(maxNominatorsPerValidator: 64)
        let reward = SubqueryRewardItemData(
            eventId: "1", timestamp: Int64(Date().timeIntervalSince1970) - 3600, validatorAddress: CovAFixtures.address(1),
            era: 9, stashAddress: CovAFixtureAlias.stashAddress, amount: BigUInt(1_000_000_000_000), isReward: true
        )
        machine.state.process(subqueryRewards: ([reward], .week))
        return machine
    }

    private func noStashState() throws -> StakingViewState {
        let machine = try machine()
        machine.state.process(stashItem: nil)
        machine.state.process(rewardEstimationAmount: 4)
        return stateFactory().createViewModel(from: machine.state)
    }

    private func nominatorState() throws -> StakingViewState {
        let machine = try machine()
        machine.state.process(stashItem: CovAFixtureAlias.stash())
        try machine.state.process(ledgerInfo: CovAFixtureAlias.ledger(unlocking: [("500000000000", "3"), ("100000000000", "40")]))
        machine.state.process(totalReward: CovAFixtureAlias.totalReward())
        try machine.state.process(nomination: CovAFixtureAlias.nomination())
        return stateFactory().createViewModel(from: machine.state)
    }

    private func validatorState() throws -> StakingViewState {
        let machine = try machine()
        machine.state.process(stashItem: StashItem(stash: CovAFixtures.address(1), controller: CovAFixtures.address(1)))
        try machine.state.process(ledgerInfo: CovAFixtureAlias.ledger())
        machine.state.process(validatorPrefs: CovAFixtureAlias.prefs())
        return stateFactory().createViewModel(from: machine.state)
    }

    private func networkInfo() -> LocalizableResource<NetworkStakingInfoViewModelProtocol> {
        let info = NetworkStakingInfo.relaychain(
            baseInfo: BaseStakingInfo(lockUpPeriod: 28, minimalBalance: 1_000_000_000, minStakeAmongActiveNominators: 2_000_000_000),
            relaychainInfo: RelaychainStakingInfo(
                stakingDuration: StakingDuration(session: 3600, era: 21600, unlocking: 2_419_200),
                totalStake: BigUInt(1_000_000_000_000_000),
                activeNominatorsCount: 10
            )
        )
        return NetworkInfoViewModelFactory().createNetworkStakingInfoViewModel(
            with: info, chainAsset: CovAFixtures.chainAsset(), minNominatorBond: 5, priceData: nil,
            selectedMetaAccount: CovAFixtures.wallet()
        )
    }

    private func makeController() -> (StakingMainViewController, CovAStakingMainPresenterSpy, UIWindow) {
        let controller = StakingMainViewController(nib: R.nib.stakingMainViewController)
        let presenter = CovAStakingMainPresenterSpy()
        controller.presenter = presenter
        controller.localizationManager = CovAFixtures.localizationManager
        let window = CovAViewInspector.host(UINavigationController(rootViewController: controller))
        controller.beginAppearanceTransition(true, animated: false)
        controller.endAppearanceTransition()
        return (controller, presenter, window)
    }

    func testControllerRendersEveryStakingState() throws {
        let (controller, presenter, window) = makeController()
        XCTAssertEqual(presenter.calls.prefix(2), ["willAppear", "setup"])

        let mainViewModel = NetworkInfoViewModelFactory().createMainViewModel(
            from: CovAFixtureAlias.stashAddress, chainAsset: CovAFixtures.chainAsset(), balance: 10, selectedMetaAccount: CovAFixtures.wallet()
        )
        controller.didReceive(viewModel: mainViewModel)
        controller.didRecieveNetworkStakingInfo(viewModel: networkInfo())
        controller.expandNetworkInfoView(true)
        controller.expandNetworkInfoView(false)
        XCTAssertEqual(controller.assetSelectionView.title, mainViewModel.assetName)

        try controller.didReceiveStakingState(viewModel: noStashState())
        controller.view.layoutIfNeeded()
        let estimation = try XCTUnwrap(CovAViewInspector.subviews(of: RewardEstimationView.self, in: controller.view).first)
        estimation.delegate?.rewardEstimationView(estimation, didChange: 2)
        estimation.delegate?.rewardEstimationView(estimation, didSelect: 0.5)
        estimation.delegate?.rewardEstimationDidRequestInfo(estimation)
        XCTAssertTrue(presenter.calls.contains("amount:2"))
        XCTAssertTrue(presenter.calls.contains("percentage:0.5"))
        XCTAssertTrue(presenter.calls.contains("rewardInfo"))
        if case let .noStash(estimationViewModel, _) = try noStashState() {
            controller.didReceive(stakingEstimationViewModel: estimationViewModel)
        }

        try controller.didReceiveStakingState(viewModel: nominatorState())
        controller.view.layoutIfNeeded()
        let nominatorView = try XCTUnwrap(CovAViewInspector.subviews(of: NominatorStateView.self, in: controller.view).first)
        XCTAssertFalse((nominatorView.stakeAmountView.valueLabel.text ?? "").isEmpty)
        nominatorView.delegate?.stakingStateViewDidReceiveMoreAction(nominatorView)
        nominatorView.delegate?.stakingStateViewDidReceiveStatusAction(nominatorView)
        XCTAssertTrue(presenter.calls.contains("manage"))
        XCTAssertTrue(presenter.calls.contains("nominationStatus"))

        try controller.didReceiveStakingState(viewModel: validatorState())
        controller.view.layoutIfNeeded()
        let validatorView = try XCTUnwrap(CovAViewInspector.subviews(of: ValidatorStateView.self, in: controller.view).first)
        validatorView.delegate?.stakingStateViewDidReceiveStatusAction(validatorView)
        XCTAssertTrue(presenter.calls.contains("validationStatus"))

        controller.didReceiveStakingState(viewModel: .undefined)
        XCTAssertTrue(CovAViewInspector.subviews(of: ValidatorStateView.self, in: controller.view).isEmpty)

        for alert in [StakingAlert.nominatorChangeValidators, .nominatorAllOversubscribed, .bondedSetValidators,
                      .nominatorLowStake(LocalizableResource { _ in "low" }), .redeemUnbonded(LocalizableResource { _ in "1" }),
                      .waitingNextEra] {
            controller.didSelectStakingAlert(alert)
        }
        XCTAssertEqual(presenter.calls.filter { $0 == "changeValidators" }.count, 2)
        XCTAssertTrue(presenter.calls.contains("setupValidators"))
        XCTAssertTrue(presenter.calls.contains("bondMore"))
        XCTAssertTrue(presenter.calls.contains("redeem"))

        controller.actionAssetSelection()
        controller.actionIcon()
        XCTAssertTrue(presenter.calls.contains("asset"))
        XCTAssertTrue(presenter.calls.contains("account"))

        controller.updateWhileKeyboardFrameChanging(CGRect(x: 0, y: 500, width: 390, height: 300))
        controller.updateWhileKeyboardFrameChanging(.zero)
        XCTAssertEqual(controller.offsetFromKeyboardWithInset(10), 0)
        XCTAssertNil(controller.target)

        controller.applyLocalization()
        controller.beginAppearanceTransition(false, animated: false)
        controller.endAppearanceTransition()
        XCTAssertTrue(presenter.calls.contains("willDisappear"))
        window.isHidden = true
    }

    func testStoriesCollectionAndNetworkInfoDelegate() throws {
        let (controller, presenter, window) = makeController()
        let networkView = try XCTUnwrap(CovAViewInspector.subviews(of: NetworkInfoView.self, in: controller.view).first)
        let collection = networkView.collectionView
        try controller.didReceive(stories: XCTUnwrap(StoriesFactory().createModel(for: .relaychain)))
        let count = controller.collectionView(collection, numberOfItemsInSection: 0)
        XCTAssertGreaterThan(count, 0)
        collection.layoutIfNeeded()
        XCTAssertFalse(collection.visibleCells.isEmpty, "stories are drawn")
        controller.collectionView(collection, didSelectItemAt: IndexPath(item: 0, section: 0))
        XCTAssertEqual(presenter.calls.last, "story:0")

        networkView.actionToggleExpansion()
        controller.didChangeExpansion(isExpanded: true, view: networkView)
        controller.animateAlongsideWithInfo(view: networkView)
        XCTAssertTrue(presenter.calls.contains("expanded:true"))

        networkView.bind(viewModel: networkInfo())
        networkView.startLoading()
        networkView.stopLoadingIfNeeded()
        networkView.bind(viewModel: nil)
        networkView.bind(chainName: "Cov Relay")
        XCTAssertTrue(CovAViewInspector.contains("Cov Relay", in: networkView))

        controller.didReceive(viewModel: nil)
        XCTAssertEqual(controller.collectionView(collection, numberOfItemsInSection: 0), 0)
        window.isHidden = true
    }
}
