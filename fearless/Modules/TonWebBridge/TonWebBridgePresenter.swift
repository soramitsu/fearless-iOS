import Foundation
import WebKit
import SoraFoundation
import SSFModels
import TonSwift

protocol TonWebBridgeViewInput: ControllerBackedProtocol {
    func evaulateJavaScript(_ javaScript: String) async throws
    func didReceive(configuration: WKWebViewConfiguration)
}

protocol TonWebBridgeInteractorInput: AnyObject {
    func setup(with output: TonWebBridgeInteractorOutput)
    func fetchManifest(with url: URL) async throws -> TonConnectManifest
    func getTonChain() async throws -> ChainModel?
    func connected(app: TonConnectApp) async
    func disconnected(app: TonConnectApp) async
    func getConnectedApp(for wallet: MetaAccountModel) async throws -> [TonConnectApp]
}

final class TonWebBridgePresenter: NSObject {
    // MARK: Private properties

    private weak var view: TonWebBridgeViewInput?
    private weak var moduleOutput: TonWebBridgeModuleOutput?
    private let router: TonWebBridgeRouterInput
    private let interactor: TonWebBridgeInteractorInput
    private let logger: LoggerProtocol
    private let coordinator = WalletConnectCoordinator.shared

    private var dapp: TonDapp
    private let wallet: MetaAccountModel
    private lazy var userContentController = WKUserContentController()
    private let messageBuilder: TonWebBridgeMessagesBuilder

    // MARK: - Constructors

    init(
        dapp: TonDapp,
        wallet: MetaAccountModel,
        messageBuilder: TonWebBridgeMessagesBuilder,
        interactor: TonWebBridgeInteractorInput,
        router: TonWebBridgeRouterInput,
        logger: LoggerProtocol,
        moduleOutput: TonWebBridgeModuleOutput?,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.dapp = dapp
        self.wallet = wallet
        self.messageBuilder = messageBuilder
        self.interactor = interactor
        self.router = router
        self.logger = logger
        self.moduleOutput = moduleOutput
        super.init()
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideWebViewConfiguration() {
        let configuration = messageBuilder.getConfiguration(
            userContentController: userContentController
        )
        view?.didReceive(configuration: configuration)
    }

    private func setBridgeMessage() {
        userContentController.add(self, name: "dapp")
    }

    // TODO: - Check is connected
    private func reconnectToAppIfAlreadyConnected(
        invocationId: String
    ) async throws {
        let apps = try await interactor.getConnectedApp(for: wallet)
        guard apps.first(where: { $0.appUrl.host == dapp.url.host }) != nil else {
            let error: TonConnect.ConnectEventError.Error = .unknownError
            let response = DappBridgeResponse(
                invocationId: invocationId,
                status: .rejected,
                data: .error(error.rawValue)
            )
            try await sendResponse(response)
            return
        }

        let string = try messageBuilder.getConnectEventSuccess(wallet: wallet)
        let response = DappBridgeResponse(
            invocationId: invocationId,
            status: .fulfilled,
            data: .data(string)
        )
        try await sendResponse(response)
    }

    // MARK: Private handle methods

    private func handleMessage(
        body: Any
    ) async throws {
        let invokeMessage = try messageBuilder.getDappFunctionInvokeMessage(from: body)

        switch invokeMessage.type {
        case .send:
            try await handleSend(message: invokeMessage)
        case .connect:
            try await handleConnect(message: invokeMessage)
        case .restoreConnection:
            try await reconnectToAppIfAlreadyConnected(
                invocationId: invokeMessage.invocationId
            )
        case .disconnect:
            try await handleDisconnect()
        }
    }

    private func handleSend(
        message: DappFunctionInvokeMessage
    ) async throws {
        let appRequest = try messageBuilder.getTonConnectAppRequest(from: message)
        coordinator.send(
            request: appRequest,
            invocationId: message.invocationId,
            wallet: wallet,
            dapp: dapp,
            delegate: self
        )
    }

    private func handleConnect(
        message: DappFunctionInvokeMessage
    ) async throws {
        let payload = try messageBuilder.getTonConnectRequestPayload(from: message)
        let manifest = try await interactor.fetchManifest(with: payload.manifestUrl)
        let parameters = TonConnectParameters(
            version: .v2,
            clientId: UUID().uuidString,
            requestPayload: payload
        )
        coordinator.suggestConnect(
            manifest: manifest,
            requestPayload: parameters,
            invocationId: message.invocationId,
            delegate: self
        )
    }

    private func handleDisconnect() async throws {
        let apps = try await interactor.getConnectedApp(for: wallet)
        guard let connectedApp = apps.first(where: { $0.appUrl.host == dapp.url.host }) else {
            logger.error("Connected app not found")
            return
        }
        await interactor.disconnected(app: connectedApp)
        moduleOutput?.didDisconnect()
    }

    private func handleSendMessage(
        result: TonConnect.SendTransactionResponse,
        invocationId: String
    ) async throws {
        let responseData = try JSONEncoder().encode(result)
        guard let string = String(data: responseData, encoding: .utf8) else {
            throw ConvenienceError(error: "Response data encoding error")
        }

        let response = DappBridgeResponse(
            invocationId: invocationId,
            status: .fulfilled,
            data: .data(string)
        )
        try await sendResponse(response)
    }

    // MARK: - Private send actions

    private func sendResponse(
        _ response: DappBridgeResponse
    ) async throws {
        guard let responseJson = response.json else { return }
        let js = """
        (function() {
            window.dispatchEvent(new MessageEvent('message', {
                data: \(responseJson)
            }));
        })();
        """
        try await view?.evaulateJavaScript(js)
    }

    private func sendApprove(
        manifest: TonConnectManifest,
        params: TonConnectParameters,
        invocationId: String
    ) async throws {
        guard let tonChainModel = try await interactor.getTonChain() else {
            throw ConvenienceError(error: "Missing Ton Chain Model")
        }
        let responseString: String = try messageBuilder.getConnectEventSuccesResponse(
            requestPayloadItems: params.requestPayload.items,
            wallet: wallet,
            manifest: manifest,
            tonChainModel: tonChainModel
        )

        let response = DappBridgeResponse(
            invocationId: invocationId,
            status: .fulfilled,
            data: .data(responseString)
        )
        try await sendResponse(response)

        let sessionCrypto = try TonConnectSessionCrypto()
        let connectedApp = TonConnectApp(
            walletId: wallet.metaId,
            clientId: params.clientId,
            appUrl: manifest.url,
            publicKey: sessionCrypto.keyPair.publicKey.data,
            privateKey: sessionCrypto.keyPair.privateKey.data
        )
        await interactor.connected(app: connectedApp)
    }

    private func sendReject(
        invocationId: String,
        error: Int
    ) async throws {
        let response = DappBridgeResponse(
            invocationId: invocationId,
            status: .rejected,
            data: .error(error)
        )
        try await sendResponse(response)
    }
}

// MARK: - TonWebBridgeViewOutput

extension TonWebBridgePresenter: TonWebBridgeViewOutput {
    func didLoadInitialURL() {
        Task {
            do {
                try await reconnectToAppIfAlreadyConnected(invocationId: "")
            } catch {
                logger.customError(error)
            }
        }
    }

    func didLoad(view: TonWebBridgeViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideWebViewConfiguration()
        setBridgeMessage()
    }
}

// MARK: - TonWebBridgeInteractorOutput

extension TonWebBridgePresenter: TonWebBridgeInteractorOutput {}

// MARK: - Localizable

extension TonWebBridgePresenter: Localizable {
    func applyLocalization() {}
}

extension TonWebBridgePresenter: TonWebBridgeModuleInput {}

// MARK: - WKScriptMessageHandler

extension TonWebBridgePresenter: WKScriptMessageHandler {
    public func userContentController(
        _: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        Task { @MainActor in
            do {
                try await handleMessage(body: message.body)
            } catch {
                logger.customError(error)
            }
        }
    }
}

// MARK: - WalletConnectProposalModuleOutput

extension TonWebBridgePresenter: WalletConnectProposalModuleOutput {
    func tonConnect(dessision: TonConnectDessision) {
        Task {
            do {
                switch dessision {
                case let .approve(manifest, params, invocationId):
                    try await sendApprove(
                        manifest: manifest,
                        params: params,
                        invocationId: invocationId
                    )
                case let .reject(invocationId):
                    let error: TonConnect.ConnectEventError.Error = .unknownApp
                    try await sendReject(
                        invocationId: invocationId,
                        error: error.rawValue
                    )
                    try await handleDisconnect()
                }
            } catch {
                logger.customError(error)
            }
        }
    }
}

// MARK: - WalletConnectSessionModuleOutput

extension TonWebBridgePresenter: WalletConnectSessionModuleOutput {
    func tonConnectSend(dessision: TonConnectSendDessision) {
        Task {
            do {
                switch dessision {
                case let .sended(invocationId, sendTransactionResponse):
                    try await handleSendMessage(
                        result: sendTransactionResponse,
                        invocationId: invocationId
                    )
                case let .declined(invocationId):
                    let declineError: TonConnect.SendTransactionResponseError.ErrorCode = .userDeclinedTransaction
                    try await sendReject(
                        invocationId: invocationId,
                        error: declineError.rawValue
                    )
                case let .error(invocationId, errorCode):
                    try await sendReject(
                        invocationId: invocationId,
                        error: errorCode.rawValue
                    )
                }
            } catch {
                logger.customError(error)
            }
        }
    }
}
