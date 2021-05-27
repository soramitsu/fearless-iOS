import Foundation
import CommonWallet
import BigInt
import SoraFoundation

protocol CrowdloanContributionSetupViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceiveAsset(viewModel: AssetBalanceViewModelProtocol)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveInput(viewModel: AmountInputViewModelProtocol)
    func didReceiveCrowdloan(viewModel: CrowdloanContributionViewModel)
    func didReceiveEstimatedReward(viewModel: String?)
}

protocol CrowdloanContributionSetupPresenterProtocol: AnyObject {
    func setup()
    func selectAmountPercentage(_ percentage: Float)
    func updateAmount(_ newValue: Decimal)
    func proceed()
}

protocol CrowdloanContributionSetupInteractorInputProtocol: CrowdloanContributionInteractorInputProtocol {}

protocol CrowdloanContributionSetupInteractorOutputProtocol: CrowdloanContributionInteractorOutputProtocol {}

protocol CrowdloanContributionSetupWireframeProtocol: AlertPresentable, ErrorPresentable,
    CrowdloanErrorPresentable {
    func showConfirmation(from view: CrowdloanContributionSetupViewProtocol?, paraId: ParaId, inputAmount: Decimal)
}
