import Foundation
import SoraFoundation

// MARK: - Entity

protocol ValidatorStakeInfoProtocol {
    var nominators: [NominatorInfo] { get }
    var totalStake: Decimal { get }
    var stakeReturn: Decimal { get }
    var maxNominatorsRewarded: UInt32 { get }
    var oversubscribed: Bool { get }
}

protocol ValidatorInfoProtocol {
    var address: String { get }
    var identity: AccountIdentity? { get }
    var stakeInfo: ValidatorStakeInfoProtocol? { get }
    var myNomination: ValidatorMyNominationStatus? { get }
}

// MARK: - View

protocol ValidatorInfoViewFactoryProtocol: AnyObject {
    static func createView(with validatorInfo: ValidatorInfoProtocol) -> ValidatorInfoViewProtocol?
}

protocol ValidatorInfoViewProtocol: ControllerBackedProtocol, Localizable {
    func didRecieve(_ viewModel: [ValidatorInfoViewModel])
}

// MARK: - Interactor

protocol ValidatorInfoInteractorInputProtocol: AnyObject {
    func setup()
}

// MARK: - Presenter

protocol ValidatorInfoInteractorOutputProtocol: AnyObject {
    func didReceive(_ validatorInfo: ValidatorInfoProtocol)
}

protocol ValidatorInfoPresenterProtocol: AnyObject {
    func setup()

    func presentAccountOptions()

    func presentTotalStake()
    func activateEmail()
    func activateWeb()
    func activateTwitter()
    func activateRiotName()
}

// MARK: - Router

protocol ValidatorInfoWireframeProtocol: WebPresentable,
    EmailPresentable,
    AlertPresentable,
    AddressOptionsPresentable {
    func showStakingAmounts(
        from view: ValidatorInfoViewProtocol?,
        items: [LocalizableResource<StakingAmountViewModel>]
    )
}
