import Foundation
import SoraFoundation

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
}

// MARK: - View

protocol ValidatorInfoViewFactoryProtocol: AnyObject {
    static func createView(with validatorInfo: ValidatorInfoProtocol) -> ValidatorInfoViewProtocol?
    static func createView(with validatorAccountAddress: AccountAddress) -> ValidatorInfoViewProtocol?
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
    func didStartLoadingValidatorInfo()
    func didReceiveValidatorInfo(result: Result<ValidatorInfoProtocol?, Error>)
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
    AlertPresentable,
    AddressOptionsPresentable,
    ErrorPresentable {
    func showStakingAmounts(
        from view: ValidatorInfoViewProtocol?,
        items: [LocalizableResource<StakingAmountViewModel>]
    )
}
