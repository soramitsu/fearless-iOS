import Foundation
import SoraFoundation
import BigInt
import SSFModels

protocol StakingRedeemViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func didReceiveConfirmation(viewModel: StakingRedeemViewModel)
    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>)
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?)
    func didReceiveHints(viewModel: LocalizableResource<[TitleIconViewModel]>)
}

protocol StakingRedeemPresenterProtocol: AnyObject {
    func setup()
    func confirm()
    func selectAccount()
}

protocol StakingRedeemInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?)
    func submit(builderClosure: ExtrinsicBuilderClosure?)
}

protocol StakingRedeemInteractorOutputProtocol: AnyObject {
    func didReceivePriceData(result: Result<PriceData?, Error>)
}

protocol StakingRedeemWireframeProtocol: SheetAlertPresentable, ErrorPresentable,
    StakingErrorPresentable, AddressOptionsPresentable {
    func complete(from view: StakingRedeemViewProtocol?)
}

protocol StakingRedeemViewFactoryProtocol: AnyObject {
    static func createView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingRedeemFlow,
        redeemCompletion: (() -> Void)?
    ) -> StakingRedeemViewProtocol?
}
