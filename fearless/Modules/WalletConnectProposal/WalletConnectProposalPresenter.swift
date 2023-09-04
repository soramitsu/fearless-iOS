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
}

final class WalletConnectProposalPresenter {
    // MARK: Private properties

    private weak var view: WalletConnectProposalViewInput?
    private let router: WalletConnectProposalRouterInput
    private let interactor: WalletConnectProposalInteractorInput

    private let walletConnectModelFactory: WalletConnectModelFactory
    private let viewModelFactory: WalletConnectProposalViewModelFactory
    private let proposal: Session.Proposal
    private let logger: LoggerProtocol

    private var viewModel: WalletConnectProposalViewModel?
    private var wallets: [MetaAccountModel] = []
    private var chains: [ChainModel] = []
    private var optionalChainsIds: [ChainModel.Id]?

    // MARK: - Constructors

    init(
        proposal: Session.Proposal,
        walletConnectModelFactory: WalletConnectModelFactory,
        viewModelFactory: WalletConnectProposalViewModelFactory,
        logger: LoggerProtocol,
        interactor: WalletConnectProposalInteractorInput,
        router: WalletConnectProposalRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.proposal = proposal
        self.walletConnectModelFactory = walletConnectModelFactory
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        guard chains.isNotEmpty, wallets.isNotEmpty else {
            return
        }
        do {
            let viewModel = try viewModelFactory.buildViewModel(
                proposal: proposal,
                chains: chains,
                wallets: wallets
            )
            DispatchQueue.main.async {
                self.view?.didReceive(viewModel: viewModel)
            }
            self.viewModel = viewModel
        } catch {
            print(error)
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
                try await interactor.submit(proposalDecision: .reject(proposal: proposal))
            } catch {
                logger.customError(error)
            }
        }
    }

    private func submitApprove() {
        Task {
            do {
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
                await showAllDone()
            } catch {
                logger.customError(error)
                await MainActor.run {
                    view?.didStopLoading()
                    let convinienceError = ConvenienceError(error: error.localizedDescription)
                    router.present(error: convinienceError, from: view, locale: selectedLocale)
                }
            }
        }
    }

    private func showRequiredNetworks() {
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
        let blockchains = proposal.optionalNamespaces.or([:]).map { $0.value }.map { $0.chains }.compactMap { $0 }.reduce([], +)
        let requiedChains = walletConnectModelFactory.resolveChains(for: Set(blockchains), chains: chains)

        router.showMultiSelect(
            canSelect: true,
            dataSource: requiedChains,
            selectedChains: [],
            moduleOutput: self,
            view: view
        )
    }

    private func showAllDone() async {
        await MainActor.run {
            view?.didStopLoading()
            router.showAllDone(
                title: "All Done",
                description: "You can now back to your browser",
                view: view
            ) { [weak self] in
                self?.router.dismiss(view: self?.view)
            }
        }
    }
}

// MARK: - WalletConnectProposalViewOutput

extension WalletConnectProposalPresenter: WalletConnectProposalViewOutput {
    func viewDidDisappear() {
        Task {
            try? await interactor.submit(proposalDecision: .reject(proposal: proposal))
        }
    }

    func backButtonDidTapped() {
        router.dismiss(view: view)
    }

    func approveButtonDidTapped() {
        submitApprove()
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
        provideViewModel()
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
