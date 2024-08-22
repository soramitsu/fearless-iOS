import Foundation
import SoraFoundation
import SSFModels

@MainActor
protocol MultichainAssetSelectionViewInput: ControllerBackedProtocol {
    func didReceive(viewModels: [ChainSelectionCollectionCellModel])
}

protocol MultichainAssetSelectionInteractorInput: AnyObject {
    func setup(with output: MultichainAssetSelectionInteractorOutput)
    func fetchChains() async throws -> [ChainModel]
    func fetchAssets(for chain: ChainModel) async throws -> [ChainAsset]
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
    private var selectedChainId: ChainModel.Id?
    private var chains: [ChainModel]?
    private let assetFetching: MultichainAssetFetching

    // MARK: - Constructors

    init(
        interactor: MultichainAssetSelectionInteractorInput,
        router: MultichainAssetSelectionRouterInput,
        localizationManager: LocalizationManagerProtocol,
        viewModelFactory: MultichainAssetSelectionViewModelFactory,
        logger: LoggerProtocol,
        selectAssetModuleOutput: SelectAssetModuleOutput?,
        assetFetching: MultichainAssetFetching
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.selectAssetModuleOutput = selectAssetModuleOutput
        self.assetFetching = assetFetching

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        Task {
            let viewModels = viewModelFactory.buildViewModels(chains: chains.or([]), selectedChainId: selectedChainId)
            await view?.didReceive(viewModels: viewModels)
        }
    }

    private func fetchChains() {
        Task {
            do {
                let chains = try await interactor.fetchChains()
                self.chains = chains

                if selectedChainId == nil {
                    selectedChainId = chains.first?.chainId
                    selectAssetModuleInput?.update(with: (chains.first?.chainAssets).or([]))
                }

                let viewModels = viewModelFactory.buildViewModels(chains: chains, selectedChainId: selectedChainId)
                await view?.didReceive(viewModels: viewModels)
            } catch {
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
        selectAssetModuleInput?.runLoading()
        selectedChainId = chain.chainId
        provideViewModel()

        Task {
            let availableChainAssets = try await assetFetching.fetchAssets(for: chain)

            await MainActor.run {
                selectAssetModuleInput?.update(with: availableChainAssets)
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
}
