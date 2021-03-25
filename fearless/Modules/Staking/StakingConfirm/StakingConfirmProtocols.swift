import Foundation
import SoraFoundation
import BigInt

protocol StakingConfirmViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func didReceive(confirmationViewModel: LocalizableResource<StakingConfirmViewModelProtocol>)
    func didReceive(assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>)
    func didReceive(feeViewModel: LocalizableResource<BalanceViewModelProtocol>?)
}

protocol StakingConfirmPresenterProtocol: class {
    func setup()
    func selectWalletAccount()
    func selectPayoutAccount()
    func selectValidators()
    func proceed()
}

protocol StakingConfirmInteractorInputProtocol: class {
    func setup()
    func submitNomination()
    func estimateFee()
}

protocol StakingConfirmInteractorOutputProtocol: class {
    func didReceive(model: StakingConfirmationModel)

    func didReceive(price: PriceData?)
    func didReceive(priceError: Error)

    func didReceive(balance: DyAccountData?)
    func didReceive(balanceError: Error)

    func didStartNomination()
    func didCompleteNomination(txHash: String)
    func didFailNomination(error: Error)

    func didReceive(paymentInfo: RuntimeDispatchInfo)
    func didReceive(feeError: Error)
}

protocol StakingConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
                                          AddressOptionsPresentable, StakingErrorPresentable {
    func showSelectedValidator(from view: StakingConfirmViewProtocol?,
                               validators: [SelectedValidatorInfo],
                               maxTargets: Int)
    func complete(from view: StakingConfirmViewProtocol?)
}

protocol StakingConfirmViewFactoryProtocol: class {
    static func createInitiatedBondingView(for state: PreparedNomination<InitiatedBonding>)
    -> StakingConfirmViewProtocol?

    static func createChangeTargetsView(for state: PreparedNomination<ExistingBonding>)
    -> StakingConfirmViewProtocol?
}
