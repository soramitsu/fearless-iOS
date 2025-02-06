import Foundation
import SoraFoundation
import SSFModels

@MainActor
protocol MultichainAssetSelectionViewInput: ControllerBackedProtocol {
    func didReceive(viewModels: [ChainSelectionCollectionCellModel]?)
}

protocol MultichainAssetSelectionInteractorInput: AnyObject {
    func setup(with output: MultichainAssetSelectionInteractorOutput)
    func fetchChains() async throws -> [ChainModel]
    func fetchAssets(for chain: ChainModel, preferredDataSourceType: PreferredDataSourceType) async throws -> [ChainAsset]
}

final class MultichainAssetSelectionPresenter {
    // MARK: Private properties

    private weak var view: MultichainAssetSelectionViewInput?
    private let router: MultichainAssetSelectionRouterInput
    private let interactor: MultichainAssetSelectionInteractorInput
    private let viewModelFactory: MultichainAssetSelectionViewModelFactory
    private let logger: LoggerProtocol
    private let selectAssetModuleOutput: SelectAssetModuleOutput?
    weak var selectAssetModuleInput: SelectAssetModuleInput?
//    private var selectedChainId: ChainModel.Id?
    private var selectedChain: ChainModel?
    private var chains: [ChainModel]?
    private let assetFetching: MultichainAssetFetching
    private var filter: ((ChainAsset) throws -> Bool)?

    // MARK: - Constructors

    init(
        interactor: MultichainAssetSelectionInteractorInput,
        router: MultichainAssetSelectionRouterInput,
        localizationManager: LocalizationManagerProtocol,
        viewModelFactory: MultichainAssetSelectionViewModelFactory,
        logger: LoggerProtocol,
        selectAssetModuleOutput: SelectAssetModuleOutput?,
        assetFetching: MultichainAssetFetching,
        selectedChainAsset: ChainAsset?,
        filter: ((ChainAsset) throws -> Bool)?
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.selectAssetModuleOutput = selectAssetModuleOutput
        self.assetFetching = assetFetching
        self.filter = filter

        selectedChain = selectedChainAsset?.chain

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        Task {
            let viewModels = viewModelFactory.buildViewModels(chains: chains.or([]), selectedChainId: selectedChain?.chainId)
            await view?.didReceive(viewModels: viewModels)
        }
    }

    private func fetchChains() {
        Task {
            do {
                let chains = try await interactor.fetchChains().sorted(by: { $0.rank.or(UInt16.max) < $1.rank.or(UInt16.max) })
                self.chains = chains

                if selectedChain == nil {
                    selectedChain = chains.first

                    if let chain = chains.first {
                        DispatchQueue.main.async { [weak self] in
                            self?.didSelect(chain: chain)
                        }
                    }
                } else if let chain = chains.first(where: { $0.chainId == selectedChain?.chainId }) {
                    DispatchQueue.main.async { [weak self] in
                        self?.didSelect(chain: chain)
                    }
                }

                let viewModels = viewModelFactory.buildViewModels(chains: chains, selectedChainId: selectedChain?.chainId)
                await view?.didReceive(viewModels: viewModels)
            } catch {
                await MainActor.run {
                    selectAssetModuleInput?.stopLoading()
                    selectAssetModuleInput?.update(with: nil)
                }

                await view?.didReceive(viewModels: nil)
                logger.customError(error)
            }
        }
    }
}

// MARK: - MultichainAssetSelectionViewOutput

extension MultichainAssetSelectionPresenter: MultichainAssetSelectionViewOutput {
    func didLoad(view: MultichainAssetSelectionViewInput) {
        self.view = view
        interactor.setup(with: self)

        fetchChains()
    }

    func didSelect(chain: ChainModel) {
        
        selectedChain = chain
        provideViewModel()

        Task {
            do {
                if let cachedChainAssets = try? await interactor.fetchAssets(for: chain, preferredDataSourceType: .cache) {
                    var filtered = cachedChainAssets

                    if let filter {
                        filtered = try cachedChainAssets.filter(filter)
                    }

                    await MainActor.run { [filtered] in
                        selectAssetModuleInput?.update(with: filtered)
                    }
                } else {
                    await MainActor.run {
                        selectAssetModuleInput?.runLoading()
                    }
                }

                let availableChainAssets = try await interactor.fetchAssets(for: chain, preferredDataSourceType: .remote)
                var filtered = availableChainAssets

                if let filter {
                    filtered = try availableChainAssets.filter(filter)
                }

                await MainActor.run { [filtered] in
                    selectAssetModuleInput?.update(with: filtered)
                }
            } catch {
                logger.customError(error)
            }
        }
    }

    func didTapCloseButton() {
        router.dismiss(view: view)
    }
}

// MARK: - MultichainAssetSelectionInteractorOutput

extension MultichainAssetSelectionPresenter: MultichainAssetSelectionInteractorOutput {}

// MARK: - Localizable

extension MultichainAssetSelectionPresenter: Localizable {
    func applyLocalization() {}
}

extension MultichainAssetSelectionPresenter: MultichainAssetSelectionModuleInput {}

extension MultichainAssetSelectionPresenter: SelectAssetModuleOutput {
    func assetSelection(didCompleteWith chainAsset: ChainAsset?, contextTag: Int?) {
        selectAssetModuleOutput?.assetSelection(didCompleteWith: chainAsset, contextTag: contextTag)
    }
    
    func refreshData() {
        selectAssetModuleInput?.runLoading()

        if let selectedChain = selectedChain {
            didSelect(chain: selectedChain)
        } else {
            fetchChains()
        }
    }
}
