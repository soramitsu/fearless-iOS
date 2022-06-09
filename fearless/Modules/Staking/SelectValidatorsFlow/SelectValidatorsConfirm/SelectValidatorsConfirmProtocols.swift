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
    func submitNomination(closure: ExtrinsicBuilderClosure?)
    func estimateFee(closure: ExtrinsicBuilderClosure?)
}

protocol SelectValidatorsConfirmInteractorOutputProtocol: AnyObject {
    func didReceivePrice(result: Result<PriceData?, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
}

protocol SelectValidatorsConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    AddressOptionsPresentable, StakingErrorPresentable {
    func complete(from view: SelectValidatorsConfirmViewProtocol?)
}

protocol SelectValidatorsConfirmViewFactoryProtocol: AnyObject {
    static func createInitiatedBondingView(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        flow: SelectValidatorsConfirmFlow
    ) -> SelectValidatorsConfirmViewProtocol?

    static func createChangeTargetsView(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        flow: SelectValidatorsConfirmFlow
    ) -> SelectValidatorsConfirmViewProtocol?

    static func createChangeYourValidatorsView(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        flow: SelectValidatorsConfirmFlow
    ) -> SelectValidatorsConfirmViewProtocol?
}
