import Foundation
import SoraFoundation
import BigInt

protocol SelectValidatorsConfirmViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func didReceive(confirmationViewModel: LocalizableResource<SelectValidatorsConfirmViewModel>)
    func didReceive(hintsViewModel: LocalizableResource<[TitleIconViewModel]>)
    func didReceive(assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>)
    func didReceive(feeViewModel: LocalizableResource<BalanceViewModelProtocol>?)
}

protocol SelectValidatorsConfirmPresenterProtocol: AnyObject {
    func setup()
    func selectWalletAccount()
    func selectPayoutAccount()
    func proceed()
}

protocol SelectValidatorsConfirmInteractorInputProtocol: AnyObject {
    func setup()
    func submitNomination()
    func estimateFee()
}

protocol SelectValidatorsConfirmInteractorOutputProtocol: AnyObject {
    func didReceiveModel(result: Result<SelectValidatorsConfirmationModel, Error>)
    func didReceivePrice(result: Result<PriceData?, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceiveMinBond(result: Result<BigUInt?, Error>)
    func didReceiveCounterForNominators(result: Result<UInt32?, Error>)
    func didReceiveMaxNominatorsCount(result: Result<UInt32?, Error>)
    func didReceiveStakingDuration(result: Result<StakingDuration, Error>)

    func didStartNomination()
    func didCompleteNomination(txHash: String)
    func didFailNomination(error: Error)

    func didReceive(paymentInfo: RuntimeDispatchInfo)
    func didReceive(feeError: Error)
}

protocol SelectValidatorsConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    AddressOptionsPresentable, StakingErrorPresentable {
    func complete(from view: SelectValidatorsConfirmViewProtocol?)
}

protocol SelectValidatorsConfirmViewFactoryProtocol: AnyObject {
    static func createInitiatedBondingView(for state: PreparedNomination<InitiatedBonding>)
        -> SelectValidatorsConfirmViewProtocol?

    static func createChangeTargetsView(for state: PreparedNomination<ExistingBonding>)
        -> SelectValidatorsConfirmViewProtocol?

    static func createChangeYourValidatorsView(for state: PreparedNomination<ExistingBonding>)
        -> SelectValidatorsConfirmViewProtocol?
}
