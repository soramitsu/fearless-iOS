import Foundation
import SoraFoundation
import CommonWallet
import BigInt

protocol StakingUnbondSetupViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>)
    func didReceiveFee(viewModel: LocalizableResource<NetworkFeeFooterViewModelProtocol>?)
    func didReceiveInput(viewModel: LocalizableResource<AmountInputViewModelProtocol>)
    func didReceiveBonding(duration: LocalizableResource<TitleWithSubtitleViewModel>)
    func didReceiveAccount(viewModel: AccountViewModel)
    func didReceiveCollator(viewModel: AccountViewModel)
    func didReceiveTitle(viewModel: LocalizableResource<String>)
    func didReceiveHints(viewModel: LocalizableResource<[TitleIconViewModel]>)
}

protocol StakingUnbondSetupPresenterProtocol: AnyObject {
    func setup()
    func selectAmountPercentage(_ percentage: Float)
    func updateAmount(_ newValue: Decimal)
    func proceed()
    func close()
    func didTapBackButton()
}

protocol StakingUnbondSetupInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?)
}

protocol StakingUnbondSetupInteractorOutputProtocol: AnyObject {
    func didReceivePriceData(result: Result<PriceData?, Error>)
}

protocol StakingUnbondSetupWireframeProtocol: SheetAlertPresentable, ErrorPresentable,
    StakingErrorPresentable, AnyDismissable {
    func close(view: StakingUnbondSetupViewProtocol?)
    func proceed(
        view: StakingUnbondSetupViewProtocol?,
        flow: StakingUnbondConfirmFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    )
}

protocol StakingUnbondSetupViewFactoryProtocol {
    static func createView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingUnbondSetupFlow
    ) -> StakingUnbondSetupViewProtocol?
}
