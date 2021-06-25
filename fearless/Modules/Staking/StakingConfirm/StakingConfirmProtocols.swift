import Foundation
import SoraFoundation
import BigInt

protocol StakingConfirmViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func didReceive(confirmationViewModel: LocalizableResource<StakingConfirmViewModelProtocol>)
    func didReceive(assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>)
    func didReceive(feeViewModel: LocalizableResource<BalanceViewModelProtocol>?)
}

protocol StakingConfirmPresenterProtocol: AnyObject {
    func setup()
    func selectWalletAccount()
    func selectPayoutAccount()
    func proceed()
}

protocol StakingConfirmInteractorInputProtocol: AnyObject {
    func setup()
    func submitNomination(for lastBalance: Decimal, lastFee: Decimal)
    func estimateFee()
}

protocol StakingConfirmInteractorOutputProtocol: AnyObject {
    func didReceiveModel(result: Result<StakingConfirmationModel, Error>)
    func didReceivePrice(result: Result<PriceData?, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceiveMinBond(result: Result<BigUInt?, Error>)
    func didReceiveCounterForNominators(result: Result<UInt32?, Error>)
    func didReceiveMaxNominatorsCount(result: Result<UInt32?, Error>)

    func didStartNomination()
    func didCompleteNomination(txHash: String)
    func didFailNomination(error: Error)

    func didReceive(paymentInfo: RuntimeDispatchInfo)
    func didReceive(feeError: Error)
}

protocol StakingConfirmWireframeProtocol: AlertPresentable, ErrorPresentable, AddressOptionsPresentable,
    StakingErrorPresentable {
    func complete(from view: StakingConfirmViewProtocol?)
}

protocol StakingConfirmViewFactoryProtocol: AnyObject {
    static func createInitiatedBondingView(for state: PreparedNomination<InitiatedBonding>)
        -> StakingConfirmViewProtocol?

    static func createChangeTargetsView(for state: PreparedNomination<ExistingBonding>)
        -> StakingConfirmViewProtocol?

    static func createChangeYourValidatorsView(for state: PreparedNomination<ExistingBonding>)
        -> StakingConfirmViewProtocol?
}
