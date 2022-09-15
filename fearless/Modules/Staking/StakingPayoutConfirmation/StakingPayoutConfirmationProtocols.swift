import SoraFoundation

protocol StakingPayoutConfirmationViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func didRecieve(viewModel: [LocalizableResource<PayoutConfirmViewModel>])
    func didReceive(feeViewModel: LocalizableResource<BalanceViewModelProtocol>?)
}

protocol StakingPayoutConfirmationPresenterProtocol: AnyObject {
    func setup()
    func proceed()
    func presentAccountOptions(for viewModel: AccountInfoViewModel)
}

protocol StakingPayoutConfirmationInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?)
    func submitPayout(builderClosure: ExtrinsicBuilderClosure?)
}

protocol StakingPayoutConfirmationInteractorOutputProtocol: AnyObject {
    func didReceivePriceData(result: Result<PriceData?, Error>)
}

protocol StakingPayoutConfirmationWireframeProtocol: AlertPresentable,
    ErrorPresentable,
    StakingErrorPresentable,
    AddressOptionsPresentable {
    func complete(from view: StakingPayoutConfirmationViewProtocol?)
}

protocol StakingPayoutConfirmationViewFactoryProtocol: AnyObject {
    static func createView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        payouts: [PayoutInfo],
        flow: StakingPayoutConfirmationFlow
    ) -> StakingPayoutConfirmationViewProtocol?
}
