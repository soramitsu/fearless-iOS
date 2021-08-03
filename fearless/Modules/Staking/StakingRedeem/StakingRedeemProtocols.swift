import Foundation
import SoraFoundation
import BigInt

protocol StakingRedeemViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func didReceiveConfirmation(viewModel: StakingRedeemViewModel)
    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>)
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?)
}

protocol StakingRedeemPresenterProtocol: AnyObject {
    func setup()
    func confirm()
    func selectAccount()
}

protocol StakingRedeemInteractorInputProtocol: AnyObject {
    func setup()
    func submitForStash(_ stashAddress: AccountAddress)
    func estimateFeeForStash(_ stashAddress: AccountAddress)
}

protocol StakingRedeemInteractorOutputProtocol: AnyObject {
    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveExistentialDeposit(result: Result<BigUInt, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveController(result: Result<AccountItem?, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)
    func didReceiveActiveEra(result: Result<ActiveEraInfo?, Error>)

    func didSubmitRedeeming(result: Result<String, Error>)
}

protocol StakingRedeemWireframeProtocol: AlertPresentable, ErrorPresentable,
    StakingErrorPresentable, AddressOptionsPresentable {
    func complete(from view: StakingRedeemViewProtocol?)
}

protocol StakingRedeemViewFactoryProtocol: AnyObject {
    static func createView() -> StakingRedeemViewProtocol?
}
