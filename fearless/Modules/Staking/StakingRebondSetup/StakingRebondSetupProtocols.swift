import Foundation
import SoraFoundation

import SSFModels

protocol StakingRebondSetupViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>)
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?)
    func didReceiveInput(viewModel: LocalizableResource<IAmountInputViewModel>)
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
    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveActiveEra(result: Result<ActiveEraInfo?, Error>)
    func didReceiveController(result: Result<ChainAccountResponse?, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
}

protocol StakingRebondSetupWireframeProtocol: SheetAlertPresentable, ErrorPresentable,
    StakingErrorPresentable {
    func proceed(
        view: StakingRebondSetupViewProtocol?,
        amount: Decimal,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingRebondConfirmationFlow
    )
    func close(view: StakingRebondSetupViewProtocol?)
}

protocol StakingRebondSetupViewFactoryProtocol: AnyObject {
    static func createView(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) -> StakingRebondSetupViewProtocol?
}
