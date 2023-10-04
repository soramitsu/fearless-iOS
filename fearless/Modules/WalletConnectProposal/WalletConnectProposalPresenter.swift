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
}

final class WalletConnectProposalPresenter {
    // MARK: Private properties

    private weak var view: WalletConnectProposalViewInput?
    private let router: WalletConnectProposalRouterInput
    private let interactor: WalletConnectProposalInteractorInput

    private let status: SessionStatus
    private let walletConnectModelFactory: WalletConnectModelFactory
    private let viewModelFactory: WalletConnectProposalViewModelFactory
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
        logger: LoggerProtocol,
        interactor: WalletConnectProposalInteractorInput,
        router: WalletConnectProposalRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.status = status
        self.walletConnectModelFactory = walletConnectModelFactory
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        switch status {
        case let .proposal(proposal):
            provideProposalSessionViewModel(proposal: proposal)
        case let .active(session):
            provideActiveSessionViewModel(session: session)
        }
    }

    private func provideProposalSessionViewModel(proposal: Session.Proposal) {
        guard chains.isNotEmpty, wallets.isNotEmpty else {
            return
        }
        do {
            let viewModel = try viewModelFactory.buildProposalSessionViewModel(
                proposal: proposal,
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

    private func provideActiveSessionViewModel(session: Session) {
        guard chains.isNotEmpty, wallets.isNotEmpty else {
            return
        }
        do {
            let viewModel = try viewModelFactory.buildActiveSessionViewModel(
                session: session,
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
                await showAllDone(description: "Rejected")
            } catch {
                logger.customError(error)
                handle(error: error)
            }
        }
    }

    private func submitApprove() {
        Task {
            do {
                guard let proposal = status.proposal else { return }
                let selectedWallets = wallets.filter { wallet in
                    viewModel?.selectedWalletIds.contains(wallet.metaId) == true
                }
                let namespaces = try walletConnectModelFactory.createSessionNamespaces(
                    from: proposal,
                    wallets: selectedWallets,
                    chains: chains,
                    optionalChainIds: optionalChainsIds
                )
                try await interactor.submit(proposalDecision: .approve(proposal: proposal, namespaces: namespaces))
                await showAllDone(description: "You can now back to your browser")
            } catch {
                logger.customError(error)
                handle(error: error)
            }
        }
    }

    private func submitDisconnect(topic: String) {
        Task {
            do {
                try await interactor.submitDisconnect(topic: topic)
                await showAllDone(description: "Disconnection from React App with ethers has been successfully completed")
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
        let requiedChains = walletConnectModelFactory.resolveChains(for: Set(blockchains), chains: chains)

        router.showMultiSelect(
            canSelect: true,
            dataSource: requiedChains,
            selectedChains: optionalChainsIds,
            moduleOutput: self,
            view: view
        )
    }

    private func showAllDone(description: String) async {
        await MainActor.run {
            view?.didStopLoading()
            router.showAllDone(
                title: "All Done",
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
            closeAction: nil
        ) { [weak self] in
            self?.router.dismiss(view: self?.view)
        }
        DispatchQueue.main.async {
            self.view?.didStopLoading()
            self.router.present(viewModel: viewModel, from: self.view)
        }
    }
}

// MARK: - WalletConnectProposalViewOutput

extension WalletConnectProposalPresenter: WalletConnectProposalViewOutput {
    func viewDidDisappear() {
        Task {
            guard let proposal = status.proposal else { return }
            try? await interactor.submit(proposalDecision: .reject(proposal: proposal))
        }
    }

    func backButtonDidTapped() {
        router.dismiss(view: view)
    }

    func mainActionButtonDidTapped() {
        view?.didStartLoading()
        switch status {
        case .proposal:
            submitApprove()
        case let .active(session):
            submitDisconnect(topic: session.topic)
        }
    }

    func rejectButtonDidTapped() {
        submitReject()
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
            self.wallets = wallets
            provideViewModel()
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

extension WalletConnectProposalPresenter {
    enum SessionStatus {
        case proposal(Session.Proposal)
        case active(Session)

        var proposal: Session.Proposal? {
            switch self {
            case let .proposal(proposal):
                return proposal
            case .active:
                return nil
            }
        }

        var session: Session? {
            switch self {
            case .proposal:
                return nil
            case let .active(session):
                return session
            }
        }
    }
}
