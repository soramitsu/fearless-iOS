import Foundation
import SoraFoundation
import BigInt
import SSFModels

protocol StakingRebondConfirmationViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func didReceiveConfirmation(viewModel: StakingRebondConfirmationViewModel)
    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>)
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?)
}

protocol StakingRebondConfirmationPresenterProtocol: AnyObject {
    func setup()
    func confirm()
    func selectAccount()
}

protocol StakingRebondConfirmationInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?)
    func submit(builderClosure: ExtrinsicBuilderClosure?)
}

protocol StakingRebondConfirmationInteractorOutputProtocol: AnyObject {}

protocol StakingRebondConfirmationWireframeProtocol: SheetAlertPresentable, ErrorPresentable,
    StakingErrorPresentable, AddressOptionsPresentable {
    func complete(from view: StakingRebondConfirmationViewProtocol?)
}
