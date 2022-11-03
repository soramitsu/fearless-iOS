import Foundation
import SoraFoundation

final class AllDonePresenter {
    // MARK: Private properties

    private weak var view: AllDoneViewInput?
    private let router: AllDoneRouterInput
    private let interactor: AllDoneInteractorInput

    private let hashString: String

    // MARK: - Constructors

    init(
        hashString: String,
        interactor: AllDoneInteractorInput,
        router: AllDoneRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.hashString = hashString
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
        
        provide(hashString: hashString)
    }

    // MARK: - Private methods

    private func provide(hashString: String) {
        view?.didReceive(hashString: hashString)
    }
}

// MARK: - AllDoneViewOutput

extension AllDonePresenter: AllDoneViewOutput {
    func didLoad(view: AllDoneViewInput) {
        self.view = view
        interactor.setup(with: self)
    }
}

// MARK: - AllDoneInteractorOutput

extension AllDonePresenter: AllDoneInteractorOutput {}

// MARK: - Localizable

extension AllDonePresenter: Localizable {
    func applyLocalization() {
        provide(hashString: hashString)
    }
}

extension AllDonePresenter: AllDoneModuleInput {}
