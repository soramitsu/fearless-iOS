import Foundation
import SoraFoundation
import SSFModels

@MainActor
protocol AssetManagementViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: AssetManagementViewModel)
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
        wallet: MetaAccountModel
    ) async -> MetaAccountModel
    func fetchAccountInfo(
        for chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) async throws -> AccountInfo?
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
    private var pendingAccountInfoChainAssets: [ChainAssetId] = []
    private var searchText: String?

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

    private func provideViewModel() {
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
                search: searchText,
                pendingAccountInfoChainAssets: pendingAccountInfoChainAssets
            )
            await view?.didReceive(viewModel: viewModel)
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

    private func handleOnSwitch(viewModel: AssetManagementTableCellViewModel) {
        if viewModel.hidden.inverted() {
            pendingAccountInfoChainAssets.removeAll(where: { $0 == viewModel.chainAsset.chainAssetId })
        } else {
            pendingAccountInfoChainAssets.append(viewModel.chainAsset.chainAssetId)
        }
    }

    private func fetchAccountInfoAndUpdateViewModel(
        chainAsset: ChainAsset,
        viewModel: AssetManagementViewModel,
        indexPath: IndexPath
    ) async {
        pendingAccountInfoChainAssets.removeAll(where: { $0 == chainAsset.chainAssetId })
        do {
            let accountInfo = try await interactor.fetchAccountInfo(
                for: chainAsset,
                wallet: wallet
            )
            guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                return
            }
            let key = chainAsset.uniqueKey(accountId: accountId)
            accountInfos[key] = accountInfo
            await update(at: indexPath, viewModel: viewModel)
        } catch {
            await _ = MainActor.run {
                router.present(error: error, from: view, locale: selectedLocale)
            }
            await update(at: indexPath, viewModel: viewModel)
        }
    }

    private func update(at indexPath: IndexPath, viewModel: AssetManagementViewModel) async {
        let viewModel = viewModelFactory.update(
            viewModel: viewModel,
            at: indexPath,
            pendingAccountInfoChainAssets: pendingAccountInfoChainAssets,
            accountInfos: accountInfos,
            prices: prices,
            locale: selectedLocale,
            wallet: wallet
        )
        await view?.didReceive(viewModel: viewModel)
    }
}

// MARK: - AssetManagementViewOutput

extension AssetManagementPresenter: AssetManagementViewOutput {
    func didSelectRow(at indexPath: IndexPath, viewModel: AssetManagementViewModel) {
        Task {
            if let section = viewModel.list[safe: indexPath.section],
               let cellViewModel = section.cells[safe: indexPath.row] {
                let updatedWallet = await interactor.change(
                    hidden: cellViewModel.hidden.inverted(),
                    assetId: cellViewModel.chainAsset.identifier,
                    wallet: wallet
                )
                wallet = updatedWallet
                handleOnSwitch(viewModel: cellViewModel)
                await update(at: indexPath, viewModel: viewModel)

                let invertedAssetHidden = cellViewModel.hidden.inverted()
                guard !invertedAssetHidden else {
                    return
                }
                await fetchAccountInfoAndUpdateViewModel(
                    chainAsset: cellViewModel.chainAsset,
                    viewModel: viewModel,
                    indexPath: indexPath
                )
            }
        }
    }

    func didTap(on section: Int, viewModel: AssetManagementViewModel) {
        Task {
            let viewModel = viewModelFactory.toggle(viewModel: viewModel, on: section)
            await view?.didReceive(viewModel: viewModel, on: section)
        }
    }

    func doneButtonDidTapped() {
        router.dismiss(view: view)
    }

    func searchTextDidChanged(_ text: String?) {
        searchText = text
        provideViewModel()
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
