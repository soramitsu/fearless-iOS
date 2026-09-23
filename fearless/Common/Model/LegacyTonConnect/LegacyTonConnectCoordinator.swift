import CryptoKit
import Foundation
import RobinHood
import SoraKeystore
import TonSwift
import TweetNacl
import UIKit

final class LegacyTonConnectURLHandler: URLHandlingServiceProtocol {
    static let shared = LegacyTonConnectURLHandler()
    private let start: (URL) -> Void

    init(start: @escaping (URL) -> Void = { url in LegacyTonConnectCoordinator.shared.open(url) }) {
        self.start = start
    }

    func handle(url: URL) -> Bool {
        guard LegacyTonConnectProtocol.canonicalLink(url) != nil else { return false }
        DispatchQueue.main.async { [start] in start(url) }
        return true
    }
}

final class LegacyTonConnectCoordinator: NSObject, AuthorizationPresentable, LegacyTonConnectRequestHandling {
    static let shared = LegacyTonConnectCoordinator()
    private let service: LegacyTonConnectService
    private let store: LegacyTonConnectSessionStoring
    private let transport: LegacyTonConnectBridgeTransporting
    private let walletLoader: (String) async throws -> MetaAccountModel
    private let keystore: KeystoreProtocol
    private let selectedWallet: () -> MetaAccountModel?
    private let networkSelection: () -> String
    private let approval: ((String, String) async throws -> Bool)?
    private var ready = false
    private var queuedURL: URL?
    private var approving = false
    private weak var approvalController: LegacyTonConnectApprovalViewController?

    init(
        store: LegacyTonConnectSessionStoring = LegacyTonConnectStore(),
        transport: LegacyTonConnectBridgeTransporting = LegacyTonConnectBridgeTransport(),
        replies: LegacyTonConnectReplyStore = LegacyTonConnectReplyStore(),
        keystore: KeystoreProtocol = Keychain(),
        selectedWallet: @escaping () -> MetaAccountModel? = { SelectedWalletSettings.shared.value },
        networkSelection: @escaping () -> String = { LocalToggleService.shared.tonEnvListToggle.storageValue ? "-3" : "-239" },
        approval: ((String, String) async throws -> Bool)? = nil,
        walletLoader: @escaping (String) async throws -> MetaAccountModel = { id in
            let repository = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
                .createMetaAccountRepository(for: nil, sortDescriptors: [])
            guard let wallet = try await repository.fetchAsync(by: id) else { throw LegacyTonConnectError.unavailableWallet }
            return wallet
        }
    ) {
        self.store = store
        self.transport = transport
        self.keystore = keystore
        self.selectedWallet = selectedWallet
        self.networkSelection = networkSelection
        self.approval = approval
        self.walletLoader = walletLoader
        service = LegacyTonConnectService(store: store, replies: replies, transport: transport)
        super.init()
    }

    func setup() {
        Task { @MainActor [weak self] in await self?.activate() }
    }

    @MainActor
    func activate() async {
        ready = true
        await service.set(handler: self)
        await service.start(selectedNetwork: selectedNetwork)
        if let url = queuedURL {
            queuedURL = nil
            open(url)
        }
    }

    func throttle() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            ready = false
            approvalController?.finish(approved: false)
            Task { await self.service.stop() }
        }
    }

    private var selectedNetwork: String {
        networkSelection()
    }

    func open(_ url: URL) {
        precondition(Thread.isMainThread)
        guard ready else {
            queuedURL = url
            return
        }
        Task { @MainActor in
            do {
                let link = try LegacyTonConnectProtocol.parseLink(url)
                guard let wallet = selectedWallet() else { throw LegacyTonConnectError.unavailableWallet }
                let manifest = try await transport.manifest(at: link.request.manifestUrl)
                _ = try await connect(walletId: wallet.metaId, clientId: link.clientId, request: link.request, manifest: manifest, connectionType: "http")
            } catch {
                present(error: error)
            }
        }
    }

    @MainActor
    func connect(
        walletId: String, clientId: String, request: LegacyTonConnectConnectRequest,
        manifest: LegacyTonConnectManifest, connectionType: String
    ) async throws -> Data {
        guard ready else { throw LegacyTonConnectError.unavailableWallet }
        _ = try request.validated()
        _ = try manifest.validated()
        guard ["http", "js"].contains(connectionType),
              connectionType == "js" || LegacyTonConnectProtocol.clientKey(clientId) != nil else {
            throw LegacyTonConnectError.invalidRequest
        }
        let wallet = try await walletLoader(walletId)
        guard let account = wallet.legacyTonAccount else { throw LegacyTonConnectError.unavailableWallet }
        let existing = try await service.sessions(walletId: walletId).first {
            $0.connectionType == connectionType && LegacyTonConnectProtocol.origin($0.appUrl) == LegacyTonConnectProtocol.origin(manifest.url) &&
                ($0.clientId.lowercased() == clientId.lowercased() || connectionType == "js")
        }
        let session: LegacyTonConnectSession
        if let existing {
            session = existing
        } else {
            let pair = try NaclBox.keyPair()
            session = LegacyTonConnectSession(
                identifier: walletId + "-" + manifest.url.absoluteString + "-" + UUID().uuidString,
                walletId: walletId, clientId: connectionType == "js" ? UUID().uuidString : clientId.lowercased(), appUrl: manifest.url, name: manifest.name,
                iconUrl: manifest.iconUrl, publicKey: pair.publicKey, privateKey: pair.secretKey, connectionType: connectionType
            )
        }
        let context: LegacyTonConnectSessionContext
        if existing != nil {
            context = try await service.context(for: session, selectedNetwork: selectedNetwork)
        } else {
            context = LegacyTonConnectSessionContext(
                bridgeURL: connectionType == "http" ? try await store.bridgeURL(network: selectedNetwork) : session.appUrl,
                network: selectedNetwork, lastEventId: nil
            )
        }
        let network = context.network
        let manifestSource = LegacyTonConnectProtocol.origin(request.manifestUrl) == LegacyTonConnectProtocol.origin(manifest.url)
            ? "" : "\nManifest: \(request.manifestUrl.absoluteString)"
        let details = "Application: \(manifest.url.absoluteString)\(manifestSource)\nWallet: \(wallet.name)\nAccount: \(account.address)\nNetwork: \(network == "-3" ? "TON Testnet" : "TON Mainnet")" +
            (request.items.contains(where: { $0.name == "ton_proof" }) ? "\nThe application also requests proof of wallet ownership." : "")
        guard try await approve(title: "Connect TON wallet", details: details) else {
            let declined = try JSONSerialization.data(withJSONObject: ["event": "connect_error", "id": UInt64(Date().timeIntervalSince1970), "payload": ["code": 300, "message": "Connection declined"]])
            if connectionType == "http" {
                try await transport.send(declined, session: session, bridge: context.bridgeURL, topic: "connect")
            }
            return declined
        }
        let current = try await walletLoader(walletId)
        guard ready, current.legacyTonAccount == account else { throw LegacyTonConnectError.unavailableWallet }
        let credentials = try account.signingCredentials(keystore: keystore, metaId: walletId)
        let response = try LegacyTonConnectProtocol.connectEvent(
            account: account, privateKey: credentials.legacyNativePrivateKey,
            network: network, request: request, manifest: manifest, timestamp: UInt64(Date().timeIntervalSince1970)
        )
        try await service.save(session: session, context: context)
        if connectionType == "http" {
            try await transport.send(response, session: session, bridge: context.bridgeURL, topic: "connect")
            await service.start(selectedNetwork: network)
        }
        return response
    }

    @MainActor
    func restoreJS(origin: URL) async throws -> Data {
        guard ready, let wallet = selectedWallet(),
              let account = wallet.legacyTonAccount,
              let session = try await service.sessions(walletId: wallet.metaId).first(where: {
                  $0.connectionType == "js" && LegacyTonConnectProtocol.origin($0.appUrl) == LegacyTonConnectProtocol.origin(origin)
              }) else { throw LegacyTonConnectError.invalidSession }
        _ = try session.validated()
        let context = try await service.context(for: session, selectedNetwork: selectedNetwork)
        let request = LegacyTonConnectConnectRequest(manifestUrl: session.appUrl, items: [.init(name: "ton_addr", payload: nil)])
        // Released sessions accepted empty/long names and non-HTTPS icons.
        // This public reply uses only the validated origin; cosmetic metadata
        // remains unchanged in storage and must not block an existing session.
        let manifest = LegacyTonConnectManifest(url: session.appUrl, name: "Connected application", iconUrl: nil)
        // Restoring a connection never creates a fresh ownership proof or signs a transaction.
        return try LegacyTonConnectProtocol.connectEvent(
            account: account,
            privateKey: nil,
            network: context.network,
            request: request,
            manifest: manifest,
            timestamp: UInt64(Date().timeIntervalSince1970)
        )
    }

    @MainActor
    func handleJS(_ data: Data, origin: URL) async throws -> Data {
        guard ready, let wallet = selectedWallet(),
              let session = try await service.sessions(walletId: wallet.metaId).first(where: {
                  $0.connectionType == "js" && LegacyTonConnectProtocol.origin($0.appUrl) == LegacyTonConnectProtocol.origin(origin)
              }) else { throw LegacyTonConnectError.invalidSession }
        let context = try await service.context(for: session, selectedNetwork: selectedNetwork)
        return try await service.handle(data, session: session, network: context.network)
    }

    @MainActor
    func process(session: LegacyTonConnectSession, network: String, request: LegacyTonConnectRPCRequest) async throws -> LegacyTonConnectRPCOutcome {
        guard ready, let encoded = request.params.first else { throw LegacyTonConnectError.unavailableWallet }
        let wallet = try await walletLoader(session.walletId)
        guard let account = wallet.legacyTonAccount else { throw LegacyTonConnectError.unavailableWallet }
        let transfer = try transferRequest(parameters: Data(encoded.utf8), session: session, requestId: request.id, network: network, account: account)
        let sender = try sendService(network: network)
        let quote = try await sender.quoteTonConnect(transfer)
        let descriptions = transfer.messages.enumerated().map { index, message in
            var details = "\(index + 1). To: \(message.recipientAddress)\nTON: \(Self.formatTon(message.amountNanotons))"
            if let payload = message.payloadBocBase64 { details += "\nContract payload SHA-256: \(Self.digest(payload))" }
            if let stateInit = message.stateInitBocBase64 { details += "\nContract deployment SHA-256: \(Self.digest(stateInit))" }
            return details
        }.joined(separator: "\n\n")
        let effects = quote.effectDescriptions.joined(separator: "\n")
        let details = "Application: \(session.appUrl.absoluteString)\nWallet: \(wallet.name)\nNetwork: \(network == "-3" ? "TON Testnet" : "TON Mainnet")\n\n\(descriptions)\n\nExpected effects:\n\(effects)\n\nNetwork fee: \(Self.formatTon(String(quote.feeNanotons))) TON"
        guard try await approve(title: "Review TON transaction", details: details) else {
            return LegacyTonConnectRPCOutcome(response: try LegacyTonConnectProtocol.response(id: request.id, errorCode: 300, message: "Transaction declined"), messageHashHex: nil)
        }
        let current = try await walletLoader(session.walletId)
        guard ready, current.legacyTonAccount == account,
              try await store.sessions().contains(session) else { throw LegacyTonConnectError.invalidSession }
        let result = try await sender.sendTonConnect(transfer, feeQuote: quote, legacyAccount: account) { [keystore] in
            try account.signingCredentials(keystore: keystore, metaId: session.walletId)
        }
        return LegacyTonConnectRPCOutcome(
            response: try LegacyTonConnectProtocol.response(id: request.id, result: result.prepared.signedMessage.bocBase64),
            messageHashHex: result.messageHashHex
        )
    }

    @MainActor
    func acknowledge(session: LegacyTonConnectSession, network: String, request: LegacyTonConnectRPCRequest, messageHashHex: String) async throws {
        guard let encoded = request.params.first,
              let account = try await walletLoader(session.walletId).legacyTonAccount else { throw LegacyTonConnectError.unavailableWallet }
        // The journal validates the immutable request/hash; acknowledgement does not re-sign.
        let transfer = try transferRequest(
            parameters: Data(encoded.utf8),
            session: session,
            requestId: request.id,
            network: network,
            account: account,
            allowExpired: true
        )
        try await sendService(network: network).acknowledgeTonConnect(request: transfer, messageHashHex: messageHashHex)
    }

    private func transferRequest(parameters: Data, session: LegacyTonConnectSession, requestId: String, network: String, account: LegacyTonAccount, allowExpired: Bool = false) throws -> TonConnectTransferRequest {
        let value: LegacyTonConnectTransactionParameters
        do {
            value = try LegacyTonConnectTransactionParameters.decode(
                parameters, sender: account.address, network: network, now: allowExpired ? 0 : UInt64(Date().timeIntervalSince1970)
            )
        } catch is DecodingError {
            throw LegacyTonConnectError.invalidRequest
        }
        return try TonConnectTransferRequest(
            publicKey: account.publicKey, senderAddress: account.address, network: network == "-3" ? .testnet : .mainnet,
            validUntil: value.valid_until, replayIdentifier: session.identifier + "/" + requestId,
            messages: try value.messages.map {
                try TonConnectTransferMessage(
                    recipientAddress: $0.address,
                    amountNanotons: $0.amount,
                    payloadBocBase64: $0.payload,
                    stateInitBocBase64: $0.stateInit
                )
            }
        )
    }

    private func sendService(network: String) throws -> TonSendService {
        guard ["-239", "-3"].contains(network),
              let registry = ChainRegistryFacade.sharedRegistry as? ChainRegistry else {
            throw LegacyTonConnectError.unavailableBridge
        }
        let selected: TonTransferNetwork = network == "-3" ? .testnet : .mainnet
        return TonSendService(remote: TonAPIRemoteClient(factory: try registry.getTonApiClientFactory(for: selected)))
    }

    @MainActor
    private func approve(title: String, details: String) async throws -> Bool {
        guard !approving else { throw LegacyTonConnectError.busy }
        approving = true
        defer { approving = false }
        if let approval { return try await approval(title, details) }
        guard UIApplication.shared.applicationState == .active,
              let presenting = UIApplication.topViewController() else { throw LegacyTonConnectError.busy }
        return await withCheckedContinuation { continuation in
            let controller = LegacyTonConnectApprovalViewController(title: title, details: details)
            approvalController = controller
            controller.onApprove = { [weak self, weak controller] in
                guard let self, let controller else { return }
                authorize(animated: true, cancellable: true, from: controller) { authorized in
                    controller.finish(approved: authorized)
                }
            }
            controller.completion = { [weak self] approved in
                self?.approvalController = nil
                continuation.resume(returning: approved)
            }
            presenting.present(controller, animated: true)
        }
    }

    @MainActor
    func presentSessions(from presenting: UIViewController) {
        let view = LegacyTonConnectSessionsViewController(coordinator: self)
        presenting.present(FearlessNavigationController(rootViewController: view), animated: true)
    }

    @MainActor
    func selectedSessions() async throws -> [LegacyTonConnectSession] {
        guard let wallet = selectedWallet() else { throw LegacyTonConnectError.unavailableWallet }
        return try await service.sessions(walletId: wallet.metaId)
    }

    func disconnect(_ session: LegacyTonConnectSession) async throws {
        try await service.disconnect(session)
    }

    @MainActor
    func connectJS(request: LegacyTonConnectConnectRequest, origin: URL) async throws -> Data {
        guard ready, let wallet = selectedWallet() else { throw LegacyTonConnectError.unavailableWallet }
        let manifest = try await transport.manifest(at: request.manifestUrl)
        guard LegacyTonConnectProtocol.origin(manifest.url) == LegacyTonConnectProtocol.origin(origin) else { throw LegacyTonConnectError.invalidRequest }
        return try await connect(walletId: wallet.metaId, clientId: "", request: request, manifest: manifest, connectionType: "js")
    }

    @MainActor
    private func present(error: Error) {
        let alert = UIAlertController(title: "TonConnect", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        UIApplication.topViewController()?.present(alert, animated: true)
    }

    private static func digest(_ base64: String) -> String {
        SHA256.hash(data: Data(base64Encoded: base64) ?? Data()).map { String(format: "%02x", $0) }.joined()
    }

    private static func formatTon(_ nanotons: String) -> String {
        guard let value = Decimal(string: nanotons) else { return nanotons }
        return NSDecimalNumber(decimal: value / 1_000_000_000).stringValue
    }
}
