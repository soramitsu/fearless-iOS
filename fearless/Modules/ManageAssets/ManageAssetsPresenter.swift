import Foundation
import SoraFoundation

final class ManageAssetsPresenter {
    weak var view: ManageAssetsViewProtocol?
    private let wireframe: ManageAssetsWireframeProtocol
    private let interactor: ManageAssetsInteractorInputProtocol
    private let viewModelFactory: ManageAssetsViewModelFactoryProtocol
    private let selectedMetaAccount: MetaAccountModel
    private var chainModels: [ChainModel] = []
    private var accountInfos: [ChainModel.Id: AccountInfo] = [:]
    private var viewModel: ManageAssetsViewModel?
    private var sortedKeys: [String]?

    init(
        interactor: ManageAssetsInteractorInputProtocol,
        wireframe: ManageAssetsWireframeProtocol,
        viewModelFactory: ManageAssetsViewModelFactoryProtocol,
        selectedMetaAccount: MetaAccountModel,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.selectedMetaAccount = selectedMetaAccount

        self.localizationManager = localizationManager
    }

    private func provideViewModel() {
        let viewModel = viewModelFactory.buildManageAssetsViewModel(
            selectedMetaAccount: selectedMetaAccount,
            chains: chainModels,
            locale: selectedLocale,
            accountInfos: accountInfos,
            sortedKeys: sortedKeys,
            cellsDelegate: self
        )

        self.viewModel = viewModel

        view?.didReceive(state: .loaded(viewModel: viewModel))
    }
}

extension ManageAssetsPresenter: ManageAssetsPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func move(viewModel _: ManageAssetsTableViewCellModel, from: Int, to: Int) {
        if var assets = viewModel?.cellModels.map(\.asset) {
            assets.swapAt(from, to)
            interactor.saveAssetsOrder(assets: assets)
        }
    }

    func didTapCloseButton() {
        wireframe.dismiss(view: view)
    }
}

extension ManageAssetsPresenter: ManageAssetsInteractorOutputProtocol {
    func didReceiveSortOrder(sortedKeys: [String]?) {
        self.sortedKeys = sortedKeys
        provideViewModel()
    }

    func didReceiveChains(result: Result<[ChainModel], Error>) {
        switch result {
        case let .success(chains):
            chainModels = chains
            provideViewModel()
        case let .failure(error):
            _ = wireframe.present(error: error, from: view, locale: selectedLocale)
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainId: ChainModel.Id) {
        accountInfos[chainId] = try? result.get()
        provideViewModel()
    }
}

extension ManageAssetsPresenter: Localizable {
    func applyLocalization() {
        view?.didReceive(locale: selectedLocale)
    }
}

extension ManageAssetsPresenter: ManageAssetsTableViewCellModelDelegate {
    func switchAssetEnabledState(asset: AssetModel) {
    }
}
