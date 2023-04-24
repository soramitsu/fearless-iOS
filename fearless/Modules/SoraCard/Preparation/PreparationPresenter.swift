import Foundation
import SoraFoundation

final class PreparationPresenter {
    // MARK: Private properties

    private weak var view: PreparationViewInput?
    private let router: PreparationRouterInput
    private let interactor: PreparationInteractorInput
    private let data: SCKYCUserDataModel

    // MARK: - Constructors

    init(
        interactor: PreparationInteractorInput,
        router: PreparationRouterInput,
        data: SCKYCUserDataModel,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.data = data
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - PreparationViewOutput

extension PreparationPresenter: PreparationViewOutput {
    func didLoad(view: PreparationViewInput) {
        self.view = view
        interactor.setup(with: self)
    }

    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapConfirmButton() {
        router.presentKYC(from: view, data: data)
    }
}

// MARK: - PreparationInteractorOutput

extension PreparationPresenter: PreparationInteractorOutput {}

// MARK: - Localizable

extension PreparationPresenter: Localizable {
    func applyLocalization() {}
}

extension PreparationPresenter: PreparationModuleInput {}
