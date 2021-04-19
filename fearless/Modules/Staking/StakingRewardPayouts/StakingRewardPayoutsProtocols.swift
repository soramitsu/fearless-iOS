import SoraFoundation
import SoraUI

protocol StakingRewardPayoutsViewProtocol: ControllerBackedProtocol,
    Localizable,
    LoadableViewProtocol,
    EmptyStateViewOwnerProtocol {
    func showRetryState()
    func reload(with viewModel: StakingPayoutViewModel)
}

protocol StakingRewardPayoutsPresenterProtocol: AnyObject {
    func setup()
    func handleSelectedHistory(at index: Int)
    func handlePayoutAction()
}

protocol StakingRewardPayoutsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol StakingRewardPayoutsInteractorOutputProtocol: AnyObject {
    func didReceive(result: Result<PayoutsInfo, Error>)
    func didReceive(priceResult: Result<PriceData?, Error>)
}

protocol StakingRewardPayoutsWireframeProtocol: AnyObject {
    func showRewardDetails(
        from view: ControllerBackedProtocol?,
        payoutInfo: PayoutInfo,
        activeEra: EraIndex,
        chain: Chain
    )

    func showPayoutConfirmation(
        for payouts: [PayoutInfo],
        from view: ControllerBackedProtocol?
    )
}

protocol StakingRewardPayoutsViewFactoryProtocol: AnyObject {
    static func createView() -> StakingRewardPayoutsViewProtocol?
}
