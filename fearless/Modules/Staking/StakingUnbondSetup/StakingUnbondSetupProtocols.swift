import Foundation
import SoraFoundation
import CommonWallet
import BigInt

protocol StakingUnbondSetupViewProtocol: ControllerBackedProtocol, Localizable {
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

protocol StakingUnbondSetupInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee()
}

protocol StakingUnbondSetupInteractorOutputProtocol: AnyObject {
    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveBondingDuration(result: Result<UInt32, Error>)
    func didReceiveExistentialDeposit(result: Result<BigUInt, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveController(result: Result<AccountItem?, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)
}

protocol StakingUnbondSetupWireframeProtocol: AlertPresentable, ErrorPresentable,
    StakingErrorPresentable {
    func close(view: StakingUnbondSetupViewProtocol?)
    func proceed(view: StakingUnbondSetupViewProtocol?, amount: Decimal)
}

protocol StakingUnbondSetupViewFactoryProtocol {
    static func createView() -> StakingUnbondSetupViewProtocol?
}
