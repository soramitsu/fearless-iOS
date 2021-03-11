import Foundation
import SoraFoundation

// MARK: - Entity
protocol ValidatorStakeInfoProtocol {
    var nominators: [NominatorInfo] { get }
    var totalStake: Decimal { get }
    var stakeReturn: Decimal { get }
}

protocol ValidatorInfoProtocol {
    var address: String { get }
    var identity: AccountIdentity? { get }
    var stakeInfo: ValidatorStakeInfoProtocol? { get }
}

// MARK: - View
protocol ValidatorInfoViewFactoryProtocol: class {
    static func createView(with validatorInfo: ValidatorInfoProtocol) -> ValidatorInfoViewProtocol?
}

protocol ValidatorInfoViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceive(accountViewModel: ValidatorInfoAccountViewModelProtocol,
                    extrasViewModel: [ValidatorInfoViewController.Section])
}

// MARK: - Interactor
protocol ValidatorInfoInteractorInputProtocol: class {
    func setup()
}

// MARK: - Presenter
protocol ValidatorInfoInteractorOutputProtocol: class {
    func didReceive(validatorInfo: ValidatorInfoProtocol)
}

protocol ValidatorInfoPresenterProtocol: class {
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
                                         AddressOptionsPresentable { }
