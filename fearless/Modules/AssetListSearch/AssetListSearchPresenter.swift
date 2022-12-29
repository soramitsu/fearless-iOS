import Foundation
import SoraFoundation

final class AssetListSearchPresenter {
    // MARK: Private properties

    private weak var assetListModuleInput: ChainAssetListModuleInput?
    private weak var view: AssetListSearchViewInput?
    private let router: AssetListSearchRouterInput
    private let interactor: AssetListSearchInteractorInput

    // MARK: - Constructors

    init(
        assetListModuleInput: ChainAssetListModuleInput?,
        interactor: AssetListSearchInteractorInput,
        router: AssetListSearchRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.assetListModuleInput = assetListModuleInput
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - AssetListSearchViewOutput

extension AssetListSearchPresenter: AssetListSearchViewOutput {
    func didTapOnCalcel() {
        router.dismiss(view: view)
    }

    func searchTextDidChange(_ text: String?) {
        guard let text = text else {
            return
        }

        var filters: [ChainAssetsFetching.Filter] = []
        if text.isNotEmpty {
            filters.append(.search(text))
        }

        assetListModuleInput?.updateChainAssets(
            using: filters,
            sorts: []
        )
    }

    func didLoad(view: AssetListSearchViewInput) {
        self.view = view
        interactor.setup(with: self)
        assetListModuleInput?.updateChainAssets(
            using: [],
            sorts: []
        )
    }
}

// MARK: - AssetListSearchInteractorOutput

extension AssetListSearchPresenter: AssetListSearchInteractorOutput {}

// MARK: - Localizable

extension AssetListSearchPresenter: Localizable {
    func applyLocalization() {}
}

extension AssetListSearchPresenter: AssetListSearchModuleInput {}
