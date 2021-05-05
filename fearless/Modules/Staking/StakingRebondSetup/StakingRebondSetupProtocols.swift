import Foundation
import SoraFoundation
import CommonWallet

protocol StakingRebondSetupViewProtocol: ControllerBackedProtocol, Localizable {
    // From Interactor through Presenter to View actions
    // func didReceive(value: Type)
    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>)
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?)
    func didReceiveInput(viewModel: LocalizableResource<AmountInputViewModelProtocol>)
}

protocol StakingRebondSetupPresenterProtocol: AnyObject {
    func setup()
    func selectAmountPercentage(_ percentage: Float)
    func updateAmount(_ newValue: Decimal)
    func proceed()
    func close()
}

protocol StakingRebondSetupInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee()
}

protocol StakingRebondSetupInteractorOutputProtocol: AnyObject {
    func didReceiveStakingLedger(result: Result<DyStakingLedger?, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveElectionStatus(result: Result<ElectionStatus?, Error>)
    func didReceiveActiveEra(result: Result<ActiveEraInfo?, Error>)
    func didReceiveController(result: Result<AccountItem?, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)
    func didReceiveAccountInfo(result: Result<DyAccountInfo?, Error>)
}

protocol StakingRebondSetupWireframeProtocol: AlertPresentable, ErrorPresentable,
    StakingErrorPresentable {
    func proceed(view _: StakingRebondSetupViewProtocol?, amount _: Decimal)
    func close(view: StakingRebondSetupViewProtocol?)
}

protocol StakingRebondSetupViewFactoryProtocol: AnyObject {
    // Setup view
    static func createView() -> StakingRebondSetupViewProtocol?
}
