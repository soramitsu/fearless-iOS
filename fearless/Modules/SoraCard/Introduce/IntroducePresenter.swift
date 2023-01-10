import Foundation
import SoraFoundation

final class IntroducePresenter {
    // MARK: Private properties

    private weak var view: IntroduceViewInput?
    private let router: IntroduceRouterInput
    private let phone: String

    // MARK: - Constructors

    init(
        router: IntroduceRouterInput,
        phone: String,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.router = router
        self.phone = phone
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - IntroduceViewOutput

extension IntroducePresenter: IntroduceViewOutput {
    func didLoad(view: IntroduceViewInput) {
        self.view = view
    }

    func didTapContinueButton(name: String, lastName: String) {
        router.presentVerificationEmail(
            from: view,
            phone: phone,
            name: name,
            lastName: lastName
        )
    }

    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapCloseButton() {
        router.close(from: view)
    }
}

// MARK: - IntroduceInteractorOutput

extension IntroducePresenter: IntroduceInteractorOutput {}

// MARK: - Localizable

extension IntroducePresenter: Localizable {
    func applyLocalization() {}
}

extension IntroducePresenter: IntroduceModuleInput {}
