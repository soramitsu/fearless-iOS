import Foundation
import SoraFoundation

final class SelectExportAccountPresenter {
    // MARK: Private properties

    private weak var view: SelectExportAccountViewInput?
    private let router: SelectExportAccountRouterInput
    private let interactor: SelectExportAccountInteractorInput

    // MARK: - Constructors

    init(
        interactor: SelectExportAccountInteractorInput,
        router: SelectExportAccountRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - SelectExportAccountViewOutput

extension SelectExportAccountPresenter: SelectExportAccountViewOutput {
    func didLoad(view: SelectExportAccountViewInput) {
        self.view = view
        interactor.setup(with: self)
    }
}

// MARK: - SelectExportAccountInteractorOutput

extension SelectExportAccountPresenter: SelectExportAccountInteractorOutput {}

// MARK: - Localizable

extension SelectExportAccountPresenter: Localizable {
    func applyLocalization() {}
}

extension SelectExportAccountPresenter: SelectExportAccountModuleInput {}
