import Foundation
import SoraFoundation

protocol AccountStatisticsViewInput: ControllerBackedProtocol {}

protocol AccountStatisticsInteractorInput: AnyObject {
    func setup(with output: AccountStatisticsInteractorOutput)
}

final class AccountStatisticsPresenter {
    // MARK: Private properties

    private weak var view: AccountStatisticsViewInput?
    private let router: AccountStatisticsRouterInput
    private let interactor: AccountStatisticsInteractorInput

    // MARK: - Constructors

    init(
        interactor: AccountStatisticsInteractorInput,
        router: AccountStatisticsRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - AccountStatisticsViewOutput

extension AccountStatisticsPresenter: AccountStatisticsViewOutput {
    func didLoad(view: AccountStatisticsViewInput) {
        self.view = view
        interactor.setup(with: self)
    }
}

// MARK: - AccountStatisticsInteractorOutput

extension AccountStatisticsPresenter: AccountStatisticsInteractorOutput {}

// MARK: - Localizable

extension AccountStatisticsPresenter: Localizable {
    func applyLocalization() {}
}

extension AccountStatisticsPresenter: AccountStatisticsModuleInput {}
