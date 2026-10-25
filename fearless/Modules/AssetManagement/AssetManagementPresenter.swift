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
    func change(
        hidden: Bool,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) async -> MetaAccountModel
    func changeGroup(hidden: Bool, chainAssets: [ChainAsset], wallet: MetaAccountModel) async
    func resetToAutomatic(chainAsset: ChainAsset, wallet: MetaAccountModel) async
    func resetOrder(wallet: MetaAccountModel) async throws -> MetaAccountModel
    func fetchAccountInfo(
        for chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) async throws -> AccountInfo?
    func refreshAccountInfos(
        for chainAssets: [ChainAsset],
        wallet: MetaAccountModel
    ) async throws -> [ChainAssetKey: AccountInfo?]
}

extension AssetManagementInteractorInput {
    func change(
        hidden: Bool,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) async -> MetaAccountModel {
        await change(hidden: hidden, assetId: chainAsset.identifier, wallet: wallet)
    }
}

final class AssetManagementPresenter {
    private weak var view: AssetManagementViewInput?
    private let router: AssetManagementRouterInput
    private let interactor: AssetManagementInteractorInput
    private let logger: LoggerProtocol
    private var wallet: MetaAccountModel
    private let viewModelFactory: AssetManagementViewModelFactory
    private var networkFilter: NetworkManagmentFilter?
    private var viewModel: AssetManagementViewModel?
    private var chainAssets: [ChainAsset] = []
    private var accountInfos: [ChainAssetKey: AccountInfo?] = [:]
    private var pendingAccountInfoChainAssets: [ChainAssetId] = []
    private var searchText: String?
    private var visibilityFilter: ManageAssetsFilter
    private let sessionScope = PortfolioCallbackScope()
    private let dataScope = PortfolioCallbackScope()
    private var sessionRequest: UUID?
    private var savingPreferenceRequest: UUID?
    private var isSavingPreference: Bool { savingPreferenceRequest != nil }

    init(
        wallet: MetaAccountModel,
        networkFilter: NetworkManagmentFilter?,
        logger: LoggerProtocol,
        viewModelFactory: AssetManagementViewModelFactory,
        interactor: AssetManagementInteractorInput,
        router: AssetManagementRouterInput,
        localizationManager: LocalizationManagerProtocol,
        visibilityFilter: ManageAssetsFilter = .all
    ) {
        self.networkFilter = networkFilter
        self.visibilityFilter = visibilityFilter
        self.wallet = wallet
        self.interactor = interactor
        self.router = router
        self.logger = logger
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
        sessionRequest = sessionScope.snapshot()
    }

    private var isCurrentSession: Bool { sessionRequest.map(sessionScope.isCurrent) == true }

    @MainActor private func provideViewModel() {
        guard isCurrentSession else { return }
        var model = viewModelFactory.buildViewModel(
            chainAssets: chainAssets, accountInfos: accountInfos, wallet: wallet, locale: selectedLocale,
            filter: visibilityFilter == .hidden ? .all : networkFilter, search: searchText, pendingAccountInfoChainAssets: pendingAccountInfoChainAssets
        ).filtered(by: visibilityFilter)
        let expanded = Set(viewModel?.list.filter(\.isExpanded).map(\.id) ?? [])
        for index in model.list.indices { model.list[index].isExpanded = expanded.contains(model.list[index].id) }
        viewModel = model
        view?.didReceive(viewModel: model)
    }

    private func getInitialData() {
        let request = dataScope.invalidate()
        Task { @MainActor [weak self] in
            guard let self, self.isCurrentSession else { return }
            let wallet = self.wallet
            do {
                let assets = try await interactor.getAvailableChainAssets()
                guard isCurrentSession, dataScope.isCurrent(request) else { return }
                let infos = try await interactor.getAccountInfos(for: assets, wallet: wallet)
                guard isCurrentSession, dataScope.isCurrent(request) else { return }
                chainAssets = assets
                accountInfos = infos
                provideViewModel()
            } catch {
                guard isCurrentSession, dataScope.isCurrent(request) else { return }
                logger.customError(error)
                router.present(error: error, from: view, locale: selectedLocale)
                provideViewModel()
            }
        }
    }
}

extension AssetManagementPresenter: AssetManagementViewOutput {
    func didTapResetOrder() {
        Task { @MainActor [weak self] in
            guard let self, self.isCurrentSession, !self.isSavingPreference, self.wallet.assetKeysOrder != nil else { return }
            let wallet = self.wallet
            let title = PortfolioStrings.text("manage_assets.reset_order", locale: selectedLocale)
            let action = SheetAlertPresentableAction(title: title) { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self, self.isCurrentSession, !self.isSavingPreference, self.wallet == wallet else { return }
                    let saveRequest = UUID()
                    savingPreferenceRequest = saveRequest
                    defer { if savingPreferenceRequest == saveRequest { savingPreferenceRequest = nil } }
                    let request = dataScope.invalidate()
                    pendingAccountInfoChainAssets = []
                    do {
                        let updated = try await interactor.resetOrder(wallet: wallet)
                        guard isCurrentSession, dataScope.isCurrent(request), self.wallet == wallet || self.wallet == updated else { return }
                        self.wallet = updated
                        provideViewModel()
                    } catch is CancellationError {
                        // A changed selection or wallet snapshot invalidates this confirmation.
                    } catch {
                        guard isCurrentSession, dataScope.isCurrent(request) else { return }
                        router.present(error: error, from: view, locale: selectedLocale)
                    }
                }
            }
            router.presentResetOrderConfirmation(viewModel: SheetAlertPresentableViewModel(
                title: title,
                message: PortfolioStrings.text("manage_assets.reset_order_message", locale: selectedLocale),
                actions: [action], closeAction: R.string.localizable.commonCancel(preferredLanguages: selectedLocale.rLanguages)
            ), from: view)
        }
    }

    func didSelectRow(at indexPath: IndexPath, viewModel model: AssetManagementViewModel) {
        Task { @MainActor [weak self] in
            guard let self, self.isCurrentSession, !self.isSavingPreference,
                  self.viewModel?.revision == model.revision,
                  let cell = model.list[safe: indexPath.section]?.cells[safe: indexPath.row] else { return }
            let wallet = self.wallet
            let request = dataScope.invalidate()
            pendingAccountInfoChainAssets = []
            let saveRequest = UUID()
            savingPreferenceRequest = saveRequest
            defer { if savingPreferenceRequest == saveRequest { savingPreferenceRequest = nil } }
            _ = await interactor.change(hidden: !cell.hidden, chainAsset: cell.chainAsset, wallet: wallet)
            guard isCurrentSession, dataScope.isCurrent(request) else { return }
            if savingPreferenceRequest == saveRequest { savingPreferenceRequest = nil }
            if cell.hidden { pendingAccountInfoChainAssets.append(cell.chainAsset.chainAssetId) }
            provideViewModel()
            guard cell.hidden else { return }
            do {
                let info = try await interactor.fetchAccountInfo(for: cell.chainAsset, wallet: wallet)
                guard isCurrentSession, dataScope.isCurrent(request) else { return }
                if let account = wallet.fetch(for: cell.chainAsset.chain.accountRequest()), let info {
                    accountInfos[cell.chainAsset.uniqueKey(accountId: account.accountId)] = info
                }
            } catch {
                guard isCurrentSession, dataScope.isCurrent(request) else { return }
                router.present(error: error, from: view, locale: selectedLocale)
            }
            pendingAccountInfoChainAssets.removeAll { $0 == cell.chainAsset.chainAssetId }
            provideViewModel()
        }
    }

    func didToggleGroup(on index: Int, viewModel model: AssetManagementViewModel) {
        Task { @MainActor [weak self] in
            guard let self, self.isCurrentSession, !self.isSavingPreference,
                  self.viewModel?.revision == model.revision,
                  let section = model.list[safe: index], section.id.hasPrefix("group:"), !section.visibilityMembers.isEmpty else { return }
            let hidden = section.groupVisibility == .on
            let members = section.visibilityMembers, wallet = self.wallet
            let request = dataScope.invalidate()
            let saveRequest = UUID()
            savingPreferenceRequest = saveRequest
            defer { if savingPreferenceRequest == saveRequest { savingPreferenceRequest = nil } }
            pendingAccountInfoChainAssets = []
            await interactor.changeGroup(hidden: hidden, chainAssets: members, wallet: wallet)
            guard isCurrentSession, dataScope.isCurrent(request) else { return }
            if savingPreferenceRequest == saveRequest { savingPreferenceRequest = nil }
            if !hidden { pendingAccountInfoChainAssets = members.map(\.chainAssetId) }
            provideViewModel()
            guard !hidden else { return }
            do {
                let infos = try await interactor.refreshAccountInfos(for: members, wallet: wallet)
                guard isCurrentSession, dataScope.isCurrent(request) else { return }
                for (key, info) in infos { if let info { accountInfos[key] = info } }
            } catch {
                guard isCurrentSession, dataScope.isCurrent(request) else { return }
                router.present(error: error, from: view, locale: selectedLocale)
            }
            pendingAccountInfoChainAssets = []
            provideViewModel()
        }
    }

    func didResetToAutomatic(at indexPath: IndexPath, viewModel model: AssetManagementViewModel) {
        Task { @MainActor [weak self] in
            guard let self, self.isCurrentSession, !self.isSavingPreference,
                  self.viewModel?.revision == model.revision,
                  let cell = model.list[safe: indexPath.section]?.cells[safe: indexPath.row] else { return }
            let request = dataScope.invalidate()
            let saveRequest = UUID()
            savingPreferenceRequest = saveRequest
            defer { if savingPreferenceRequest == saveRequest { savingPreferenceRequest = nil } }
            pendingAccountInfoChainAssets = []
            await interactor.resetToAutomatic(chainAsset: cell.chainAsset, wallet: wallet)
            guard isCurrentSession, dataScope.isCurrent(request) else { return }
            provideViewModel()
        }
    }

    func didTap(on section: Int, viewModel model: AssetManagementViewModel) {
        Task { @MainActor [weak self] in
            guard let self, self.isCurrentSession, self.viewModel?.revision == model.revision else { return }
            var updated = viewModelFactory.toggle(viewModel: model, on: section)
            updated.revision = UUID()
            viewModel = updated
            view?.didReceive(viewModel: updated)
        }
    }

    func doneButtonDidTapped() {
        sessionScope.invalidate()
        dataScope.invalidate()
        Task { @MainActor [weak self] in
            guard let self else { return }
            router.dismiss(view: view)
        }
    }

    func searchTextDidChanged(_ text: String?) {
        Task { @MainActor [weak self] in
            guard let self, self.isCurrentSession else { return }
            searchText = text
            provideViewModel()
        }
    }

    func didSelectVisibilityFilter(_ filter: ManageAssetsFilter) {
        Task { @MainActor [weak self] in
            guard let self, self.isCurrentSession else { return }
            visibilityFilter = filter
            provideViewModel()
        }
    }

    func allNetworkButtonDidTapped() {
        Task { @MainActor [weak self] in
            guard let self, self.isCurrentSession else { return }
            router.showSelectNetwork(from: view, wallet: wallet, delegate: self)
        }
    }

    func didLoad(view: AssetManagementViewInput) {
        Task { @MainActor [weak self] in
            guard let self, self.isCurrentSession else { return }
            self.view = view
            await interactor.setup(with: self)
            guard isCurrentSession else { return }
            getInitialData()
        }
    }

    func didPullToRefresh() {
        let request = dataScope.invalidate()
        Task { @MainActor [weak self] in
            guard let self, self.isCurrentSession else { return }
            guard !chainAssets.isEmpty else { getInitialData(); return }
            let assets = chainAssets, wallet = self.wallet
            do {
                let infos = try await interactor.refreshAccountInfos(for: assets, wallet: wallet)
                guard isCurrentSession, dataScope.isCurrent(request) else { return }
                for (key, value) in infos { if let value { accountInfos[key] = value } }
            } catch {
                guard isCurrentSession, dataScope.isCurrent(request) else { return }
                router.present(error: error, from: view, locale: selectedLocale)
            }
            pendingAccountInfoChainAssets = []
            provideViewModel()
        }
    }
}

extension AssetManagementPresenter: AssetManagementInteractorOutput {
    func didReceiveUpdated(wallet: MetaAccountModel) {
        Task { @MainActor [weak self] in
            guard let self, self.isCurrentSession, self.wallet.metaId == wallet.metaId else { return }
            self.wallet = wallet
            provideViewModel()
        }
    }

    func didChangeSelectedWallet() {
        // Invalidate synchronously at the event boundary, before queued callbacks.
        doneButtonDidTapped()
    }
}

extension AssetManagementPresenter: Localizable {
    func applyLocalization() {
        Task { @MainActor [weak self] in self?.provideViewModel() }
    }
}

extension AssetManagementPresenter: AssetManagementModuleInput {}

extension AssetManagementPresenter: NetworkManagmentModuleOutput {
    func did(select: NetworkManagmentFilter, contextTag _: Int?) {
        Task { @MainActor [weak self] in
            guard let self, self.isCurrentSession else { return }
            networkFilter = select
            provideViewModel()
        }
    }
}
