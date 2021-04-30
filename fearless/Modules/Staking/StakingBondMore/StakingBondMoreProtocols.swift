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
    func estimateFee(amount: BigUInt)
}

protocol StakingBondMoreInteractorOutputProtocol: AnyObject {
    func didReceive(price: PriceData?)
    func didReceive(balance: DyAccountData?)
    func didReceive(error: Error)
    func didReceive(paymentInfo: RuntimeDispatchInfo, for amount: BigUInt)
    func didReceive(stashItemResult: Result<StashItem?, Error>)
}

protocol StakingBondMoreWireframeProtocol: AlertPresentable, ErrorPresentable, StakingErrorPresentable {
    func showConfirmation(from view: ControllerBackedProtocol?)
    func close(view: ControllerBackedProtocol?)
}
