import Foundation
import SoraFoundation
import CommonWallet

protocol StakingMainViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceive(viewModel: StakingMainViewModelProtocol)
    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>)
    func didReceiveInput(viewModel: LocalizableResource<AmountInputViewModelProtocol>)
    func didReceiveRewards(monthlyViewModel: LocalizableResource<RewardViewModelProtocol>,
                           yearlyViewModel: LocalizableResource<RewardViewModelProtocol>
    )
    func didReceiveChainName(chainName newChainName: LocalizableResource<String>)
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
    func didReceive(priceError: Error)
    func didReceive(balance: DyAccountData?)
    func didReceive(balanceError: Error)
    func didReceive(calculator: RewardCalculatorEngineProtocol)
    func didReceive(calculatorError: Error)
    func didReceive(stashItem: StashItem?)
    func didReceive(stashItemError: Error)
    func didReceive(ledgerInfo: DyStakingLedger?)
    func didReceive(ledgerInfoError: Error)
    func didReceive(nomination: Nomination?)
    func didReceive(nominationError: Error)
    func didReceive(validator: ValidatorPrefs?)
    func didReceive(validatorError: Error)
    func didReceive(electionStatus: ElectionStatus?)
    func didReceive(electionStatusError: Error)
    func didReceive(activeEra: ActiveEraInfo?)
    func didReceive(activeEraError: Error)
    func didReceive(newChain: Chain)
}

protocol StakingMainWireframeProtocol: AlertPresentable, ErrorPresentable, StakingErrorPresentable {
    func showSetupAmount(from view: StakingMainViewProtocol?, amount: Decimal?)
}

protocol StakingMainViewFactoryProtocol: class {
	static func createView() -> StakingMainViewProtocol?
}
