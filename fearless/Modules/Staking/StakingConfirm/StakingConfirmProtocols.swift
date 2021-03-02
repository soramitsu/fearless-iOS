import Foundation
import SoraFoundation
import BigInt

protocol StakingConfirmViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
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
    func submitNomination(controller: AccountItem,
                          amount: BigUInt,
                          rewardDestination: RewardDestination,
                          targets: [SelectedValidatorInfo])
}

protocol StakingConfirmInteractorOutputProtocol: class {
    func didReceive(price: PriceData?)
    func didReceive(priceError: Error)

    func didReceive(balance: DyAccountData?)
    func didReceive(balanceError: Error)

    func didStartNomination()
    func didCompleteNomination(txHash: String)
    func didFailNomination(error: Error)
}

protocol StakingConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
                                          AddressOptionsPresentable {
    func complete(from view: StakingConfirmViewProtocol?)
}

protocol StakingConfirmViewFactoryProtocol: class {
    static func createView(for state: PreparedNomination) -> StakingConfirmViewProtocol?
}
