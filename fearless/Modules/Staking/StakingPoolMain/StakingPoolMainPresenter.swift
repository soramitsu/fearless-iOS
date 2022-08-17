import Foundation
import SoraFoundation

final class StakingPoolMainPresenter {
    // MARK: Private properties

    private weak var view: StakingPoolMainViewInput?
    private let router: StakingPoolMainRouterInput
    private let interactor: StakingPoolMainInteractorInput

    // MARK: - Constructors

    init(
        interactor: StakingPoolMainInteractorInput,
        router: StakingPoolMainRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - StakingPoolMainViewOutput

extension StakingPoolMainPresenter: StakingPoolMainViewOutput {
    func didLoad(view: StakingPoolMainViewInput) {
        self.view = view
        interactor.setup(with: self)
    }
}

// MARK: - StakingPoolMainInteractorOutput

extension StakingPoolMainPresenter: StakingPoolMainInteractorOutput {}

// MARK: - Localizable

extension StakingPoolMainPresenter: Localizable {
    func applyLocalization() {}
}

extension StakingPoolMainPresenter: StakingPoolMainModuleInput {}
