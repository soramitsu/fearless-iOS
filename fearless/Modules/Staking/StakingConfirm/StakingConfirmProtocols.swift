import Foundation
import SoraFoundation

protocol StakingConfirmViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceive(confirmationViewModel: LocalizableResource<StakingConfirmViewModelProtocol>)
    func didReceive(assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>)
    func didReceive(feeViewModel: LocalizableResource<BalanceViewModelProtocol>)
}

protocol StakingConfirmPresenterProtocol: class {
    func setup()
    func selectWalletAccount()
    func selectPayoutAccount()
    func proceed()
}

protocol StakingConfirmInteractorInputProtocol: class {
    func setup()
}

protocol StakingConfirmInteractorOutputProtocol: class {
    func didReceive(price: PriceData?)
    func didReceive(balance: DyAccountData?)
    func didReceive(error: Error)
}

protocol StakingConfirmWireframeProtocol: AlertPresentable, ErrorPresentable {}

protocol StakingConfirmViewFactoryProtocol: class {
    static func createView(for state: PreparedNomination) -> StakingConfirmViewProtocol?
}
