import SoraFoundation
import CommonWallet
import BigInt

protocol StakingBondMoreViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceiveInput(viewModel: LocalizableResource<AmountInputViewModelProtocol>)
    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>)
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?)
}

protocol StakingBondMorePresenterProtocol: AnyObject {
    func setup()
    func handleContinueAction()
    func updateAmount(_ newValue: Decimal)
    func selectAmountPercentage(_ percentage: Float)
}

protocol StakingBondMoreInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee()
}

protocol StakingBondMoreInteractorOutputProtocol: AnyObject {
    func didReceiveElectionStatus(result: Result<ElectionStatus?, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveStash(result: Result<AccountItem?, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)
}

protocol StakingBondMoreWireframeProtocol: AlertPresentable, ErrorPresentable, StakingErrorPresentable {
    func showConfirmation(from view: ControllerBackedProtocol?, amount: Decimal)
    func close(view: ControllerBackedProtocol?)
}
