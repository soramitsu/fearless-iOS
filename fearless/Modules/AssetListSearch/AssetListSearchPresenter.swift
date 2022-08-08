import Foundation
import SoraFoundation

final class AssetListSearchPresenter {
    // MARK: Private properties

    private weak var view: AssetListSearchViewInput?
    private let router: AssetListSearchRouterInput
    private let interactor: AssetListSearchInteractorInput

    // MARK: - Constructors

    init(
        interactor: AssetListSearchInteractorInput,
        router: AssetListSearchRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - AssetListSearchViewOutput

extension AssetListSearchPresenter: AssetListSearchViewOutput {
    func didLoad(view: AssetListSearchViewInput) {
        self.view = view
        interactor.setup(with: self)
    }
}

// MARK: - AssetListSearchInteractorOutput

extension AssetListSearchPresenter: AssetListSearchInteractorOutput {}

// MARK: - Localizable

extension AssetListSearchPresenter: Localizable {
    func applyLocalization() {}
}

extension AssetListSearchPresenter: AssetListSearchModuleInput {}
