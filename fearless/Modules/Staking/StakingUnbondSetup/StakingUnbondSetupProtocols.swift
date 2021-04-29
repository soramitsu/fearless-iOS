import Foundation
import SoraFoundation
import CommonWallet

protocol StakingUnbondSetupViewProtocol: ControllerBackedProtocol {
    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>)
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?)
    func didReceiveInput(viewModel: LocalizableResource<AmountInputViewModelProtocol>)
    func didReceiveBonding(duration: LocalizableResource<String>)
}

protocol StakingUnbondSetupPresenterProtocol: AnyObject {
    func setup()
    func selectAmountPercentage(_ percentage: Float)
    func updateAmount(_ newValue: Decimal)
    func proceed()
    func close()
}

protocol StakingUnbondSetupInteractorInputProtocol: AnyObject {}

protocol StakingUnbondSetupInteractorOutputProtocol: AnyObject {}

protocol StakingUnbondSetupWireframeProtocol: AnyObject {
    func close(view: StakingUnbondSetupViewProtocol?)
}

protocol StakingUnbondSetupViewFactoryProtocol: AnyObject {
    static func createView() -> StakingUnbondSetupViewProtocol?
}
