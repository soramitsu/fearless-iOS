import Foundation
import SoraFoundation
import SSFModels

// MARK: - Entity

protocol ValidatorStakeInfoProtocol {
    var nominators: [NominatorInfo] { get }
    var totalStake: Decimal { get }
    var ownStake: Decimal { get }
    var stakeReturn: Decimal { get }
    var maxNominatorsRewarded: UInt32 { get }
    var oversubscribed: Bool { get }
}

protocol ValidatorInfoProtocol {
    var address: String { get }
    var identity: AccountIdentity? { get }
    var stakeInfo: ValidatorStakeInfoProtocol? { get }
    var myNomination: ValidatorMyNominationStatus? { get }
    var totalStake: Decimal { get }
    var ownStake: Decimal { get }
    var hasSlashes: Bool { get }
    var blocked: Bool { get }
    var commission: Decimal { get }
    var elected: Bool { get }
}

// MARK: - View

protocol ValidatorInfoViewFactoryProtocol: AnyObject {
    static func createView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: ValidatorInfoFlow
    ) -> ValidatorInfoViewProtocol?
}

protocol ValidatorInfoViewProtocol: ControllerBackedProtocol, Localizable {
    func didRecieve(state: ValidatorInfoState)
}

// MARK: - Interactor

protocol ValidatorInfoInteractorInputProtocol: AnyObject {
    func setup()
    func reload()
}

// MARK: - Presenter

protocol ValidatorInfoInteractorOutputProtocol: AnyObject {
    func didReceivePriceData(result: Result<PriceData?, Error>)
}

protocol ValidatorInfoPresenterProtocol: AnyObject {
    func setup()
    func reload()

    func presentAccountOptions()
    func presentTotalStake()
    func presentIdentityItem(_ value: ValidatorInfoViewModel.IdentityItemValue)
}

// MARK: - Router

protocol ValidatorInfoWireframeProtocol: WebPresentable,
    EmailPresentable,
    SheetAlertPresentable,
    AddressOptionsPresentable,
    ErrorPresentable {
    func showStakingAmounts(
        from view: ValidatorInfoViewProtocol?,
        items: [LocalizableResource<StakingAmountViewModel>]
    )
}
