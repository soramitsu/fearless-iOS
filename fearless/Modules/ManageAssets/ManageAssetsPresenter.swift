import Foundation
import SoraFoundation

final class ManageAssetsPresenter {
    weak var view: ManageAssetsViewProtocol?
    private let wireframe: ManageAssetsWireframeProtocol
    private let interactor: ManageAssetsInteractorInputProtocol
    private let viewModelFactory: ManageAssetsViewModelFactoryProtocol
    private var selectedMetaAccount: MetaAccountModel
    private var chainModels: [ChainModel] = []
    private var accountInfos: [ChainModel.Id: AccountInfo] = [:]
    private var viewModel: ManageAssetsViewModel?
    private var sortedKeys: [String]?
    private var assetIdsEnabled: [String]?
    private var filter: String?
    private var chainAssets: [ChainAsset]?

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
            accountInfos: accountInfos,
            sortedKeys: sortedKeys,
            assetIdsEnabled: assetIdsEnabled,
            cellsDelegate: self,
            filter: filter,
            locale: localizationManager?.selectedLocale
        )

        self.viewModel = viewModel

        view?.didReceive(state: .loaded(viewModel: viewModel))
    }
}

extension ManageAssetsPresenter: ManageAssetsPresenterProtocol {
    func setup() {
        interactor.setup()

        view?.didReceive(locale: selectedLocale)
    }

    func move(from: IndexPath, to: IndexPath) {
        if var assets = viewModel?.sections[from.section].cellModels.map(\.chainAsset) {
            assets.swapAt(from.row, to.row)
            interactor.saveAssetsOrder(assets: assets)
        }
    }

    func didTapCloseButton() {
        wireframe.dismiss(view: view)
    }

    func didTapApplyButton() {
        interactor.saveAllChanges()
    }

    func searchBarTextDidChange(_ text: String) {
        filter = text
        provideViewModel()
    }
}

extension ManageAssetsPresenter: ManageAssetsInteractorOutputProtocol {
    func didReceiveWallet(_ wallet: MetaAccountModel) {
        selectedMetaAccount = wallet
        provideViewModel()
    }

    func didReceiveAssetIdsEnabled(_ assetIdsEnabled: [String]?) {
        self.assetIdsEnabled = assetIdsEnabled
        provideViewModel()
    }

    func didReceiveSortOrder(_ sortedKeys: [String]?) {
        self.sortedKeys = sortedKeys
        provideViewModel()
    }

    func didReceiveChains(result: Result<[ChainModel], Error>) {
        switch result {
        case let .success(chains):
            chainModels = chains
            chainAssets = chains.map { chain in
                chain.assets.compactMap { asset in
                    ChainAsset(chain: chain, asset: asset.asset)
                }
            }.reduce([], +)

            provideViewModel()
        case let .failure(error):
            _ = wireframe.present(error: error, from: view, locale: selectedLocale)
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainId: ChainModel.Id) {
        accountInfos[chainId] = try? result.get()
        provideViewModel()
    }

    func saveDidComplete() {
        wireframe.dismiss(view: view)
    }
}

extension ManageAssetsPresenter: Localizable {
    func applyLocalization() {
        view?.didReceive(locale: selectedLocale)
        provideViewModel()
    }
}

extension ManageAssetsPresenter: ManageAssetsTableViewCellModelDelegate {
    func switchAssetEnabledState(asset: ChainAsset) {
        let id = asset.uniqueKey(accountId: selectedMetaAccount.substrateAccountId)
        let accountId = selectedMetaAccount.substrateAccountId

        var modifiedAssetIdsEnabled: [String] = []
        if assetIdsEnabled == nil {
            modifiedAssetIdsEnabled = chainAssets?
                .compactMap { $0.uniqueKey(accountId: accountId) }
                .filter { $0 != id } ?? []
        } else {
            let contains = assetIdsEnabled?.contains(id) == true
            if contains {
                modifiedAssetIdsEnabled = assetIdsEnabled?.filter { $0 != id } ?? []
            } else {
                modifiedAssetIdsEnabled = (assetIdsEnabled ?? []) + [id]
            }
        }

        interactor.saveAssetIdsEnabled(modifiedAssetIdsEnabled)
    }

    func showMissingAccountOptions(chainAsset: ChainAsset) {
        let unused = (selectedMetaAccount.unusedChainIds ?? []).contains(chainAsset.chain.chainId)
        let options: [MissingAccountOption?] = [.create, .import, unused ? nil : .skip]

        wireframe.presentAccountOptions(
            from: view,
            locale: selectedLocale,
            options: options.compactMap { $0 },
            uniqueChainModel: UniqueChainModel(
                meta: selectedMetaAccount,
                chain: chainAsset.chain
            )
        ) { [weak self] chain in
            self?.interactor.markUnused(chain: chain)
        }
    }
}
