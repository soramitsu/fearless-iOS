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
    func selectCollatorAccount()
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

protocol SelectValidatorsConfirmWireframeProtocol: SheetAlertPresentable, ErrorPresentable,
    AddressOptionsPresentable, StakingErrorPresentable {
    func complete(chainAsset: ChainAsset, txHash: String, from view: SelectValidatorsConfirmViewProtocol?)
}

protocol SelectValidatorsConfirmViewFactoryProtocol: AnyObject {
    static func createView(
        chainAsset: ChainAsset,
        flow: SelectValidatorsConfirmFlow,
        wallet: MetaAccountModel
    ) -> SelectValidatorsConfirmViewProtocol?
}
