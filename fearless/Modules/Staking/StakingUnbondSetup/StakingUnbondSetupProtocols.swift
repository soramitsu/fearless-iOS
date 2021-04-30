import Foundation
import SoraFoundation
import CommonWallet
import BigInt

protocol StakingUnbondSetupViewProtocol: ControllerBackedProtocol {
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
}

protocol StakingUnbondSetupInteractorOutputProtocol: AnyObject {
    func didReceiveStakingLedger(result: Result<DyStakingLedger?, Error>)
    func didReceiveAccountInfo(result: Result<DyAccountInfo?, Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveBondingDuration(result: Result<UInt32, Error>)
    func didReceiveExistentialDeposit(result: Result<BigUInt, Error>)
}

protocol StakingUnbondSetupWireframeProtocol: AnyObject {
    func close(view: StakingUnbondSetupViewProtocol?)
}

protocol StakingUnbondSetupViewFactoryProtocol: AnyObject {
    static func createView() -> StakingUnbondSetupViewProtocol?
}
