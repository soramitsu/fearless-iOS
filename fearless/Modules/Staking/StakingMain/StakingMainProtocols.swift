import Foundation
import SoraFoundation
import CommonWallet

protocol StakingMainViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceive(viewModel: StakingMainViewModelProtocol)
    func didReceiveChainName(chainName newChainName: LocalizableResource<String>)
    func didRecieveNetworkStakingInfo(viewModel: LocalizableResource<NetworkStakingInfoViewModelProtocol>)

    func didReceiveStakingState(viewModel: StakingViewState)
}

protocol StakingMainPresenterProtocol: class {
    func setup()
    func performMainAction()
    func performAccountAction()
    func updateAmount(_ newValue: Decimal)
    func selectAmountPercentage(_ percentage: Float)
    func selectStory(at index: Int)
}

protocol StakingMainInteractorInputProtocol: class {
    func setup()
}

protocol StakingMainInteractorOutputProtocol: class {
    func didReceive(selectedAddress: String)
    func didReceive(price: PriceData?)
    func didReceive(priceError: Error)
    func didReceive(totalReward: TotalRewardItem)
    func didReceive(totalReward: Error)
    func didReceive(accountInfo: DyAccountInfo?)
    func didReceive(balanceError: Error)
    func didReceive(calculator: RewardCalculatorEngineProtocol)
    func didReceive(calculatorError: Error)
    func didReceive(stashItem: StashItem?)
    func didReceive(stashItemError: Error)
    func didReceive(ledgerInfo: DyStakingLedger?)
    func didReceive(ledgerInfoError: Error)
    func didReceive(nomination: Nomination?)
    func didReceive(nominationError: Error)
    func didReceive(validatorPrefs: ValidatorPrefs?)
    func didReceive(validatorError: Error)
    func didReceive(electionStatus: ElectionStatus?)
    func didReceive(electionStatusError: Error)
    func didReceive(eraStakersInfo: EraStakersInfo)
    func didReceive(eraStakersInfoError: Error)
    func didReceive(networkStakingInfo: NetworkStakingInfo)
    func didReceive(networkStakingInfoError: Error)
    func didReceive(newChain: Chain)
}

protocol StakingMainWireframeProtocol: AlertPresentable, ErrorPresentable, StakingErrorPresentable {
    func showSetupAmount(from view: StakingMainViewProtocol?, amount: Decimal?)
    func showStories(from view: StakingMainViewProtocol?, startingFrom index: Int)
}

protocol StakingMainViewFactoryProtocol: class {
	static func createView() -> StakingMainViewProtocol?
}
