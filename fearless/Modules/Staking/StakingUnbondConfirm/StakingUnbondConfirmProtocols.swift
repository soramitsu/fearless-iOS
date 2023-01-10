import Foundation
import SoraFoundation
import BigInt

protocol StakingUnbondConfirmViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func didReceiveConfirmation(viewModel: StakingUnbondConfirmViewModel)
    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>)
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?)
    func didReceiveBonding(duration: LocalizableResource<TitleWithSubtitleViewModel>)
}

protocol StakingUnbondConfirmPresenterProtocol: AnyObject {
    func setup()
    func confirm()
    func selectAccount()
    func didTapBackButton()
}

protocol StakingUnbondConfirmInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?)
    func submit(builderClosure: ExtrinsicBuilderClosure?)
}

protocol StakingUnbondConfirmInteractorOutputProtocol: AnyObject {
    func didReceivePriceData(result: Result<PriceData?, Error>)
}

protocol StakingUnbondConfirmWireframeProtocol: SheetAlertPresentable, ErrorPresentable,
    StakingErrorPresentable, AddressOptionsPresentable, AnyDismissable {
    func complete(
        on view: ControllerBackedProtocol?,
        hash: String,
        chainAsset: ChainAsset
    )
}

protocol StakingUnbondConfirmViewFactoryProtocol {
    static func createView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingUnbondConfirmFlow
    ) -> StakingUnbondConfirmViewProtocol?
}
