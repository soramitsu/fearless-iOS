import SoraFoundation
import SSFModels

protocol StakingRewardDetailsViewProtocol: ControllerBackedProtocol, Localizable {
    func reload(with viewModel: LocalizableResource<StakingRewardDetailsViewModel>)
}

protocol StakingRewardDetailsPresenterProtocol: AnyObject {
    func setup()
    func handlePayoutAction()
    func handleValidatorAccountAction(locale: Locale)
}

protocol StakingRewardDetailsInteractorInputProtocol: AnyObject {}

protocol StakingRewardDetailsInteractorOutputProtocol: AnyObject {}

protocol StakingRewardDetailsWireframeProtocol: AnyObject, AddressOptionsPresentable {
    func showPayoutConfirmation(
        from view: ControllerBackedProtocol?,
        payoutInfo: PayoutInfo,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    )
}

protocol StakingRewardDetailsViewFactoryProtocol: AnyObject {
    static func createView(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        input: StakingRewardDetailsInput
    ) -> StakingRewardDetailsViewProtocol?
}

struct StakingRewardDetailsInput {
    let payoutInfo: PayoutInfo
    let chain: ChainModel
    let activeEra: EraIndex
    let historyDepth: UInt32
}
