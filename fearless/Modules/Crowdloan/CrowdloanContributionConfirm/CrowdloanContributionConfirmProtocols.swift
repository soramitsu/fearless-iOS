import SoraFoundation
import BigInt

protocol CrowdloanContributionConfirmViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func didReceiveAsset(viewModel: AssetBalanceViewModelProtocol)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveCrowdloan(viewModel: CrowdloanContributeConfirmViewModel)
    func didReceiveEstimatedReward(viewModel: String?)
    func didReceiveBonus(viewModel: String?)
}

protocol CrowdloanContributionConfirmPresenterProtocol: AnyObject {
    func setup()
    func confirm()
    func presentAccountOptions()
}

protocol CrowdloanContributionConfirmInteractorInputProtocol: CrowdloanContributionInteractorInputProtocol {
    func submit(contribution: BigUInt)
}

protocol CrowdloanContributionConfirmInteractorOutputProtocol: CrowdloanContributionInteractorOutputProtocol {
    func didSubmitContribution(result: Result<String, Error>)
    func didReceiveDisplayAddress(result: Result<DisplayAddress, Error>)
}

protocol CrowdloanContributionConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    CrowdloanErrorPresentable, AddressOptionsPresentable {
    func complete(on view: CrowdloanContributionConfirmViewProtocol?)
}
