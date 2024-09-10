import Foundation
import SSFTransferService
import SSFNetwork
import SSFModels
import TonConnectAPI
import RobinHood
import TonSwift

enum TonConnectServiceError: Swift.Error {
    case incorrectUrl
    case incorrectClientId
}

actor TonConnectServiceImpl: TonConnectService {
    private let chainRegistry: ChainRegistryProtocol
    private let tonService: TonSendService
    private let networkWorker: SSFNetwork.NetworkWorker
    private let messageBuilder: TonConnectMessageBuilder
    private let appRepository: AsyncAnyRepository<TonConnectApp>
    private let eventCenter: TonConnectEventsCenter
    private let logger: LoggerProtocol

    private var listeners: [WeakWrapper] = []

    init(
        chainRegistry: ChainRegistryProtocol,
        tonService: TonSendService,
        networkWorker: SSFNetwork.NetworkWorker,
        messageBuilder: TonConnectMessageBuilder,
        appRepository: AsyncAnyRepository<TonConnectApp>,
        eventCenter: TonConnectEventsCenter,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.tonService = tonService
        self.networkWorker = networkWorker
        self.messageBuilder = messageBuilder
        self.appRepository = appRepository
        self.eventCenter = eventCenter
        self.logger = logger
    }

    // MARK: - TonConnectService

    func set(listener: TonConnectServiceDelegate) async {
        let weakListener = WeakWrapper(target: listener)
        listeners.append(weakListener)
    }

    func establishConnection(with uri: String) async throws {
        let config = try getConfig(uri)
        let manifest = try await fetchManifest(with: config.requestPayload.manifestUrl)

        listeners.forEach {
            ($0.target as? TonConnectServiceDelegate)?.suggestConnect(
                manifest: manifest,
                requestPayload: config,
                invocationId: nil,
                delegate: nil
            )
        }
    }

    func fetchManifest(with url: URL) async throws -> TonConnectManifest {
        let request = SSFNetwork.RequestConfig(
            baseURL: url,
            method: .get,
            endpoint: nil,
            headers: nil,
            body: nil
        )
        let manifest: TonConnectManifest = try await networkWorker.performRequest(with: request)
        return manifest
    }

    func confirmConnectionRequest(
        wallet: MetaAccountModel,
        tonChainModel: ChainModel,
        params: TonConnectParameters,
        manifest: TonConnectManifest
    ) async throws {
        let connectSuccessResponseEvent: TonConnect.ConnectEventSuccess = try messageBuilder.getConnectEventSuccessResponse(
            requestPayloadItems: params.requestPayload.items,
            wallet: wallet,
            manifest: manifest,
            tonChainModel: tonChainModel
        )

        let sessionCrypto = try TonConnectSessionCrypto()
        let encrypted = try messageBuilder.encryptSuccessResponse(
            successResponse: connectSuccessResponseEvent,
            clientId: params.clientId,
            sessionCrypto: sessionCrypto
        )

        try await sendMessageConfirmConnectionRequest(
            body: encrypted,
            sessionCrypto: sessionCrypto,
            parameters: params
        )

        await saveToStore(
            wallet: wallet,
            clientId: params.clientId,
            appUrl: manifest.url,
            sessionCrypto: sessionCrypto,
            name: manifest.name,
            iconUrl: manifest.iconUrl
        )
        await updateEventCenter()
    }

    func cancelRequest(
        appRequest: TonConnect.AppRequest,
        app: TonConnectApp
    ) async throws {
        let apiClient = try chainRegistry.getTonApiAssembly().tonConnectAPIClient()
        let sessionCrypto = try TonConnectSessionCrypto(privateKey: app.keyPair.privateKey)
        let body = try messageBuilder.buildSendTransactionResponseError(
            sessionCrypto: sessionCrypto,
            errorCode: .userDeclinedTransaction,
            id: appRequest.id,
            clientId: app.clientId
        )
        _ = try await apiClient.message(
            query: .init(
                client_id: sessionCrypto.sessionId,
                to: app.clientId,
                ttl: 300
            ),
            body: .plainText(.init(stringLiteral: body))
        )
    }

    func approveTonJsBridgeSend(
        wallet: MetaAccountModel,
        parameter: SendTransactionParam
    ) async throws -> String {
        guard
            let sender = wallet.tonAddress,
            let walletContract = wallet.tonWalletContract()
        else {
            throw ConvenienceError(error: "Missing Ton params")
        }
        async let seqno = try tonService.loadSeqno(address: sender.toRaw())
        async let timeout = tonService.getTimeoutSafely(TTL: 5 * 60)

        let bocFactory = try createBocFactory(for: wallet)
        let boc = try await bocFactory.createTonConnectTransferBoc(
            sender: sender,
            contract: walletContract,
            parameter: parameter,
            seqno: seqno,
            timeout: timeout
        )

        try await tonService.sendTransaction(boc: boc)
        return boc
    }

    func confirmTonConnectRequest(
        wallet: MetaAccountModel,
        appRequest: TonConnect.AppRequest,
        app: TonConnectApp,
        parameter: SendTransactionParam
    ) async throws {
        guard
            let sender = wallet.tonAddress,
            let walletContract = wallet.tonWalletContract()
        else {
            throw ConvenienceError(error: "Missing Ton params")
        }
        let sessionCrypto = try TonConnectSessionCrypto(privateKey: app.keyPair.privateKey)
        async let seqno = try tonService.loadSeqno(address: sender.toRaw())
        async let timeout = tonService.getTimeoutSafely(TTL: 5 * 60)

        let bocFactory = try createBocFactory(for: wallet)
        let boc = try await bocFactory.createTonConnectTransferBoc(
            sender: sender,
            contract: walletContract,
            parameter: parameter,
            seqno: seqno,
            timeout: timeout
        )
        try await tonService.sendTransaction(boc: boc)

        let body = try messageBuilder.buildSendTransactionResponseSuccess(
            sessionCrypto: sessionCrypto,
            boc: boc,
            id: appRequest.id,
            clientId: app.clientId
        )

        let apiClient = try chainRegistry.getTonApiAssembly().tonConnectAPIClient()
        _ = try await apiClient.message(
            query: .init(
                client_id: sessionCrypto.sessionId,
                to: app.clientId,
                ttl: 300
            ),
            body: .plainText(.init(stringLiteral: body))
        )
    }

    func getConnectedApp(for wallet: MetaAccountModel) async throws -> [TonConnectApp] {
        let apps = try await appRepository.fetchAll()
        let walletApps = apps.filter { $0.walletId == wallet.metaId }
        return walletApps
    }

    func saveConnected(app: TonConnectApp) async {
        await appRepository.save(models: [app])
        await updateEventCenter()
    }

    func saveDisconnected(app: TonConnectApp) async {
        await appRepository.remove(ids: [app.identifier])
        await updateEventCenter()
        listeners.forEach {
            ($0.target as? TonConnectServiceDelegate)?.didDisconnectedApp()
        }
    }

    func disconnectAll() async {
        guard let apps = try? await appRepository.fetchAll() else {
            return
        }
        await appRepository.remove(ids: apps.map { $0.identifier })
        await updateEventCenter()
        listeners.forEach {
            ($0.target as? TonConnectServiceDelegate)?.didDisconnectedApp()
        }
    }

    // MARK: - ApplicationServiceProtocol

    nonisolated func setup() {
        Task {
            await eventCenter.set(delegate: self)
            let apps = try await appRepository.fetchAll()
            try await eventCenter.start(with: apps)
        }
    }

    nonisolated func throttle() {
        Task {
            await eventCenter.stop()
        }
    }

    // MARK: - Private methods

    private func updateEventCenter() async {
        do {
            let apps = try await appRepository.fetchAll()
            try await eventCenter.start(with: apps)
        } catch {
            logger.customError(error)
        }
    }

    private func saveToStore(
        wallet: MetaAccountModel,
        clientId: String,
        appUrl: URL,
        sessionCrypto: TonConnectSessionCrypto,
        name: String,
        iconUrl: URL?
    ) async {
        let app = TonConnectApp(
            walletId: wallet.metaId,
            clientId: clientId,
            appUrl: appUrl,
            name: name,
            iconUrl: iconUrl,
            publicKey: sessionCrypto.keyPair.publicKey.data,
            privateKey: sessionCrypto.keyPair.privateKey.data
        )
        await appRepository.save(models: [app])
    }

    private func sendMessageConfirmConnectionRequest(
        body: String,
        sessionCrypto: TonConnectSessionCrypto,
        parameters: TonConnectParameters
    ) async throws {
        let apiClient = try chainRegistry.getTonApiAssembly().tonConnectAPIClient()
        let response = try await apiClient.message(
            query: .init(
                client_id: sessionCrypto.sessionId,
                to: parameters.clientId,
                ttl: 300
            ),
            body: .plainText(.init(stringLiteral: body))
        )

        _ = try response.ok.body.json
    }

    private func getConfig(_ deeplink: String) throws -> TonConnectParameters {
        guard
            let url = URL(string: deeplink),
            let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
            components.scheme == "tc",
            let queryItems = components.queryItems,
            let versionValue = queryItems.first(where: { $0.name == "v" })?.value,
            let version = TonConnectParameters.Version(rawValue: versionValue),
            let clientId = queryItems.first(where: { $0.name == "id" })?.value,
            let requestPayloadValue = queryItems.first(where: { $0.name == "r" })?.value,
            let requestPayloadData = requestPayloadValue.data(using: .utf8),
            let requestPayload = try? JSONDecoder().decode(TonConnectRequestPayload.self, from: requestPayloadData)
        else {
            throw TonConnectServiceError.incorrectUrl
        }

        return TonConnectParameters(
            version: version,
            clientId: clientId,
            requestPayload: requestPayload
        )
    }

    private func createBocFactory(for wallet: MetaAccountModel) throws -> BocFactory {
        let network = LocalToggleService.shared.tonEnvListToggle.storageValue ? "-3" : "-239"
        let request = ChainAccountRequest(
            chainId: network,
            addressPrefix: 0,
            ecosystem: .ton,
            accountId: nil
        )
        guard let accountResponse = wallet.fetch(for: request) else {
            throw ConvenienceError(error: "Account response fetch error")
        }

        let bocFactory = try ServiceAssembly.shared.tonBocFactory(
            metaId: wallet.metaId,
            accountResponse: accountResponse
        )
        return bocFactory
    }
}

// MARK: - TonConnectEventsCenterDelegate

extension TonConnectServiceImpl: TonConnectEventsCenterDelegate {
    func didReceive(event: TonConnectEventsCenter.Event) {
        switch event {
        case let .request(request, walletId, app):
            switch request.method {
            case .sendTransaction:
                listeners.forEach {
                    ($0.target as? TonConnectServiceDelegate)?.send(
                        request: request,
                        walletId: walletId,
                        app: app
                    )
                }
            case .disconnect:
                Task { await saveDisconnected(app: app) }
            }
        }
    }
}
