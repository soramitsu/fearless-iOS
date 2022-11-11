import SoraFoundation
import CommonWallet
import BigInt

protocol StakingBondMoreConfirmationViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func didReceiveConfirmation(viewModel: StakingBondMoreConfirmViewModel)
    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>)
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?)
}

protocol StakingBondMoreConfirmationPresenterProtocol: AnyObject {
    func setup()
    func confirm()
    func selectAccount()
    func didTapBackButton()
}

protocol StakingBondMoreConfirmationInteractorInputProtocol: AnyObject {
    func setup()

    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?)
    func submit(builderClosure: ExtrinsicBuilderClosure?)
}

protocol StakingBondMoreConfirmationOutputProtocol: AnyObject {
    func didReceivePriceData(result: Result<PriceData?, Error>)
}

protocol StakingBondMoreConfirmationWireframeProtocol: SheetAlertPresentable, ErrorPresentable,
    StakingErrorPresentable,
    AddressOptionsPresentable, AnyDismissable {
    func complete(from view: StakingBondMoreConfirmationViewProtocol?)
}

protocol StakingBondMoreConfirmationViewLayoutProtocol {
    var locale: Locale { get set }
}
