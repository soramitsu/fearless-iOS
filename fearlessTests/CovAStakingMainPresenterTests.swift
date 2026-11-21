import BigInt
import SoraFoundation
import SSFModels
import SSFUtils
import UIKit
import XCTest
@testable import fearless

final class CovAStakingMainViewStub: UIViewController, StakingMainViewProtocol {
    private(set) var presentedControllers: [UIViewController] = []

    override func present(_ viewControllerToPresent: UIViewController, animated _: Bool, completion: (() -> Void)? = nil) {
        presentedControllers.append(viewControllerToPresent)
        completion?()
    }

    private(set) var mainViewModels: [StakingMainViewModel?] = []
    private(set) var networkInfos: [LocalizableResource<NetworkStakingInfoViewModelProtocol>?] = []
    private(set) var states: [StakingViewState] = []
    private(set) var expansions: [Bool] = []
    private(set) var stories: [LocalizableResource<StoriesModel>] = []

    func didReceive(viewModel: StakingMainViewModel?) {
        mainViewModels.append(viewModel)
    }

    func didRecieveNetworkStakingInfo(viewModel: LocalizableResource<NetworkStakingInfoViewModelProtocol>?) {
        networkInfos.append(viewModel)
    }

    func didReceiveStakingState(viewModel: StakingViewState) {
        states.append(viewModel)
    }

    func expandNetworkInfoView(_ isExpanded: Bool) {
        expansions.append(isExpanded)
    }

    func didReceive(stakingEstimationViewModel _: StakingEstimationViewModel) {}
    func didReceive(stories: LocalizableResource<StoriesModel>) {
        self.stories.append(stories)
    }

    func applyLocalization() {}
}

final class CovAStakingMainInteractorSpy: StakingMainInteractorInputProtocol {
    private(set) var calls: [String] = []
    private(set) var savedChainAssets: [ChainAsset] = []

    func setup() {
        calls.append("setup")
    }

    func saveNetworkInfoViewExpansion(isExpanded: Bool) {
        calls.append("expand:\(isExpanded)")
    }

    func save(chainAsset: ChainAsset) {
        savedChainAssets.append(chainAsset)
    }

    func changeActiveState(_ isActive: Bool) {
        calls.append("active:\(isActive)")
    }
}

final class CovAStakingMainModuleOutputSpy: StakingMainModuleOutput {
    private(set) var switches = 0
    func didSwitchStakingType(_: AssetSelectionStakingType) {
        switches += 1
    }
}

final class CovAStakingMainWireframeStub: StakingMainWireframeProtocol {
    private(set) var events: [String] = []
    private(set) var manageItems: [[StakingManageOption]] = []
    private(set) var analyticsModes: [AnalyticsContainerViewMode] = []
    private(set) var sheets: [SheetAlertPresentableViewModel] = []

    func showSetupAmount(
        from _: StakingMainViewProtocol?, amount _: Decimal?, chain _: ChainModel, asset _: AssetModel,
        selectedAccount _: MetaAccountModel, rewardChainAsset _: ChainAsset?
    ) {
        events.append("setupAmount")
    }

    func showManageStaking(
        from _: StakingMainViewProtocol?, items: [StakingManageOption], delegate _: ModalPickerViewControllerDelegate?, context _: AnyObject?
    ) {
        manageItems.append(items)
        events.append("manage")
    }

    func proceedToSelectValidatorsStart(
        from _: StakingMainViewProtocol?, existingBonding _: ExistingBonding, chain _: ChainModel, asset _: AssetModel,
        selectedAccount _: MetaAccountModel
    ) {
        events.append("selectValidators")
    }

    func showStories(from _: ControllerBackedProtocol?, startingFrom index: Int, chainAsset _: ChainAsset) {
        events.append("stories:\(index)")
    }

    func showRewardDetails(
        from _: ControllerBackedProtocol?, maxReward _: (title: String, amount: Decimal), avgReward _: (title: String, amount: Decimal)
    ) {
        events.append("rewardDetails")
    }

    func showRewardPayoutsForNominator(
        from _: ControllerBackedProtocol?, stashAddress _: AccountAddress, chainAsset _: ChainAsset, wallet _: MetaAccountModel
    ) {
        events.append("payoutsNominator")
    }

    func showRewardPayoutsForValidator(
        from _: ControllerBackedProtocol?, stashAddress _: AccountAddress, chainAsset _: ChainAsset, wallet _: MetaAccountModel
    ) {
        events.append("payoutsValidator")
    }

    func showStakingBalance(from _: ControllerBackedProtocol?, chainAsset _: ChainAsset, wallet _: MetaAccountModel, flow _: StakingBalanceFlow) {
        events.append("balance")
    }

    func showNominatorValidators(from _: ControllerBackedProtocol?, chainAsset _: ChainAsset, wallet _: MetaAccountModel) {
        events.append("validators")
    }

    func showRewardDestination(
        from _: ControllerBackedProtocol?, chain _: ChainModel, asset _: AssetModel, selectedAccount _: MetaAccountModel,
        rewardChainAsset _: ChainAsset?
    ) {
        events.append("rewardDestination")
    }

    func showControllerAccount(from _: ControllerBackedProtocol?, chain _: ChainModel, asset _: AssetModel, selectedAccount _: MetaAccountModel) {
        events.append("controller")
    }

    func showAccountsSelection(from _: StakingMainViewProtocol?, moduleOutput _: WalletsManagmentModuleOutput) {
        events.append("accounts")
    }

    func showBondMore(from _: ControllerBackedProtocol?, chainAsset _: ChainAsset, wallet _: MetaAccountModel, flow _: StakingBondMoreFlow) {
        events.append("bondMore")
    }

    func showRedeem(from _: ControllerBackedProtocol?, chainAsset _: ChainAsset, wallet _: MetaAccountModel, flow _: StakingRedeemConfirmationFlow) {
        events.append("redeem")
    }

    func showAnalytics(
        from _: ControllerBackedProtocol?, mode: AnalyticsContainerViewMode, chainAsset _: ChainAsset, wallet _: MetaAccountModel,
        flow _: AnalyticsRewardsFlow
    ) {
        analyticsModes.append(mode)
        events.append("analytics")
    }

    func showYourValidatorInfo(
        chainAsset _: ChainAsset, selectedAccount _: MetaAccountModel, flow _: ValidatorInfoFlow, from _: ControllerBackedProtocol?
    ) {
        events.append("yourValidator")
    }

    func showChainAssetSelection(from _: StakingMainViewProtocol?, selectedChainAsset _: ChainAsset?, delegate _: AssetSelectionDelegate) {
        events.append("assetSelection")
    }

    func showCreateNewWallet(from _: ControllerBackedProtocol?) {
        events.append("createWallet")
    }

    func showImportWallet(defaultSource _: AccountImportSource, from _: ControllerBackedProtocol?) {
        events.append("importWallet")
    }

    func showBackupSelectWallet(from _: ControllerBackedProtocol?) {
        events.append("backup")
    }

    func showGetPreinstalledWallet(from _: ControllerBackedProtocol?) {
        events.append("preinstalled")
    }

    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {
        sheets.append(viewModel)
        events.append("sheet")
    }

    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        events.append("error")
        return false
    }

    func presentMissingController(from _: ControllerBackedProtocol, address _: AccountAddress, locale _: Locale?) {
        events.append("missingController")
    }

    func present(
        message _: String?, title _: String, closeAction _: String?, from _: ControllerBackedProtocol?, actions _: [SheetAlertPresentableAction]
    ) {
        events.append("message")
    }

    func presentMaxNumberOfNominatorsReached(from _: ControllerBackedProtocol?, locale _: Locale?) {
        events.append("maxNominators")
    }
}
