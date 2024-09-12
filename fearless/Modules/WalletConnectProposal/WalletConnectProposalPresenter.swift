import Foundation
import WalletConnectSign
import SoraFoundation
import SSFModels

protocol WalletConnectProposalViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(viewModel: WalletConnectProposalViewModel)
}

protocol WalletConnectProposalInteractorInput: AnyObject {
    func setup(with output: WalletConnectProposalInteractorOutput)
    func submit(proposalDecision: WalletConnectProposalDecision) async throws
    func submitDisconnect(topic: String) async throws
    func confirmConnectionRequest(
        wallet: MetaAccountModel,
        tonChainModel: ChainModel,
        params: TonConnectParameters,
        manifest: TonConnectManifest
    ) async throws
}

final class WalletConnectProposalPresenter {
    // MARK: Private properties

    private weak var view: WalletConnectProposalViewInput?
    private weak var moduleOutput: WalletConnectProposalModuleOutput?
    private let router: WalletConnectProposalRouterInput
    private let interactor: WalletConnectProposalInteractorInput

    private let status: SessionStatus
    private let walletConnectModelFactory: WalletConnectModelFactory
    private let viewModelFactory: WalletConnectProposalViewModelFactory
    private let dataValidatingFactory: WalletConnectProposalDataValidating
    private let logger: LoggerProtocol

    private var viewModel: WalletConnectProposalViewModel?
    private var wallets: [MetaAccountModel] = []
    private var chains: [ChainModel] = []
    private var optionalChainsIds: [ChainModel.Id]?

    // MARK: - Constructors

    init(
        status: SessionStatus,
        walletConnectModelFactory: WalletConnectModelFactory,
        viewModelFactory: WalletConnectProposalViewModelFactory,
        dataValidatingFactory: WalletConnectProposalDataValidating,
        logger: LoggerProtocol,
        interactor: WalletConnectProposalInteractorInput,
        router: WalletConnectProposalRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        moduleOutput = status.moduleOutput
        self.status = status
        self.walletConnectModelFactory = walletConnectModelFactory
        self.viewModelFactory = viewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.logger = logger
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        switch status {
        case .proposal:
            buildViewModel()
            setOptionalChains()
        case .active:
            buildViewModel()
        }
    }

    private func buildViewModel() {
        guard chains.isNotEmpty, wallets.isNotEmpty else {
            return
        }
        do {
            let viewModel = try viewModelFactory.buildViewModel(
                chains: chains,
                wallets: wallets,
                locale: selectedLocale
            )
            DispatchQueue.main.async {
                self.view?.didReceive(viewModel: viewModel)
            }
            self.viewModel = viewModel
        } catch {
            logger.customError(error)
            handle(error: error)
        }
    }

    private func provideTappedViewModel(at indexPath: IndexPath) {
        guard
            let cells = viewModel?.cells,
            let updatedViewModel = viewModelFactory.didTapOn(indexPath, cells: cells)
        else {
            return
        }

        view?.didReceive(viewModel: updatedViewModel)
        viewModel = updatedViewModel
    }

    private func submitReject() {
        Task {
            do {
                guard let proposal = status.proposal else { return }
                try await interactor.submit(proposalDecision: .reject(proposal: proposal))
                await showAllDone(description: R.string.localizable.commonRejected(preferredLanguages: selectedLocale.rLanguages))
            } catch {
                logger.customError(error)
                handle(error: error)
            }
        }
    }

    private func submitWalletConnectApprove() {
        guard let proposal = status.proposal else { return }
        let selectedWallets = wallets.filter { wallet in
            viewModel?.selectedWalletIds?.contains(wallet.metaId) == true
        }
        let requiredNamespaces = proposal.requiredNamespaces.map { $0.value }
        let requiredMethods = requiredNamespaces.map { $0.methods }.reduce([], +)
        DataValidationRunner(validators: [
            dataValidatingFactory.validate(
                requiredMethods: requiredMethods,
                view: view,
                locale: selectedLocale,
                onReject: { [weak self] in
                    self?.submitReject()
                }
            )
        ]).runValidation { [weak self] in
            guard let strongSelf = self else { return }
            Task {
                do {
                    let namespaces = try strongSelf.walletConnectModelFactory.createSessionNamespaces(
                        from: proposal,
                        wallets: selectedWallets,
                        chains: strongSelf.chains,
                        optionalChainIds: strongSelf.optionalChainsIds
                    )
                    try await strongSelf.interactor.submit(proposalDecision: .approve(proposal: proposal, namespaces: namespaces))
                    let dApp = proposal.proposer.name
                    let description = R.string.localizable
                        .walletConnectConnectionComplete(dApp, preferredLanguages: strongSelf.selectedLocale.rLanguages)
                    await strongSelf.showAllDone(description: description)
                } catch {
                    strongSelf.logger.customError(error)
                    strongSelf.handle(error: error)
                }
            }
        }
    }

    private func submitDisconnect(topic: String, name: String) {
        Task {
            do {
                try await interactor.submitDisconnect(topic: topic)
                let description = R.string.localizable.walletConnectConnectionDissconnected(name, preferredLanguages: selectedLocale.rLanguages)
                await showAllDone(description: description)
            } catch {
                logger.customError(error)
                handle(error: error)
            }
        }
    }

    private func showRequiredNetworks() {
        guard let proposal = status.proposal else { return }
        let blockchains = proposal.requiredNamespaces.map { $0.value }.map { $0.chains }.compactMap { $0 }.reduce([], +)
        let requiedChains = walletConnectModelFactory.resolveChains(for: Set(blockchains), chains: chains)

        router.showMultiSelect(
            canSelect: false,
            dataSource: requiedChains,
            selectedChains: requiedChains.map { $0.chainId },
            moduleOutput: self,
            view: view
        )
    }

    private func showOptionalNetworks() {
        guard let proposal = status.proposal else { return }
        let blockchains = proposal.optionalNamespaces.or([:]).map { $0.value }.map { $0.chains }.compactMap { $0 }.reduce([], +)
        let сhains = walletConnectModelFactory.resolveChains(for: Set(blockchains), chains: chains)

        router.showMultiSelect(
            canSelect: true,
            dataSource: сhains,
            selectedChains: optionalChainsIds,
            moduleOutput: self,
            view: view
        )
    }

    private func showAllDone(description: String) async {
        await MainActor.run {
            view?.didStopLoading()
            router.showAllDone(
                title: R.string.localizable.allDoneAlertAllDoneStub(preferredLanguages: selectedLocale.rLanguages),
                description: description,
                view: view
            ) { [weak self] in
                self?.router.dismiss(view: self?.view)
            }
        }
    }

    private func handle(error: Error) {
        var message = error.localizedDescription
        if let error = error as? JSONRPCError {
            message = error.message
        }
        let viewModel = SheetAlertPresentableViewModel(
            title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: selectedLocale.rLanguages),
            message: message,
            actions: [],
            closeAction: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages)
        ) { [weak self] in
            self?.router.dismiss(view: self?.view)
        }
        DispatchQueue.main.async {
            self.view?.didStopLoading()
            self.router.present(viewModel: viewModel, from: self.view)
        }
    }

    private func setOptionalChains() {
        guard let proposal = status.proposal else { return }
        let optionalBlockchains = proposal.optionalNamespaces.or([:]).map { $0.value }.map { $0.chains }.compactMap { $0 }.reduce([], +)
        let optionalChains = walletConnectModelFactory.resolveChains(for: Set(optionalBlockchains), chains: chains)
        optionalChainsIds = optionalChains.map { $0.chainId }
    }

    private func setLocalWalletsIfNeeded(wallets: [MetaAccountModel]) {
        switch status {
        case let .proposal(proposalVariant):
            switch proposalVariant {
            case .walletConnect:
                self.wallets = wallets
            case .tonConnect:
                self.wallets = wallets.filter { $0.tonAddress != nil }
                if self.wallets.isEmpty {
                    showMissingAccountAlert()
                    return
                }
            case .tonJsBridge:
                self.wallets = [SelectedWalletSettings.shared.value].compactMap { $0 }
            }
        case .active:
            self.wallets = wallets
        }
        provideViewModel()
    }

    private func submitTonJsBridgeApprove(
        manifest: TonConnectManifest,
        params: TonConnectParameters,
        invocationId: String
    ) {
        let dessision: TonConnectDessision = .approve(
            manifest: manifest,
            params: params,
            invocationId: invocationId
        )
        moduleOutput?.tonConnect(dessision: dessision)
        Task { @MainActor in
            router.dismiss(view: view)
        }
    }

    private func confirmTonConnectionRequest(
        manifest: TonConnectManifest,
        params: TonConnectParameters
    ) {
        Task {
            do {
                guard
                    let tonChainModel = self.chains.first(where: { $0.ecosystem == .ton }),
                    let selectedWallet = wallets.filter({ wallet in
                        viewModel?.selectedWalletIds?.contains(wallet.metaId) == true
                    }).first
                else {
                    throw ConvenienceError(error: "Missing ton chain model")
                }
                try await interactor.confirmConnectionRequest(
                    wallet: selectedWallet,
                    tonChainModel: tonChainModel,
                    params: params,
                    manifest: manifest
                )
                Task { @MainActor in
                    router.dismiss(view: view)
                }
            } catch {
                logger.customError(error)
            }
        }
    }

    private func showMissingAccountAlert() {
        Task { @MainActor in
            let title = R.string.localizable.accountNeededTitle(preferredLanguages: selectedLocale.rLanguages)
            let message = R.string.localizable.accountNeededMessage(preferredLanguages: selectedLocale.rLanguages)
            let closeActionTitle = R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages)
            let closeAction = SheetAlertPresentableAction(title: closeActionTitle) { [weak self] in
                self?.router.dismiss(view: self?.view)
            }
            router.present(
                message: message,
                title: title,
                closeAction: nil,
                from: view,
                actions: [closeAction]
            )
        }
    }
}

// MARK: - WalletConnectProposalViewOutput

extension WalletConnectProposalPresenter: WalletConnectProposalViewOutput {
    func viewDidDisappear() {
        view?.controller.onInteractionDismiss()
        Task {
            guard let proposal = status.proposal else { return }
            try? await interactor.submit(proposalDecision: .reject(proposal: proposal))
        }
    }

    func backButtonDidTapped() {
        router.dismiss(view: view)
    }

    func mainActionButtonDidTapped() {
        switch status {
        case let .proposal(connect):
            switch connect {
            case .walletConnect:
                submitWalletConnectApprove()
            case let .tonJsBridge(manifest, payload, invocationId, _):
                submitTonJsBridgeApprove(
                    manifest: manifest,
                    params: payload,
                    invocationId: invocationId
                )
            case let .tonConnect(manifest: manifest, requestPayload: requestPayload):
                confirmTonConnectionRequest(
                    manifest: manifest,
                    params: requestPayload
                )
            }
        case let .active(active):
            switch active {
            case let .walletConnect(session):
                view?.didStartLoading()
                submitDisconnect(topic: session.topic, name: session.peer.name)
            }
        }
    }

    func rejectButtonDidTapped() {
        switch status {
        case let .proposal(connect):
            switch connect {
            case .walletConnect:
                submitReject()
            case let .tonJsBridge(_, _, invocationId, _):
                moduleOutput?.tonConnect(dessision: .reject(invocationId: invocationId))
                router.dismiss(view: view)
            case .tonConnect:
                router.dismiss(view: view)
            }
        case let .active(active):
            switch active {
            case .walletConnect:
                submitReject()
            }
        }
    }

    func didSelectRowAt(_ indexPath: IndexPath) {
        guard let tappedCell = viewModel?.cells[safe: indexPath.row] else {
            return
        }

        switch tappedCell {
        case .dAppInfo:
            break
        case .requiredNetworks:
            showRequiredNetworks()
        case .optionalNetworks:
            showOptionalNetworks()
        case .requiredExpandable, .optionalExpandable, .wallet:
            provideTappedViewModel(at: indexPath)
        }
    }

    func didLoad(view: WalletConnectProposalViewInput) {
        self.view = view
        interactor.setup(with: self)
    }
}

// MARK: - WalletConnectProposalInteractorOutput

extension WalletConnectProposalPresenter: WalletConnectProposalInteractorOutput {
    func didReceive(walletsResult: Result<[MetaAccountModel], Error>) {
        switch walletsResult {
        case let .success(wallets):
            setLocalWalletsIfNeeded(wallets: wallets)
        case let .failure(failure):
            logger.customError(failure)
        }
    }

    func didReceive(chainsResult: Result<[SSFModels.ChainModel], Error>) {
        switch chainsResult {
        case let .success(chains):
            self.chains = chains
            provideViewModel()
        case let .failure(failure):
            logger.customError(failure)
        }
    }
}

// MARK: - Localizable

extension WalletConnectProposalPresenter: Localizable {
    func applyLocalization() {}
}

extension WalletConnectProposalPresenter: WalletConnectProposalModuleInput {}

// MARK: - MultiSelectNetworksModuleOutput

extension WalletConnectProposalPresenter: MultiSelectNetworksModuleOutput {
    func selectedChain(ids: [SSFModels.ChainModel.Id]?) {
        optionalChainsIds = ids
    }
}
