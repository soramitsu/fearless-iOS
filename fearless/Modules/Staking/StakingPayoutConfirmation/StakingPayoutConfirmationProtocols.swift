import SoraFoundation
import SSFModels

protocol StakingPayoutConfirmationViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func didRecieve(viewModel: [LocalizableResource<PayoutConfirmViewModel>])
    func didReceive(feeViewModel: LocalizableResource<BalanceViewModelProtocol>?)
    func didReceive(singleViewModel: StakingPayoutConfirmationViewModel?)
}

protocol StakingPayoutConfirmationPresenterProtocol: AnyObject {
    func setup()
    func proceed()
    func presentAccountOptions(for viewModel: AccountInfoViewModel)
    func didTapBackButton()
}

protocol StakingPayoutConfirmationInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?)
    func submitPayout(builderClosure: ExtrinsicBuilderClosure?)
}

protocol StakingPayoutConfirmationInteractorOutputProtocol: AnyObject {}

protocol StakingPayoutConfirmationWireframeProtocol: SheetAlertPresentable,
    ErrorPresentable,
    StakingErrorPresentable,
    AddressOptionsPresentable, AnyDismissable {
    func complete(from view: StakingPayoutConfirmationViewProtocol?)
}

protocol StakingPayoutConfirmationViewFactoryProtocol: AnyObject {
    static func createView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingPayoutConfirmationFlow
    ) -> StakingPayoutConfirmationViewProtocol?
}
