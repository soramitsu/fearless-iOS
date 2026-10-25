import Foundation
import SoraFoundation
import BigInt
import SSFModels

protocol StakingRedeemConfirmationViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func didReceiveConfirmation(viewModel: StakingRedeemConfirmationViewModel)
    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>)
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?)
    func didReceiveHints(viewModel: LocalizableResource<[TitleIconViewModel]>)
}

protocol StakingRedeemConfirmationPresenterProtocol: AnyObject {
    func setup()
    func confirm()
    func selectAccount()
    func didTapBackButton()
}

protocol StakingRedeemConfirmationInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?)
    func submit(builderClosure: ExtrinsicBuilderClosure?)
}

protocol StakingRedeemConfirmationInteractorOutputProtocol: AnyObject {}

protocol StakingRedeemConfirmationWireframeProtocol: SheetAlertPresentable, ErrorPresentable,
    StakingErrorPresentable, AddressOptionsPresentable, AnyDismissable {
    func complete(from view: StakingRedeemConfirmationViewProtocol?)
}

protocol StakingRedeemConfirmationViewFactoryProtocol: AnyObject {
    static func createView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingRedeemConfirmationFlow,
        redeemCompletion: (() -> Void)?
    ) -> StakingRedeemConfirmationViewProtocol?
}
