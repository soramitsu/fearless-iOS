import Foundation
import SoraFoundation

final class IntroducePresenter {
    // MARK: Private properties

    private weak var view: IntroduceViewInput?
    private let router: IntroduceRouterInput
    private let interactor: IntroduceInteractorInput

    // MARK: - Constructors

    init(
        interactor: IntroduceInteractorInput,
        router: IntroduceRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - IntroduceViewOutput

extension IntroducePresenter: IntroduceViewOutput {
    func didLoad(view: IntroduceViewInput) {
        self.view = view
        interactor.setup(with: self)
    }
}

// MARK: - IntroduceInteractorOutput

extension IntroducePresenter: IntroduceInteractorOutput {}

// MARK: - Localizable

extension IntroducePresenter: Localizable {
    func applyLocalization() {}
}

extension IntroducePresenter: IntroduceModuleInput {}
