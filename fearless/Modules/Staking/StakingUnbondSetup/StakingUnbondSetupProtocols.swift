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
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?)
}

protocol StakingUnbondSetupInteractorOutputProtocol: AnyObject {
    func didReceivePriceData(result: Result<PriceData?, Error>)
}

protocol StakingUnbondSetupWireframeProtocol: AlertPresentable, ErrorPresentable,
    StakingErrorPresentable {
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
