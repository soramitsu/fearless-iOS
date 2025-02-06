import Foundation
import SoraFoundation
import SSFModels

final class SelectAssetPresenter {
    // MARK: Private properties

    private weak var view: SelectAssetViewInput?
    private let router: SelectAssetRouterInput
    private let interactor: SelectAssetInteractorInput
    private let logger: LoggerProtocol?

    private let selectedAssetId: String?
    private let viewModelFactory: SelectAssetViewModelFactoryProtocol
    private let wallet: MetaAccountModel
    private let searchTextsViewModel: TextSearchViewModel?
    private let output: SelectAssetModuleOutput
    private let contextTag: Int?

    private var accountInfos: [ChainAssetKey: AccountInfo?] = [:]
    private var viewModels: [SelectAssetCellViewModel] = []
    private var fullViewModels: [SelectAssetCellViewModel] = []
    private var chainAssets: [ChainAsset] = []
    private var selectedChainAsset: ChainAsset?

    private var accountInfosTask: Task<Void, Never>?
    private let processingQueue = DispatchQueue(label: "qr.capture.service.queue")

    // MARK: - Constructors

    init(
        viewModelFactory: SelectAssetViewModelFactoryProtocol,
        wallet: MetaAccountModel,
        selectedAssetId: AssetModel.Id?,
        searchTextsViewModel: TextSearchViewModel?,
        interactor: SelectAssetInteractorInput,
        router: SelectAssetRouterInput,
        output: SelectAssetModuleOutput,
        localizationManager: LocalizationManagerProtocol,
        contextTag: Int?,
        logger: LoggerProtocol?
    ) {
        self.viewModelFactory = viewModelFactory
        self.wallet = wallet
        self.selectedAssetId = selectedAssetId
        self.searchTextsViewModel = searchTextsViewModel
        self.interactor = interactor
        self.router = router
        self.output = output
        self.contextTag = contextTag
        self.logger = logger
        
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func handle(chainAssets: [ChainAsset]) {
        accountInfosTask = Task {
            do {
                let accountInfos = try await self.interactor.fetchAccountInfos(with: chainAssets)
                self.accountInfos = accountInfos
                
                guard !Task.isCancelled else {
                    return
                }
                
                self.chainAssets = chainAssets
                
                await MainActor.run(body: {
                    provideViewModel()
                })
            } catch {
                logger?.customError(error)
            }
        }
    }

    private func provideViewModel() {
        viewModels = viewModelFactory.buildViewModel(
            wallet: wallet,
            chainAssets: chainAssets,
            accountInfos: accountInfos,
            locale: selectedLocale,
            selectedAssetId: selectedAssetId
        )

        fullViewModels = viewModels
        view?.didReload()
    }
}

// MARK: - SelectAssetViewOutput

extension SelectAssetPresenter: SelectAssetViewOutput {
    func didTapRetry() {
        output.refreshData()
    }
    
    var numberOfItems: Int {
        viewModels.count
    }

    func item(at index: Int) -> SelectableViewModelProtocol {
        viewModels[index]
    }

    func selectItem(at index: Int) {
        guard let view = view else { return }
        guard
            let selectedViewModel = viewModels[safe: index],
            let selectedChainAsset = chainAssets.first(where: { chainAsset in
                chainAsset.asset.symbol.lowercased() == selectedViewModel.symbol.lowercased() && chainAsset.chain.name.lowercased() == selectedViewModel.name.lowercased()
            })
        else {
            output.assetSelection(didCompleteWith: nil, contextTag: contextTag)
            router.dismiss(view: view)
            return
        }
        self.selectedChainAsset = selectedChainAsset
        router.dismiss(view: view)
    }

    func searchItem(with text: String?) {
        guard let text = text, text.isNotEmpty else {
            viewModels = fullViewModels
            view?.didReload()
            return
        }

        viewModels = fullViewModels.filter {
            $0.symbol.lowercased().contains(text.lowercased())
        }
        view?.didReload()
    }

    func didLoad(view: SelectAssetViewInput) {
        self.view = view
        interactor.setup(with: self)
        view.bind(viewModel: searchTextsViewModel)
    }

    func willDisappear() {
        output.assetSelection(didCompleteWith: selectedChainAsset, contextTag: contextTag)
    }
}

// MARK: - SelectAssetInteractorOutput

extension SelectAssetPresenter: SelectAssetInteractorOutput {
    func didReceiveChainAssets(result: Result<[ChainAsset], Error>) {
        switch result {
        case let .success(chainAssets):
            handle(chainAssets: chainAssets)
        case let .failure(error):
            router.present(error: error, from: view, locale: selectedLocale)
        }
    }
}

// MARK: - Localizable

extension SelectAssetPresenter: Localizable {
    func applyLocalization() {
        provideViewModel()
    }
}

extension SelectAssetPresenter: SelectAssetModuleInput {
    func update(with chainAssets: [ChainAsset]?) {
        guard let chainAssets else {
            view?.didReceive(errorMessage: R.string.localizable.emptyStateMessage(preferredLanguages: selectedLocale.rLanguages))
            return
        }
        
        view?.didReceive(errorMessage: nil)

        self.chainAssets = chainAssets

        accountInfosTask?.cancel()

        interactor.update(with: chainAssets)
    }

    func runLoading() {
        chainAssets = []
        accountInfos = [:]

        view?.didReload()
        view?.didStartLoading()
    }

    func stopLoading() {
        view?.didStopLoading()
    }
}
