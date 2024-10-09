import Foundation
import SoraFoundation
import BigInt

import SSFModels

protocol StakingAmountViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func didReceive(viewModel: StakingAmountMainViewModel)

    func didReceiveYourRewardDestination(viewModel: LocalizableResource<YourRewardDestinationViewModel>)
    func didReceiveRewardDestination(viewModel: LocalizableResource<RewardDestinationViewModelProtocol>)
    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>)
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?)
    func didReceiveInput(viewModel: LocalizableResource<IAmountInputViewModel>)
}

protocol StakingAmountPresenterProtocol: AnyObject {
    func setup()
    func selectRestakeDestination()
    func selectPayoutDestination()
    func selectAmountPercentage(_ percentage: Float)
    func selectPayoutAccount()
    func updateAmount(_ newValue: Decimal)
    func selectLearnMore()
    func proceed()
    func close()
}

protocol StakingAmountInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(extrinsicBuilderClosure: @escaping ExtrinsicBuilderClosure)
    func fetchAccounts()
}

protocol StakingAmountInteractorOutputProtocol: AnyObject {
    func didReceive(accounts: [ChainAccountResponse])
    func didReceive(balance: AccountData?)
    func didReceive(error: Error)
    func didReceive(calculator: RewardCalculatorEngineProtocol)
    func didReceive(calculatorError: Error)
}

protocol StakingAmountWireframeProtocol: SheetAlertPresentable, ErrorPresentable, WebPresentable,
    StakingErrorPresentable, AddressOptionsPresentable {
    func presentAccountSelection(
        _ accounts: [ChainAccountResponse],
        selectedAccountItem: ChainAccountResponse,
        delegate: ModalPickerViewControllerDelegate,
        from view: StakingAmountViewProtocol?,
        context: AnyObject?
    )

    func proceed(
        from view: StakingAmountViewProtocol?,
        state: InitiatedBonding,
        asset: AssetModel,
        chain: ChainModel,
        selectedAccount: MetaAccountModel
    )

    func close(view: StakingAmountViewProtocol?)
}

protocol StakingAmountViewFactoryProtocol: AnyObject {
    static func createView(
        with amount: Decimal?,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        rewardChainAsset: ChainAsset?
    ) -> StakingAmountViewProtocol?
}
