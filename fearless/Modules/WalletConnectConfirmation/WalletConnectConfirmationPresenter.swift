import Foundation
import SoraFoundation

protocol WalletConnectConfirmationViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(viewModel: WalletConnectConfirmationViewModel)
}

protocol WalletConnectConfirmationInteractorInput: AnyObject {
    func setup(with output: WalletConnectConfirmationInteractorOutput)
    func approve() async throws -> String?
    func cancelTonConnect(
        appRequest: TonConnect.AppRequest,
        app: TonConnectApp
    ) async throws
}

final class WalletConnectConfirmationPresenter {
    // MARK: Private properties

    private weak var moduleOutput: WalletConnectSessionModuleOutput?
    private weak var view: WalletConnectConfirmationViewInput?
    private let router: WalletConnectConfirmationRouterInput
    private let interactor: WalletConnectConfirmationInteractorInput

    private let inputData: WalletConnectConfirmationInputData
    private let viewModelFactory: WalletConnectConfirmationViewModelFactory

    // MARK: - Constructors

    init(
        inputData: WalletConnectConfirmationInputData,
        viewModelFactory: WalletConnectConfirmationViewModelFactory,
        interactor: WalletConnectConfirmationInteractorInput,
        router: WalletConnectConfirmationRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        moduleOutput = inputData.moduleOutput
        self.inputData = inputData
        self.viewModelFactory = viewModelFactory
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let viewModel = viewModelFactory.buildViewModel()
        view?.didReceive(viewModel: viewModel)
    }

    private func showAllDone(hash: String?) {
        router.showAllDone(
            chain: inputData.chain,
            hashString: hash,
            view: view
        ) { [weak self, weak view] in
            self?.router.dismiss(view: self?.view)
            view?.controller.onInteractionDismiss()
        }
    }

    private func show(error: Error) {
        guard let view = view else {
            return
        }
        router.presentError(
            for: "",
            message: "\(error)",
            view: view,
            locale: selectedLocale
        )
    }

    private func approveWalletConnect() async throws {
        let hash = try await interactor.approve()
        Task { @MainActor in
            showAllDone(hash: hash)
            view?.didStopLoading()
        }
    }

    private func approveTonJsBridge(
        requestId: String,
        invocationId: String
    ) async throws {
        guard let boc = try await interactor.approve() else {
            throw ConvenienceError(error: "Send boc ton connect error")
        }
        let response: TonConnect.SendTransactionResponse = .success(
            TonConnect.SendTransactionResponseSuccess(
                result: boc,
                id: requestId
            )
        )
        moduleOutput?.tonConnectSend(
            dessision: .sended(
                invocationId: invocationId,
                response: response
            )
        )
        Task { @MainActor in
            router.dismiss(view: view)
            view?.controller.onInteractionDismiss()
        }
    }

    private func approveTonConnect() async throws {
        _ = try await interactor.approve()
        Task { @MainActor in
            router.dismiss(view: view)
            view?.controller.onInteractionDismiss()
        }
    }

    private func handleWalletConnect(error: Error) {
        Task { @MainActor in
            view?.didStopLoading()
            show(error: error)
        }
    }

    private func handleTonJsBridge(
        error: Error,
        invocationId: String
    ) {
        moduleOutput?.tonConnectSend(
            dessision: .error(
                invocationId: invocationId,
                error: .unknownError
            )
        )
        Task { @MainActor in
            view?.didStopLoading()
            show(error: error)
        }
    }

    private func cancelTonConnect(
        appRequest: TonConnect.AppRequest,
        app: TonConnectApp
    ) async {
        do {
            try await interactor.cancelTonConnect(
                appRequest: appRequest,
                app: app
            )
        } catch {
            show(error: error)
        }
    }
}

// MARK: - WalletConnectConfirmationViewOutput

extension WalletConnectConfirmationPresenter: WalletConnectConfirmationViewOutput {
    func backButtonDidTapped() {
        router.dismiss(view: view)
    }

    func rawDataDidTapped() {
        router.showRawData(json: inputData.payload.txDetails, from: view)
    }

    func confirmDidTapped() {
        view?.didStartLoading()
        Task {
            do {
                switch inputData.variant {
                case .walletConnect:
                    try await approveWalletConnect()
                case let .tonJsBridge(invocationId, _, request, _):
                    try await approveTonJsBridge(requestId: request.id, invocationId: invocationId)
                case let .tonConnect(request: request, app: app):
                    try await approveTonConnect()
                }
            } catch {
                switch inputData.variant {
                case .walletConnect:
                    handleWalletConnect(error: error)
                case let .tonJsBridge(invocationId, _, _, _):
                    handleTonJsBridge(
                        error: error,
                        invocationId: invocationId
                    )
                case let .tonConnect(request: request, app: app):
                    await cancelTonConnect(appRequest: request, app: app)
                }
            }
        }
    }

    func didLoad(view: WalletConnectConfirmationViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideViewModel()
    }
}

// MARK: - WalletConnectConfirmationInteractorOutput

extension WalletConnectConfirmationPresenter: WalletConnectConfirmationInteractorOutput {}

// MARK: - Localizable

extension WalletConnectConfirmationPresenter: Localizable {
    func applyLocalization() {}
}

extension WalletConnectConfirmationPresenter: WalletConnectConfirmationModuleInput {}
