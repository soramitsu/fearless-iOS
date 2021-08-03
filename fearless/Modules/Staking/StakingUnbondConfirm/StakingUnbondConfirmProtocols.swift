import Foundation
import SoraFoundation
import BigInt

protocol StakingUnbondConfirmViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func didReceiveConfirmation(viewModel: StakingUnbondConfirmViewModel)
    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>)
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?)
}

protocol StakingUnbondConfirmPresenterProtocol: AnyObject {
    func setup()
    func confirm()
    func selectAccount()
}

protocol StakingUnbondConfirmInteractorInputProtocol: AnyObject {
    func setup()
    func submit(for amount: Decimal, resettingRewardDestination: Bool, chilling: Bool)
    func estimateFee(for amount: Decimal, resettingRewardDestination: Bool, chilling: Bool)
}

protocol StakingUnbondConfirmInteractorOutputProtocol: AnyObject {
    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveExistentialDeposit(result: Result<BigUInt, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveController(result: Result<AccountItem?, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)
    func didReceivePayee(result: Result<RewardDestinationArg?, Error>)
    func didReceiveMinBonded(result: Result<BigUInt?, Error>)
    func didReceiveNomination(result: Result<Nomination?, Error>)

    func didSubmitUnbonding(result: Result<String, Error>)
}

protocol StakingUnbondConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    StakingErrorPresentable, AddressOptionsPresentable {
    func complete(from view: StakingUnbondConfirmViewProtocol?)
}

protocol StakingUnbondConfirmViewFactoryProtocol {
    static func createView(from amount: Decimal) -> StakingUnbondConfirmViewProtocol?
}
