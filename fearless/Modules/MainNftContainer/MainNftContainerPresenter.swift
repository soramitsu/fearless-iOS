import Foundation
import SoraFoundation

final class MainNftContainerPresenter {
    // MARK: Private properties

    private weak var view: MainNftContainerViewInput?
    private let router: MainNftContainerRouterInput
    private let interactor: MainNftContainerInteractorInput

    // MARK: - Constructors

    init(
        interactor: MainNftContainerInteractorInput,
        router: MainNftContainerRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - MainNftContainerViewOutput

extension MainNftContainerPresenter: MainNftContainerViewOutput {
    func didLoad(view: MainNftContainerViewInput) {
        self.view = view
        interactor.setup(with: self)
    }
}

// MARK: - MainNftContainerInteractorOutput

extension MainNftContainerPresenter: MainNftContainerInteractorOutput {}

// MARK: - Localizable

extension MainNftContainerPresenter: Localizable {
    func applyLocalization() {}
}

extension MainNftContainerPresenter: MainNftContainerModuleInput {}
