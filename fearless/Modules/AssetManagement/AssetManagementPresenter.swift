import Foundation
import SoraFoundation
import SSFModels

@MainActor
protocol AssetManagementViewInput: ControllerBackedProtocol {
    func didReceive(
        viewModel: AssetManagementViewModel,
        for indexPath: IndexPath?
    )
    func didReceive(
        viewModel: AssetManagementViewModel,
        on section: Int
    )
}

protocol AssetManagementInteractorInput: AnyObject {
    func setup(with output: AssetManagementInteractorOutput) async
    func getAvailableChainAssets() async throws -> [ChainAsset]
    func getAccountInfos(
        for chainAssets: [ChainAsset],
        wallet: MetaAccountModel
    ) async throws -> [ChainAssetKey: AccountInfo?]
    func change(
        hidden: Bool,
        assetId: String,
        wallet: MetaAccountModel,
        chainAssets: [ChainAsset]
    ) async
}

final class AssetManagementPresenter {
    // MARK: Private properties

    private weak var view: AssetManagementViewInput?
    private let router: AssetManagementRouterInput
    private let interactor: AssetManagementInteractorInput
    private let logger: LoggerProtocol
    private var wallet: MetaAccountModel
    private let viewModelFactory: AssetManagementViewModelFactory
    private var networkFilter: NetworkManagmentFilter?

    private var chainAssets: [ChainAsset] = []
    private var accountInfos: [ChainAssetKey: AccountInfo?] = [:]
    private var prices: [PriceData] = []

    // MARK: - Constructors

    init(
        wallet: MetaAccountModel,
        networkFilter: NetworkManagmentFilter?,
        logger: LoggerProtocol,
        viewModelFactory: AssetManagementViewModelFactory,
        interactor: AssetManagementInteractorInput,
        router: AssetManagementRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.networkFilter = networkFilter
        self.wallet = wallet
        self.interactor = interactor
        self.router = router
        self.logger = logger
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel(with search: String? = nil) {
        guard chainAssets.isNotEmpty else {
            return
        }
        Task {
            let viewModel = viewModelFactory.buildViewModel(
                chainAssets: chainAssets,
                accountInfos: accountInfos,
                prices: prices,
                wallet: wallet,
                locale: selectedLocale,
                filter: networkFilter,
                search: search
            )
            await view?.didReceive(viewModel: viewModel, for: nil)
        }
    }

    private func getInitialData() {
        Task {
            do {
                let chainAssets = try await interactor.getAvailableChainAssets()
                let accountInfos = try await interactor.getAccountInfos(for: chainAssets, wallet: wallet)
                self.chainAssets = chainAssets
                self.accountInfos = accountInfos
                provideViewModel()
            } catch {
                logger.customError(error)
            }
        }
    }
}

// MARK: - AssetManagementViewOutput

extension AssetManagementPresenter: AssetManagementViewOutput {
    func didSelectRow(at indexPath: IndexPath, viewModel: AssetManagementViewModel) {
        Task {
            let viewModel = viewModelFactory.update(viewModel: viewModel, at: indexPath)
            if let section = viewModel.list[safe: indexPath.section],
               let viewModel = section.cells[safe: indexPath.row] {
                await interactor.change(
                    hidden: viewModel.hidden,
                    assetId: viewModel.assetId,
                    wallet: wallet,
                    chainAssets: chainAssets
                )
            }
            await view?.didReceive(viewModel: viewModel, for: indexPath)
        }
    }

    func didTap(on section: Int, viewModel: AssetManagementViewModel) {
        Task {
            let viewModel = viewModelFactory.update(viewModel: viewModel, on: section)
            await view?.didReceive(viewModel: viewModel, on: section)
        }
    }

    func doneButtonDidTapped() {
        router.dismiss(view: view)
    }

    func searchTextDidChanged(_ text: String?) {
        provideViewModel(with: text)
    }

    func allNetworkButtonDidTapped() {
        router.showSelectNetwork(
            from: view,
            wallet: wallet,
            delegate: self
        )
    }

    func didLoad(view: AssetManagementViewInput) {
        self.view = view
        Task {
            await interactor.setup(with: self)
        }
        getInitialData()
    }
}

// MARK: - AssetManagementInteractorOutput

extension AssetManagementPresenter: AssetManagementInteractorOutput {
    func didReceivePricesData(
        result: Result<[PriceData], Error>
    ) {
        switch result {
        case let .success(priceDataResult):
            guard prices.isEmpty else {
                return
            }
            prices = priceDataResult
            provideViewModel()
        case let .failure(error):
            logger.customError(error)
        }
    }

    func didReceiveUpdated(wallet: MetaAccountModel) {
        self.wallet = wallet
    }
}

// MARK: - Localizable

extension AssetManagementPresenter: Localizable {
    func applyLocalization() {}
}

extension AssetManagementPresenter: AssetManagementModuleInput {}

// MARK: - NetworkManagmentModuleOutput

extension AssetManagementPresenter: NetworkManagmentModuleOutput {
    func did(select: NetworkManagmentFilter, contextTag _: Int?) {
        networkFilter = select
        provideViewModel()
    }
}
