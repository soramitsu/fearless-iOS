import Foundation
import SoraFoundation

final class IntroducePresenter {
    // MARK: Private properties

    private weak var view: IntroduceViewInput?
    private let router: IntroduceRouterInput
    private var data: SCKYCUserDataModel

    // MARK: - Constructors

    init(
        router: IntroduceRouterInput,
        data: SCKYCUserDataModel,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.router = router
        self.data = data
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
        data.name = name
        data.lastname = lastName
        router.presentVerificationEmail(
            from: view,
            data: data
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
