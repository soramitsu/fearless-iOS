import Foundation
import FearlessWalletConnect
import SoraFoundation
import SSFModels

protocol WalletConnectSessionViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(viewModel: WalletConnectSessionViewModel)
}

protocol WalletConnectSessionInteractorInput: AnyObject {
    func setup(with output: WalletConnectSessionInteractorOutput)
    func submit(proposalDecision: WalletConnectProposalDecision) async throws
    func submit(signDecision: WalletConnectSignDecision) async throws
}

final class WalletConnectSessionPresenter {
    private enum Preparation {
        case idle
        case preparing
        case prepared(WalletConnectSigningRequest)
        case declined
    }

    // MARK: Private properties

    private weak var view: WalletConnectSessionViewInput?
    private let router: WalletConnectSessionRouterInput
    private let interactor: WalletConnectSessionInteractorInput
    private let logger: LoggerProtocol

    private let request: Request
    private let session: Session?
    private let viewModelFactory: WalletConnectSessionViewModelFactory
    private let preparer: WalletConnectRequestPreparing

    private var wallets: [MetaAccountModel] = []
    private var chainModels: [ChainModel] = []
    private var balanceInfos: WalletBalanceInfos?
    private var viewModel: WalletConnectSessionViewModel?
    private var preparation: Preparation = .idle

    // MARK: - Constructors

    init(
        request: Request,
        session: Session?,
        viewModelFactory: WalletConnectSessionViewModelFactory,
        preparer: WalletConnectRequestPreparing,
        logger: LoggerProtocol,
        interactor: WalletConnectSessionInteractorInput,
        router: WalletConnectSessionRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.request = request
        self.session = session
        self.viewModelFactory = viewModelFactory
        self.preparer = preparer
        self.interactor = interactor
        self.logger = logger
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        switch preparation {
        case let .prepared(signingRequest):
            let viewModel = viewModelFactory.buildViewModel(
                signingRequest: signingRequest,
                balanceInfo: balanceInfos,
                locale: selectedLocale
            )
            self.viewModel = viewModel
            view?.didReceive(viewModel: viewModel)
        case .idle:
            prepareSigningRequest()
        case .preparing, .declined:
            break
        }
    }

    /// Decodes and checks the request once. Balance updates only refresh the wallet row,
    /// so what the confirmation shows is not quoted again behind the user's back.
    private func prepareSigningRequest() {
        guard chainModels.isNotEmpty, wallets.isNotEmpty else {
            return
        }

        guard let session = session else {
            preparation = .declined
            handle(error: WalletConnectRequestError.accountNotApproved, request: request)
            return
        }

        preparation = .preparing
        let request = request
        let wallets = wallets
        let chains = chainModels
        Task {
            do {
                let signingRequest = try await preparer.prepare(
                    request: request,
                    session: session,
                    wallets: wallets,
                    chains: chains
                )
                await MainActor.run {
                    preparation = .prepared(signingRequest)
                    provideViewModel()
                }
            } catch {
                await MainActor.run {
                    preparation = .declined
                    handle(error: error, request: request)
                }
            }
        }
    }

    private func sumbitReject(request: Request, error: JSONRPCError) {
        Task {
            do {
                try await interactor.submit(signDecision: .rejected(request: request, error: error))
            } catch {
                logger.customError(error)
            }
        }
    }

    private func prepareConfirmationData() {
        guard let session = session, case let .prepared(signingRequest) = preparation else {
            view?.didStopLoading()
            return
        }

        let inputData = WalletConnectConfirmationInputData(
            signingRequest: signingRequest,
            session: session
        )
        view?.didStopLoading()
        router.showConfirmation(inputData: inputData)
    }

    private func handle(error: Error, request: Request?) {
        logger.customError(error)
        view?.didStopLoading()

        let title: String
        let message: String
        if let content = (error as? ErrorContentConvertible)?.toErrorContent(for: selectedLocale) {
            title = content.title
            message = content.message
        } else {
            title = "\(error._code)"
            message = error.localizedDescription
        }

        let viewModel = SheetAlertPresentableViewModel(
            title: title,
            message: message,
            actions: [],
            closeAction: nil
        ) { [weak self] in
            self?.router.dismiss(view: self?.view)
        }
        router.present(viewModel: viewModel, from: view)

        guard let request = request else {
            return
        }
        if let error = error as? WalletConnectRequestError {
            sumbitReject(request: request, error: error.rpcError)
        } else if let error = error as? JSONRPCError {
            sumbitReject(request: request, error: error)
        } else {
            let error = JSONRPCError(
                code: error._code,
                message: error.localizedDescription
            )
            sumbitReject(request: request, error: error)
        }
    }
}

// MARK: - WalletConnectSessionViewOutput

extension WalletConnectSessionPresenter: WalletConnectSessionViewOutput {
    func viewDidDisappear() {
        view?.controller.onInteractionDismiss()
        sumbitReject(request: request, error: JSONRPCError.userRejected)
    }

    func closeButtonDidTapped() {
        router.dismiss(view: view)
    }

    func actionButtonDidTapped() {
        view?.didStartLoading()
        prepareConfirmationData()
    }

    func didLoad(view: WalletConnectSessionViewInput) {
        self.view = view
        interactor.setup(with: self)
    }
}

// MARK: - WalletConnectSessionInteractorOutput

extension WalletConnectSessionPresenter: WalletConnectSessionInteractorOutput {
    func didReceive(chainsResult: Result<[SSFModels.ChainModel], Error>) {
        switch chainsResult {
        case let .success(chains):
            chainModels = chains
            provideViewModel()
        case let .failure(failure):
            logger.customError(failure)
        }
    }

    func didReceiveBalance(result: WalletBalancesResult) {
        switch result {
        case let .success(infos):
            balanceInfos = infos
            provideViewModel()
        case let .failure(error):
            logger.customError(error)
        }
    }

    func didReceive(walletsResult: Result<[MetaAccountModel], Error>) {
        switch walletsResult {
        case let .success(wallet):
            wallets = wallet
            provideViewModel()
        case let .failure(failure):
            logger.customError(failure)
        }
    }
}

// MARK: - Localizable

extension WalletConnectSessionPresenter: Localizable {
    func applyLocalization() {}
}

extension WalletConnectSessionPresenter: WalletConnectSessionModuleInput {}
