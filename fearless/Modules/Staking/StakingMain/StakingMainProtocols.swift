import Foundation
import SoraFoundation

import BigInt
import SSFModels

protocol StakingMainViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceive(viewModel: StakingMainViewModel)
    func didRecieveNetworkStakingInfo(viewModel: LocalizableResource<NetworkStakingInfoViewModelProtocol>?)
    func didReceiveStakingState(viewModel: StakingViewState)
    func expandNetworkInfoView(_ isExpanded: Bool)
    func didReceive(stakingEstimationViewModel: StakingEstimationViewModel)
    func didReceive(stories: LocalizableResource<StoriesModel>)
}

protocol StakingMainPresenterProtocol: AnyObject {
    func didTriggerViewWillAppear()
    func didTriggerViewWillDisappear()
    func setup()
    func performAssetSelection()
    func performMainAction()
    func performParachainMainAction(for delegation: ParachainStakingDelegationInfo)
    func performAccountAction()
    func performManageStakingAction()
    func performParachainManageStakingAction(for delegation: ParachainStakingDelegationInfo)
    func performNominationStatusAction()
    func performValidationStatusAction()
    func performDelegationStatusAction()
    func performRewardInfoAction()
    func performChangeValidatorsAction()
    func performSetupValidatorsForBondedAction()
    func performBondMoreAction()
    func performRedeemAction()
    func performAnalyticsAction()
    func updateAmount(_ newValue: Decimal)
    func selectAmountPercentage(_ percentage: Float)
    func selectStory(at index: Int)
    func networkInfoViewDidChangeExpansion(isExpanded: Bool)
}

protocol StakingMainInteractorInputProtocol: AnyObject {
    func setup()
    func saveNetworkInfoViewExpansion(isExpanded: Bool)
    func save(chainAsset: ChainAsset)
    func changeActiveState(_ isActive: Bool)
}

protocol StakingMainInteractorOutputProtocol: AnyObject {
    func didReceive(selectedWallet: MetaAccountModel)
    func didReceive(selectedAddress: String)
    func didReceive(totalReward: TotalRewardItem)
    func didReceive(totalReward: Error)
    func didReceive(accountInfo: AccountInfo?)
    func didReceive(balanceError: Error)
    func didReceive(calculator: RewardCalculatorEngineProtocol)
    func didReceive(calculatorError: Error)
    func didReceive(stashItem: StashItem?)
    func didReceive(stashItemError: Error)
    func didReceive(ledgerInfo: StakingLedger?)
    func didReceive(ledgerInfoError: Error)
    func didReceive(nomination: Nomination?)
    func didReceive(nominationError: Error)
    func didReceive(validatorPrefs: ValidatorPrefs?)
    func didReceive(validatorError: Error)
    func didReceive(eraStakersInfo: EraStakersInfo)
    func didReceive(eraStakersInfoError: Error)
    func didReceive(networkStakingInfo: NetworkStakingInfo)
    func didReceive(networkStakingInfoError: Error)
    func didReceive(payee: RewardDestinationArg?)
    func didReceive(payeeError: Error)
    func didReceive(newChainAsset: ChainAsset)
    func didReceieve(subqueryRewards: Result<[SubqueryRewardItemData]?, Error>, period: AnalyticsPeriod)
    func didReceiveMinNominatorBond(result: Result<BigUInt?, Error>)
    func didReceiveCounterForNominators(result: Result<UInt32?, Error>)
    func didReceiveMaxNominatorsCount(result: Result<UInt32?, Error>)
    func didReceive(eraCountdownResult: Result<EraCountdown, Error>)
    func didReceive(rewardChainAsset: ChainAsset?)

    func didReceiveMaxNominatorsPerValidator(_ maxNominatorsPerValidator: UInt32?)

    func didReceiveControllerAccount(result: Result<ChainAccountResponse?, Error>)
    func networkInfoViewExpansion(isExpanded: Bool)

//    Parachain

    func didReceive(delegationInfos: [ParachainStakingDelegationInfo]?)
    func didReceiveRound(round: ParachainStakingRoundInfo?)
    func didReceiveCurrentBlock(currentBlock: UInt32?)
    func didReceiveScheduledRequests(requests: [AccountAddress: [ParachainStakingScheduledRequest]]?)
    func didReceiveTopDelegations(delegations: [AccountAddress: ParachainStakingDelegations]?)
    func didReceiveBottomDelegations(delegations: [AccountAddress: ParachainStakingDelegations]?)
}

protocol StakingMainWireframeProtocol: SheetAlertPresentable, ErrorPresentable, StakingErrorPresentable, AccountManagementPresentable {
    func showSetupAmount(
        from view: StakingMainViewProtocol?,
        amount: Decimal?,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        rewardChainAsset: ChainAsset?
    )

    func showManageStaking(
        from view: StakingMainViewProtocol?,
        items: [StakingManageOption],
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    )

    func proceedToSelectValidatorsStart(
        from view: StakingMainViewProtocol?,
        existingBonding: ExistingBonding,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    )

    func showStories(
        from view: ControllerBackedProtocol?,
        startingFrom index: Int,
        chainAsset: ChainAsset
    )

    func showRewardDetails(
        from view: ControllerBackedProtocol?,
        maxReward: (title: String, amount: Decimal),
        avgReward: (title: String, amount: Decimal)
    )

    func showRewardPayoutsForNominator(
        from view: ControllerBackedProtocol?,
        stashAddress: AccountAddress,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    )

    func showRewardPayoutsForValidator(
        from view: ControllerBackedProtocol?,
        stashAddress: AccountAddress,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    )

    func showStakingBalance(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingBalanceFlow
    )

    func showNominatorValidators(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    )

    func showRewardDestination(
        from view: ControllerBackedProtocol?,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        rewardChainAsset: ChainAsset?
    )

    func showControllerAccount(
        from view: ControllerBackedProtocol?,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    )

    func showAccountsSelection(
        from view: StakingMainViewProtocol?,
        moduleOutput: WalletsManagmentModuleOutput
    )

    func showBondMore(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingBondMoreFlow
    )

    func showRedeem(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingRedeemConfirmationFlow
    )

    func showAnalytics(
        from view: ControllerBackedProtocol?,
        mode: AnalyticsContainerViewMode,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: AnalyticsRewardsFlow
    )

    func showYourValidatorInfo(
        chainAsset: ChainAsset,
        selectedAccount: MetaAccountModel,
        flow: ValidatorInfoFlow,
        from view: ControllerBackedProtocol?
    )

    func showChainAssetSelection(
        from view: StakingMainViewProtocol?,
        selectedChainAsset: ChainAsset?,
        delegate: AssetSelectionDelegate
    )
}

protocol StakingMainViewFactoryProtocol: AnyObject {
    static func createView(moduleOutput: StakingMainModuleOutput?) -> StakingMainViewProtocol?
}

protocol StakingMainModuleOutput: AnyObject {
    func didSwitchStakingType(_ type: AssetSelectionStakingType)
}
