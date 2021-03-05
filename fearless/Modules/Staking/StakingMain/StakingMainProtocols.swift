import Foundation
import SoraFoundation
import CommonWallet
import BigInt

protocol StakingMainViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceive(viewModel: StakingMainViewModelProtocol)
    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>)
    func didReceiveInput(viewModel: LocalizableResource<AmountInputViewModelProtocol>)
    func didReceiveRewards(monthlyViewModel: LocalizableResource<RewardViewModelProtocol>,
                           yearlyViewModel: LocalizableResource<RewardViewModelProtocol>
    )

    func didReceive(stories: [StoryViewModelProtocol])
    func didReceiveEraInfo(viewModel: EraStakingViewModelProtocol)
}

protocol StakingMainPresenterProtocol: class {
    func setup()
    func performMainAction()
    func performAccountAction()
    func updateAmount(_ newValue: Decimal)
    func selectAmountPercentage(_ percentage: Float)
}

protocol StakingMainInteractorInputProtocol: class {
    func setup()
}

protocol StakingMainInteractorOutputProtocol: class {
    func didReceive(selectedAddress: String)
    func didReceive(price: PriceData?)
    func didReceive(balance: DyAccountData?)
    func didReceive(calculator: RewardCalculatorEngineProtocol)
    func didReceive(calculatorError: Error)
    func didReceive(error: Error)
    func didReceive(newChain: Chain)
    func didReceive(eraStakingInfo: EraStakingInfo)
    func didReceiveNomination()
    func didReceiveValidatorPrefs()
    func didReceiveStakingLedger()
    func didReceive(nominationStatus: NominationStatus)
    func didReceive(totalRewards: BigUInt?)
}

protocol StakingMainWireframeProtocol: AlertPresentable, ErrorPresentable, StakingErrorPresentable {
    func showSetupAmount(from view: StakingMainViewProtocol?)
    func showAccountSelection(from view: StakingMainViewProtocol?)
}

protocol StakingMainViewFactoryProtocol: class {
	static func createView() -> StakingMainViewProtocol?
}
