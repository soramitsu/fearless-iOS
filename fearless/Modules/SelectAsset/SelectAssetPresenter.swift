import Foundation
import SoraFoundation

final class SelectAssetPresenter {
    // MARK: Private properties

    private let lock = ReaderWriterLock()

    private weak var view: SelectAssetViewInput?
    private let router: SelectAssetRouterInput
    private let interactor: SelectAssetInteractorInput

    private let selectedAssetId: String?
    private let viewModelFactory: SelectAssetViewModelFactoryProtocol
    private let wallet: MetaAccountModel
    private let searchTextsViewModel: TextSearchViewModel?
    private let output: SelectAssetModuleOutput

    private var accountInfos: [ChainAssetKey: AccountInfo?] = [:]
    private var prices: PriceDataUpdated = ([], false)
    private var viewModels: [SelectAssetCellViewModel] = []
    private var fullViewModels: [SelectAssetCellViewModel] = []
    private var chainAssets: [ChainAsset] = []
    private var accountInfosFetched = false
    private var pricesFetched = false

    private lazy var factoryOperationQueue: OperationQueue = {
        OperationQueue()
    }()

    // MARK: - Constructors

    init(
        viewModelFactory: SelectAssetViewModelFactoryProtocol,
        wallet: MetaAccountModel,
        selectedAssetId: AssetModel.Id?,
        searchTextsViewModel: TextSearchViewModel?,
        interactor: SelectAssetInteractorInput,
        router: SelectAssetRouterInput,
        output: SelectAssetModuleOutput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.viewModelFactory = viewModelFactory
        self.wallet = wallet
        self.selectedAssetId = selectedAssetId
        self.searchTextsViewModel = searchTextsViewModel
        self.interactor = interactor
        self.router = router
        self.output = output
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        guard
            accountInfosFetched,
            pricesFetched
        else {
            return
        }
        factoryOperationQueue.operations.forEach { $0.cancel() }
        factoryOperationQueue.cancelAllOperations()

        let operationBlock = BlockOperation()
        operationBlock.addExecutionBlock { [unowned operationBlock] in
            guard !operationBlock.isCancelled else {
                return
            }
            self.viewModels = self.viewModelFactory.buildViewModel(
                wallet: self.wallet,
                chainAssets: self.chainAssets,
                accountInfos: self.lock.concurrentlyRead { [unowned self] in
                    self.accountInfos
                },
                prices: self.prices,
                locale: self.selectedLocale
            )
            self.fullViewModels = self.viewModels

            DispatchQueue.main.async {
                self.view?.didReload()
            }
        }

        factoryOperationQueue.addOperation(operationBlock)
    }
}

// MARK: - SelectAssetViewOutput

extension SelectAssetPresenter: SelectAssetViewOutput {
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
            let selectedAsset = chainAssets.first(where: { chainAsset in
                chainAsset.asset.name == selectedViewModel.symbol
            })
        else {
            output.assetSelection(didCompleteWith: nil)
            router.dismiss(view: view)
            return
        }

        output.assetSelection(didCompleteWith: selectedAsset.asset)
        router.dismiss(view: view)
    }

    func searchItem(with text: String?) {
        guard let text = text, text.isNotEmpty else {
            viewModels = fullViewModels
            view?.didReload()
            return
        }

        viewModels = viewModels.filter { $0.symbol.lowercased().contains(text.lowercased()) }
        view?.didReload()
    }

    func didLoad(view: SelectAssetViewInput) {
        self.view = view
        interactor.setup(with: self)
        view.bind(viewModel: searchTextsViewModel)
    }
}

// MARK: - SelectAssetInteractorOutput

extension SelectAssetPresenter: SelectAssetInteractorOutput {
    func didReceivePricesData(result: Result<[PriceData], Error>) {
        switch result {
        case let .success(priceDataResult):
            let priceDataUpdated = (pricesData: priceDataResult, updated: true)
            prices = priceDataUpdated
        case let .failure(error):
            let priceDataUpdated = (pricesData: [], updated: true) as PriceDataUpdated
            prices = priceDataUpdated
            router.present(error: error, from: view, locale: selectedLocale)
        }

        pricesFetched = true
        provideViewModel()
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset) {
        switch result {
        case let .success(accountInfo):

            lock.exclusivelyWrite { [unowned self] in
                guard let accountId = self.wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                    return
                }
                let key = chainAsset.uniqueKey(accountId: accountId)
                self.accountInfos[key] = accountInfo
                accountInfosFetched = true
                provideViewModel()
            }
        case let .failure(error):
            DispatchQueue.main.async {
                self.router.present(error: error, from: self.view, locale: self.selectedLocale)
            }
        }
    }

    func didReceiveChainAssets(result: Result<[ChainAsset], Error>) {
        switch result {
        case let .success(chainAssets):
            var items: [ChainAsset] = []
            chainAssets.forEach { items.append($0) }
            self.chainAssets = items
            provideViewModel()
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

extension SelectAssetPresenter: SelectAssetModuleInput {}
