import SoraFoundation
import SoraUI
import SSFModels

protocol StakingRewardPayoutsViewProtocol: ControllerBackedProtocol,
    Localizable,
    LoadableViewProtocol {
    func reload(with state: StakingRewardPayoutsViewState)
}

enum StakingRewardPayoutsViewState {
    case loading(Bool)
    case payoutsList(LocalizableResource<StakingPayoutViewModel>)
    case emptyList
    case error(LocalizableResource<String>)
}

protocol StakingRewardPayoutsPresenterProtocol: AnyObject {
    func setup()
    func handleSelectedHistory(at index: Int)
    func handlePayoutAction()
    func reload()
    func getTimeLeftString(at index: Int) -> LocalizableResource<NSAttributedString>?
}

protocol StakingRewardPayoutsInteractorInputProtocol: AnyObject {
    func setup()
    func reload()
}

protocol StakingRewardPayoutsInteractorOutputProtocol: AnyObject {
    func didReceive(result: Result<PayoutsInfo, PayoutRewardsServiceError>)
    func didReceive(priceResult: Result<PriceData?, Error>)
    func didReceive(eraCountdownResult: Result<EraCountdown, Error>)
}

protocol StakingRewardPayoutsWireframeProtocol: AnyObject {
    func showRewardDetails(
        from view: ControllerBackedProtocol?,
        payoutInfo: PayoutInfo,
        activeEra: EraIndex,
        historyDepth: UInt32,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    )
    func showPayoutConfirmation(
        for payouts: [PayoutInfo],
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    )
}

protocol StakingRewardPayoutsViewFactoryProtocol: AnyObject {
    static func createViewForNominator(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        stashAddress: AccountAddress
    ) -> StakingRewardPayoutsViewProtocol?
    static func createViewForValidator(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        stashAddress: AccountAddress
    ) -> StakingRewardPayoutsViewProtocol?
}

protocol StakingPayoutViewModelFactoryProtocol {
    func createPayoutsViewModel(
        payoutsInfo: PayoutsInfo,
        priceData: PriceData?,
        eraCountdown: EraCountdown?,
        erasPerDay: UInt32
    ) -> LocalizableResource<StakingPayoutViewModel>

    func timeLeftString(
        at index: Int,
        payoutsInfo: PayoutsInfo,
        eraCountdown: EraCountdown?,
        erasPerDay: UInt32
    ) -> LocalizableResource<NSAttributedString>
}
