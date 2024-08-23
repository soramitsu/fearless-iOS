import Foundation
import WalletConnectSign
import SoraFoundation
import SSFModels

protocol WalletConnectSessionViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(viewModel: WalletConnectSessionViewModel)
}

protocol WalletConnectSessionInteractorInput: AnyObject {
    func setup(with output: WalletConnectSessionInteractorOutput)
    func submit(proposalDecision: WalletConnectProposalDecision) async throws
    func submit(signDecision: WalletConnectSignDecision) async throws
    func cancelTonConnect(
        appRequest: TonConnect.AppRequest,
        app: TonConnectApp
    ) async throws
}

final class WalletConnectSessionPresenter {
    // MARK: Private properties

    private weak var view: WalletConnectSessionViewInput?
    private weak var moduleOutput: WalletConnectSessionModuleOutput?
    private let router: WalletConnectSessionRouterInput
    private let interactor: WalletConnectSessionInteractorInput
    private let logger: LoggerProtocol

    private let variant: ConnectRequestVariant
    private let viewModelFactory: WalletConnectSessionViewModelFactory
    private let walletConnectModelFactory: WalletConnectModelFactory

    private var wallets: [MetaAccountModel] = []
    private var chainModels: [ChainModel] = []
    private var balanceInfos: WalletBalanceInfos?
    private var viewModel: WalletConnectSessionViewModel?

    // MARK: - Constructors

    init(
        variant: ConnectRequestVariant,
        viewModelFactory: WalletConnectSessionViewModelFactory,
        walletConnectModelFactory: WalletConnectModelFactory,
        logger: LoggerProtocol,
        interactor: WalletConnectSessionInteractorInput,
        router: WalletConnectSessionRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        moduleOutput = variant.moduleOutput
        self.variant = variant
        self.viewModelFactory = viewModelFactory
        self.walletConnectModelFactory = walletConnectModelFactory
        self.interactor = interactor
        self.logger = logger
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        guard chainModels.isNotEmpty, wallets.isNotEmpty else {
            return
        }
        Task {
            do {
                let viewModel = try await viewModelFactory.buildViewModel(
                    wallets: wallets,
                    chains: chainModels,
                    balanceInfo: balanceInfos,
                    locale: selectedLocale
                )

                await MainActor.run {
                    view?.didReceive(viewModel: viewModel)
                    self.viewModel = viewModel
                }

            } catch {
                await MainActor.run(body: {
                    switch variant {
                    case let .walletConnect(request, _):
                        handle(error: error, request: request)
                    case .tonJsBridge, .tonConnect:
                        logger.customError(error)
                    }
                })
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
        do {
            switch variant {
            case let .walletConnect(request, session):
                try prepereWalletConnectConfirmData(
                    request: request,
                    session: session
                )
            case let .tonJsBridge(invocationId, wallet, dapp, request, delegate):
                try prepareTonJsBridgConfirmData(
                    invocationId: invocationId,
                    wallet: wallet,
                    dapp: dapp,
                    request: request
                )
            case let .tonConnect(request: request, walletId: walletId, app: app):
                try prepareTonConnectConfirmData(
                    request: request,
                    walletId: walletId,
                    app: app
                )
            }
        } catch {
            switch variant {
            case let .walletConnect(request, _):
                handle(error: error, request: request)
            case .tonJsBridge, .tonConnect:
                logger.customError(error)
            }
        }
    }

    private func prepereWalletConnectConfirmData(
        request: Request,
        session: Session?
    ) throws {
        let chain = try walletConnectModelFactory.resolveChain(for: request.chainId, chains: chainModels)
        let method = try walletConnectModelFactory.parseMethod(from: request)
        guard
            let session = session,
            let viewModel = viewModel
        else {
            throw JSONRPCError.invalidRequest
        }

        let inputData = WalletConnectConfirmationInputData(
            wallet: viewModel.wallet,
            chain: chain,
            variant: .walletConnect(
                resuest: request,
                session: session,
                method: method
            ),
            payload: viewModel.payload
        )
        view?.didStopLoading()
        router.showConfirmation(inputData: inputData)
    }

    private func prepareTonJsBridgConfirmData(
        invocationId: String,
        wallet: MetaAccountModel,
        dapp: TonDapp,
        request: TonConnect.AppRequest
    ) throws {
        guard let chain = chainModels.first(where: { $0.ecosystem == .ton }) else {
            throw ConvenienceError(error: "Missing Ton ChainModel")
        }
        guard let payload = viewModel?.payload else {
            return
        }
        let inputData = WalletConnectConfirmationInputData(
            wallet: wallet,
            chain: chain,
            variant: .tonJsBridge(
                invocationId: invocationId,
                dapp: dapp,
                request: request,
                moduleOutput: moduleOutput
            ),
            payload: payload
        )
        view?.didStopLoading()
        router.showConfirmation(inputData: inputData)
    }

    private func prepareTonConnectConfirmData(
        request: TonConnect.AppRequest,
        walletId: SSFModels.MetaAccountId,
        app: TonConnectApp
    ) throws {
        guard
            let wallet = wallets.first(where: { $0.metaId == walletId }),
            let chain = chainModels.first(where: { $0.ecosystem == .ton }),
            let payload = viewModel?.payload
        else {
            throw ConvenienceError(error: "Missing wallet or chain")
        }

        let inputData = WalletConnectConfirmationInputData(
            wallet: wallet,
            chain: chain,
            variant: .tonConnect(
                request: request,
                app: app
            ),
            payload: payload
        )
        view?.didStopLoading()
        router.showConfirmation(inputData: inputData)
    }

    private func handle(error: Error, request: Request?) {
        logger.customError(error)
        view?.didStopLoading()

        let viewModel = SheetAlertPresentableViewModel(
            title: "\(error._code)",
            message: error.localizedDescription,
            actions: [],
            closeAction: nil
        ) { [weak self] in
            self?.router.dismiss(view: self?.view)
        }
        router.present(viewModel: viewModel, from: view)

        guard let request = request else {
            return
        }
        if let error = error as? JSONRPCError {
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
        switch variant {
        case let .walletConnect(request, _):
            sumbitReject(request: request, error: JSONRPCError.userRejected)
        case let .tonJsBridge(invocationId, _, _, _, _):
            moduleOutput?.tonConnectSend(
                dessision: .declined(
                    invocationId: invocationId
                )
            )
        case let .tonConnect(request: request, walletId: walletId, app: app):
            Task {
                try await interactor.cancelTonConnect(
                    appRequest: request,
                    app: app
                )
            }
        }
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
