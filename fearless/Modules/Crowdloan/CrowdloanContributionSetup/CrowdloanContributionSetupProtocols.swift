import Foundation
import CommonWallet
import BigInt
import SoraFoundation

protocol CrowdloanContributionSetupViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceiveAsset(viewModel: AssetBalanceViewModelProtocol)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveInput(viewModel: AmountInputViewModelProtocol?)
    func didReceiveEthereumAddress(viewModel: InputViewModelProtocol)
    func didReceiveCrowdloan(viewModel: CrowdloanContributionSetupViewModel)
    func didReceiveEstimatedReward(viewModel: String?)
    func didReceiveBonus(viewModel: String?)
    func didReceiveCustomCrowdloanFlow(viewModel: CustomCrowdloanFlow?)
}

protocol CrowdloanContributionSetupPresenterProtocol: AnyObject {
    func setup()
    func selectAmountPercentage(_ percentage: Float)
    func updateAmount(_ newValue: Decimal)
    func updateEthereumAddress(_ newValue: String)
    func proceed()
    func presentLearnMore()
    func presentAdditionalBonuses()
}

protocol CrowdloanContributionSetupInteractorInputProtocol: CrowdloanContributionInteractorInputProtocol {}

protocol CrowdloanContributionSetupInteractorOutputProtocol: CrowdloanContributionInteractorOutputProtocol {}

protocol CrowdloanContributionSetupWireframeProtocol: AlertPresentable, ErrorPresentable,
    CrowdloanErrorPresentable, WebPresentable {
    func showConfirmation(
        from view: CrowdloanContributionSetupViewProtocol?,
        paraId: ParaId,
        inputAmount: Decimal?,
        bonusService: CrowdloanBonusServiceProtocol?,
        customFlow: CustomCrowdloanFlow?,
        ethereumAddress: String?
    )

    func showAdditionalBonus(
        from view: CrowdloanContributionSetupViewProtocol?,
        for displayInfo: CrowdloanDisplayInfo,
        inputAmount: Decimal,
        delegate: CustomCrowdloanDelegate,
        existingService: CrowdloanBonusServiceProtocol?
    )
}
