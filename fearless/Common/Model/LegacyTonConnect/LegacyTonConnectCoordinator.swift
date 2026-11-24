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
    /// The remote veto (`RemoteKillSwitch.tonConnect`); an absent key keeps TON Connect on.
    private let isEnabled: () -> Bool
    /// The remote signing veto (`RemoteKillSwitch.tonDappSigning`): transactions and `ton_proof` sign-ins, as on
    /// Android. An absent key keeps signing on.
    private let isSigningEnabled: () -> Bool
    /// How long a disconnect notice may take to reach the application's bridge before it is given up.
    private let disconnectNoticeNanoseconds: UInt64
    private let logger: LoggerProtocol
    /// Asks iOS for time to finish work if the app leaves the screen meanwhile; `expired` runs if that time runs
    /// out. Returns how to give the time back.
    typealias BackgroundTimeRequest = (_ expired: @escaping () -> Void) -> () -> Void
    /// Keeps a disconnect notice going if the app leaves the screen right after the disconnect.
    private let requestBackgroundTime: BackgroundTimeRequest
    /// Disconnect notices still on their way to applications' bridges. Nobody waits for them; each ends by itself
    /// within `disconnectNoticeNanoseconds`.
    private var disconnectNotices: [UUID: Task<Void, Never>] = [:]
    private var ready = false
    /// Links in arrival order, opened one at a time. The one being opened stays first until it is done, so a
    /// duplicate arriving meanwhile is merged with it.
    private var pendingURLs: [URL] = []
    private var isOpeningURL = false
    /// The first link was blocked (another approval, a lock, the app inactive or the wallet not ready): it waits for
    /// a trigger instead of being retried at once.
    private var waitsForTrigger = false
    private var drainObservers: [NSObjectProtocol] = []
    private var presenterCheckScheduled = false
    /// Links the user answered whose reply is still being sent again, with that delivery: the same link arriving
    /// meanwhile is merged with it instead of being asked about a second time.
    private var answeredURLs: [URL: UUID] = [:]
    /// The decided reply each session owes its application, from its first try until it left or was given up; with
    /// the task that sends it again. A disconnect or a newer reply for that session ends it.
    private var replyDeliveries: [String: (token: UUID, task: Task<Void, Never>?)] = [:]
    /// Waits before each further try of a decided connection's reply that the bridge did not take.
    private let replyRetryNanoseconds: [UInt64]
    private let replyRetryWait: (UInt64) async throws -> Void
    private let authorizationViewFactory: (ScreenAuthorizationWireframeProtocol, Bool) -> PinSetupViewProtocol?
    private let reportError: ((Error) -> Void)?

    /// Set by `approve`, in the opening link's own task, once the user has decided on it. A link is queued again
    /// only for a failure before that decision, so nobody is asked twice about one link.
    private final class LinkDecision {
        let url: URL
        var made = false

        init(url: URL) {
            self.url = url
        }
    }

    @TaskLocal private static var linkDecision: LinkDecision?
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
        },
        isEnabled: @escaping () -> Bool = { MultiChainFeaturePolicy.current.tonConnectEnabled },
        isSigningEnabled: @escaping () -> Bool = { MultiChainFeaturePolicy.current.tonDappSigningEnabled },
        disconnectNoticeNanoseconds: UInt64 = 5_000_000_000,
        replyRetryNanoseconds: [UInt64] = [1, 2, 4, 8, 16].map { $0 * 1_000_000_000 },
        replyRetryWait: @escaping (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) },
        authorizationViewFactory: @escaping (ScreenAuthorizationWireframeProtocol, Bool) -> PinSetupViewProtocol? = {
            PinViewFactory.createScreenAuthorizationView(with: $0, cancellable: $1)
        },
        reportError: ((Error) -> Void)? = nil,
        logger: LoggerProtocol = Logger.shared,
        requestBackgroundTime: @escaping BackgroundTimeRequest = LegacyTonConnectBackgroundTime.request
    ) {
        self.store = store
        self.transport = transport
        self.keystore = keystore
        self.selectedWallet = selectedWallet
        self.networkSelection = networkSelection
        self.approval = approval
        self.walletLoader = walletLoader
        self.isEnabled = isEnabled
        self.isSigningEnabled = isSigningEnabled
        self.disconnectNoticeNanoseconds = disconnectNoticeNanoseconds
        self.replyRetryNanoseconds = replyRetryNanoseconds
        self.replyRetryWait = replyRetryWait
        self.authorizationViewFactory = authorizationViewFactory
        self.reportError = reportError
        self.logger = logger
        self.requestBackgroundTime = requestBackgroundTime
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
        drainPendingURLs(trigger: true)
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
        // Answered already, its reply still on the way: asking again could only contradict the answer.
        guard answeredURLs[url] == nil else { return }
        // Links wait, in order, while the wallet is not ready, the app is locked or not active.
        if !pendingURLs.contains(url) {
            pendingURLs.append(url)
        }
        drainPendingURLs()
    }

    private var canOpenURLs: Bool {
        ready && !ApplicationLockState.shared.isLocked && UIApplication.shared.applicationState == .active
    }

    /// `trigger`: something that may unblock the first link happened (unlock, activation, an approval ended, the
    /// coordinator was activated).
    private func drainPendingURLs(trigger: Bool = false) {
        if trigger {
            waitsForTrigger = false
        }
        guard let url = pendingURLs.first else {
            drainObservers.forEach { NotificationCenter.default.removeObserver($0) }
            drainObservers = []
            return
        }
        guard canOpenURLs, !isOpeningURL, !waitsForTrigger else {
            observeDrainTriggersIfNeeded()
            return
        }
        isOpeningURL = true
        Task { @MainActor in
            var blocked = false
            let decision = LinkDecision(url: url)
            defer {
                isOpeningURL = false
                if blocked {
                    waitsForTrigger = true
                } else {
                    pendingURLs.removeAll { $0 == url }
                }
                drainPendingURLs()
            }
            do {
                guard isEnabled() else { throw LegacyTonConnectError.disabled }
                let link = try LegacyTonConnectProtocol.parseLink(url)
                guard let wallet = selectedWallet() else { throw LegacyTonConnectError.unavailableWallet }
                let manifest = try await transport.manifest(at: link.request.manifestUrl)
                guard canOpenURLs else {
                    blocked = true
                    return
                }
                _ = try await Self.$linkDecision.withValue(decision) {
                    try await connect(
                        walletId: wallet.metaId, clientId: link.clientId, request: link.request, manifest: manifest,
                        connectionType: "http"
                    )
                }
            } catch LegacyTonConnectError.busy where !decision.made {
                // Another approval is open, the app locked or left, or nothing can present the request: the link
                // waits for that to end.
                blocked = true
                schedulePresenterCheckIfNeeded()
            } catch where !canOpenURLs && !decision.made {
                // The wallet stopped being ready while the link was prepared: it waits for the next activation.
                blocked = true
            } catch {
                present(error: error)
            }
        }
    }

    /// Nothing wakes the queue when the app stays active and unlocked but had no settled screen to present on (none,
    /// or UIKit refused the sheet mid-transition): look again every second, without loading anything, until one
    /// exists and no other approval is open.
    private func schedulePresenterCheckIfNeeded() {
        guard !presenterCheckScheduled, !approving, canOpenURLs else {
            return
        }
        presenterCheckScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else { return }
            self.presenterCheckScheduled = false
            guard self.waitsForTrigger, !self.pendingURLs.isEmpty, !self.approving, self.canOpenURLs else { return }
            if let top = UIApplication.topViewController(), Self.isSettled(top) {
                self.drainPendingURLs(trigger: true)
            } else {
                self.schedulePresenterCheckIfNeeded()
            }
        }
    }

    /// In a window, with no presentation, dismissal or interactive transition in flight.
    private static func isSettled(_ controller: UIViewController) -> Bool {
        controller.viewIfLoaded?.window != nil && controller.transitionCoordinator == nil
            && !controller.isBeingPresented && !controller.isBeingDismissed
    }

    private func observeDrainTriggersIfNeeded() {
        guard drainObservers.isEmpty else { return }
        let triggers: [(Notification.Name, Any?)] = [
            (ApplicationLockState.didChangeNotification, ApplicationLockState.shared),
            (UIApplication.didBecomeActiveNotification, nil)
        ]
        drainObservers = triggers.map { name, object in
            NotificationCenter.default.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
                self?.drainPendingURLs(trigger: true)
            }
        }
    }

    /// `pageOrigin` is the verified page of the in-app browser that asked; a link has none.
    @MainActor
    func connect(
        walletId: String, clientId: String, request: LegacyTonConnectConnectRequest,
        manifest: LegacyTonConnectManifest, connectionType: String, pageOrigin: URL? = nil
    ) async throws -> Data {
        guard ready else { throw LegacyTonConnectError.unavailableWallet }
        guard isEnabled() else { throw LegacyTonConnectError.disabled }
        _ = try request.validated()
        _ = try manifest.validated()
        guard ["http", "js"].contains(connectionType),
              connectionType == "js" || LegacyTonConnectProtocol.clientKey(clientId) != nil else {
            throw LegacyTonConnectError.invalidRequest
        }
        // A link's manifest can name any site. Unless the host that served it (or the page that
        // asked) vouches for that site, the prompt and the stored session name the serving host.
        let voucher = pageOrigin ?? request.manifestUrl
        let isVouched = LegacyTonConnectProtocol.isVouched(claimed: manifest.url, by: voucher)
        guard let appURL = isVouched ? manifest.url : LegacyTonConnectProtocol.origin(voucher).flatMap({ URL(string: $0) }) else {
            throw LegacyTonConnectError.invalidRequest
        }
        let wallet = try await walletLoader(walletId)
        guard let account = wallet.legacyTonAccount else { throw LegacyTonConnectError.unavailableWallet }
        let existing = try await service.sessions(walletId: walletId).first {
            $0.connectionType == connectionType && LegacyTonConnectProtocol.origin($0.appUrl) == LegacyTonConnectProtocol.origin(appURL) &&
                ($0.clientId.lowercased() == clientId.lowercased() || connectionType == "js")
        }
        let session: LegacyTonConnectSession
        if let existing {
            session = existing
        } else {
            let pair = try NaclBox.keyPair()
            session = LegacyTonConnectSession(
                identifier: walletId + "-" + appURL.absoluteString + "-" + UUID().uuidString,
                walletId: walletId, clientId: connectionType == "js" ? UUID().uuidString : clientId.lowercased(), appUrl: appURL,
                name: isVouched ? manifest.name : (appURL.host ?? manifest.name),
                iconUrl: isVouched ? manifest.iconUrl : nil, publicKey: pair.publicKey, privateKey: pair.secretKey, connectionType: connectionType
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
        let requestsProof = request.items.contains(where: { $0.name == "ton_proof" })
        // A sign-in proof is a signature: the signing veto refuses it before any prompt.
        guard !requestsProof || isSigningEnabled() else { throw LegacyTonConnectError.signingPaused }
        if !isVouched, requestsProof {
            // Refused before any prompt: a sign-in proof for the claimed site would let this link
            // log in to it as the user. The application hears why instead of waiting.
            let refused = try JSONSerialization.data(withJSONObject: [
                "event": "connect_error", "id": UInt64(Date().timeIntervalSince1970),
                "payload": ["code": 3, "message": "The manifest url is not on the host that serves the manifest"]
            ])
            if connectionType == "http" {
                try? await transport.send(refused, session: session, bridge: context.bridgeURL, topic: "connect")
            }
            throw LegacyTonConnectError.unverifiedApplication(claimedHost: manifest.url.host ?? "", sourceHost: voucher.host ?? "")
        }
        let headline: String
        if isVouched {
            let manifestSource = LegacyTonConnectProtocol.origin(request.manifestUrl) == LegacyTonConnectProtocol.origin(manifest.url)
                ? "" : "\nManifest: \(request.manifestUrl.absoluteString)"
            headline = "Application: \(manifest.url.absoluteString)\(manifestSource)"
        } else {
            let warning = R.string.localizable.tonconnectDomainMismatch(
                manifest.url.absoluteString,
                preferredLanguages: LegacyTonConnectProtocol.languages
            )
            headline = "Application: \(appURL.absoluteString)\n\(warning)"
        }
        let details = "\(headline)\nWallet: \(wallet.name)\nAccount: \(account.address)\nNetwork: \(network == "-3" ? "TON Testnet" : "TON Mainnet")" +
            (requestsProof ? "\nThe application also requests proof of wallet ownership." : "")
        guard try await approve(title: "Connect TON wallet", details: details) else {
            let declined = try JSONSerialization.data(withJSONObject: ["event": "connect_error", "id": UInt64(Date().timeIntervalSince1970), "payload": ["code": 300, "message": "Connection declined"]])
            if connectionType == "http" {
                await deliverConnectReply(declined, session: session, bridge: context.bridgeURL, sessionIsSaved: false)
            }
            return declined
        }
        let current = try await walletLoader(walletId)
        guard ready, current.legacyTonAccount == account else { throw LegacyTonConnectError.unavailableWallet }
        guard isEnabled() else { throw LegacyTonConnectError.disabled }
        guard !requestsProof || isSigningEnabled() else { throw LegacyTonConnectError.signingPaused }
        // An address-only connection shares public data: the spending key is read only to sign
        // the ownership proof the user just approved.
        let privateKey = requestsProof
            ? try account.signingCredentials(keystore: keystore, metaId: walletId).legacyNativePrivateKey
            : nil
        let response = try LegacyTonConnectProtocol.connectEvent(
            account: account, privateKey: privateKey,
            network: network, request: request, manifest: manifest, timestamp: UInt64(Date().timeIntervalSince1970),
            vouchedBy: pageOrigin
        )
        try await service.save(session: session, context: context)
        if connectionType == "http" {
            await deliverConnectReply(response, session: session, bridge: context.bridgeURL, sessionIsSaved: true)
            // The saved session listens whether or not its reply has left yet; a wallet throttled meanwhile starts
            // it on its next activation instead.
            if ready {
                await service.start(selectedNetwork: network)
            }
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
        // A vetoed request is answered at once (`LegacyTonConnectService`) and never signed.
        guard isEnabled() else { throw LegacyTonConnectError.disabled }
        guard isSigningEnabled() else { throw LegacyTonConnectError.signingPaused }
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
        guard isEnabled() else { throw LegacyTonConnectError.disabled }
        guard isSigningEnabled() else { throw LegacyTonConnectError.signingPaused }
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
        // A wallet that stopped being ready (throttled while the request was prepared) asks nothing.
        guard ready, !approving else { throw LegacyTonConnectError.busy }
        approving = true
        defer {
            approving = false
            // A link that waited for this approval to end may go now.
            drainPendingURLs(trigger: true)
        }
        let approved: Bool
        if let approval {
            approved = try await approval(title, details)
        } else {
            approved = try await presentApproval(title: title, details: details)
        }
        Self.linkDecision?.made = true
        return approved
    }

    @MainActor
    private func presentApproval(title: String, details: String) async throws -> Bool {
        // Never over the PIN screen or the re-lock cover: wallet and request details wait for an unlocked app.
        guard UIApplication.shared.applicationState == .active, !ApplicationLockState.shared.isLocked,
              let presenting = UIApplication.topViewController(), Self.isSettled(presenting) else {
            throw LegacyTonConnectError.busy
        }
        // nil: the user did not answer (UIKit refused the sheet, or the lock or a throttle closed it).
        let outcome: Bool? = await withCheckedContinuation { continuation in
            var resumed = false
            let resume: (Bool?) -> Void = { value in
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: value)
            }
            let controller = LegacyTonConnectApprovalViewController(title: title, details: details)
            approvalController = controller
            controller.isInterrupted = { [weak self] in ApplicationLockState.shared.isLocked || self?.ready != true }
            controller.onApprove = { [weak self, weak controller] in
                guard let self, let controller else { return }
                authorizeWithOutcome(animated: true, cancellable: true, from: controller) { outcome in
                    switch outcome {
                    case .authorized: controller.finish(approved: true)
                    case .declined: controller.finish(approved: false)
                    // The PIN closed with the app going to the background: nothing was decided, so nothing is sent
                    // and the request is asked again.
                    case .unanswered: controller.finishUnanswered()
                    }
                }
            }
            controller.completion = { [weak self] outcome in
                self?.approvalController = nil
                resume(outcome)
            }
            presenting.present(controller, animated: true)
            // UIKit declines a presentation during another transition and only logs it; the sheet then never
            // answers, which would hold the approval slot and every waiting link.
            if controller.presentingViewController == nil {
                controller.completion = nil
                controller.onApprove = nil
                approvalController = nil
                resume(nil)
            }
        }
        guard let outcome else { throw LegacyTonConnectError.busy }
        return outcome
    }

    @MainActor
    func presentSessions(from presenting: UIViewController) {
        guard isEnabled() else {
            present(error: LegacyTonConnectError.disabled)
            return
        }
        let view = LegacyTonConnectSessionsViewController(coordinator: self)
        presenting.present(FearlessNavigationController(rootViewController: view), animated: true)
    }

    @MainActor
    func selectedSessions() async throws -> [LegacyTonConnectSession] {
        guard let wallet = selectedWallet() else { throw LegacyTonConnectError.unavailableWallet }
        return try await service.sessions(walletId: wallet.metaId)
    }

    /// The id of a wallet `disconnect` event: the largest integer a JavaScript number holds exactly. @tonconnect/sdk
    /// drops a wallet event whose id is not above the last one it accepted, and a disconnect ends the session, so it
    /// takes the largest id an application can compare, above every connect event's (Unix seconds).
    static let disconnectEventId: UInt64 = 9_007_199_254_740_991

    /// The user disconnects a session in the wallet. It stops working at once, and this returns as soon as it is
    /// removed here; a bridge application is then told in the background, so it stops trusting the session's
    /// transport key.
    @MainActor
    func disconnect(_ session: LegacyTonConnectSession) async throws {
        do {
            try await service.disconnect(session)
        } catch let unfinished as LegacyTonConnectUnfinishedRemoval {
            // Retired for good though not fully removed yet: the application is told all the same.
            notifyDisconnected([session])
            throw unfinished
        }
        notifyDisconnected([session])
    }

    /// Disconnect notices sent and not yet delivered, failed or given up.
    @MainActor
    var disconnectNoticesInFlight: Int {
        disconnectNotices.count
    }

    /// Returns once every disconnect notice sent so far was delivered, failed or given up; for tests; nothing in the
    /// app waits for a notice.
    @MainActor
    func waitForDisconnectNotices() async {
        while let notice = disconnectNotices.values.first {
            await notice.value
        }
    }

    /// Bridge sessions of the selected wallet whose transport key an older version kept in the database, and whose
    /// offer to reconnect the user has not answered. An in-app browser session never uses its key, so it is not
    /// offered.
    @MainActor
    func sessionsToReconnect() async throws -> [LegacyTonConnectSession] {
        guard let wallet = selectedWallet() else { return [] }
        return try await store.sessionsToReconnect().filter { $0.walletId == wallet.metaId && $0.connectionType == "http" }
    }

    /// The user chose to reconnect: every session is disconnected, and the first failure is reported once all were
    /// tried. A disconnect that never started leaves its session waiting, so it is offered again; one recorded but
    /// not finished is finished by the next read. Once every disconnect was recorded, applications are told in the
    /// background, each recorded one included.
    @MainActor
    func reconnect(_ sessions: [LegacyTonConnectSession]) async throws {
        var disconnected: [LegacyTonConnectSession] = []
        var firstFailure: Error?
        for session in sessions {
            do {
                try await service.disconnect(session)
                disconnected.append(session)
            } catch let unfinished as LegacyTonConnectUnfinishedRemoval {
                disconnected.append(session)
                firstFailure = firstFailure ?? unfinished
            } catch {
                firstFailure = firstFailure ?? error
            }
        }
        notifyDisconnected(disconnected)
        if let firstFailure {
            throw firstFailure
        }
    }

    /// The user chose to keep these sessions as they are: they are not offered again.
    @MainActor
    func keepWithoutReconnecting(_ sessions: [LegacyTonConnectSession]) async throws {
        try await store.finishReconnectOffer(for: sessions)
    }

    /// TON Connect has a wallet tell a bridge application that the user disconnected it, so the application drops
    /// the session and its transport key. Called once the sessions are removed, with their keys still in memory.
    /// Best effort, in the background: the notices go out together and are given up (cancelled) after
    /// `disconnectNoticeNanoseconds`, or earlier if iOS ends the time it gave the app to finish them once it left the
    /// screen. A paused TON Connect sends nothing and logs that it did not.
    @MainActor
    private func notifyDisconnected(_ sessions: [LegacyTonConnectSession]) {
        let bridged = sessions.filter { $0.connectionType == "http" }
        guard !bridged.isEmpty else { return }
        guard isEnabled() else {
            logger.warning("TON Connect is paused: a disconnect notice to \(bridged.count) application(s) was not sent")
            return
        }
        let service = service
        let transport = transport
        let network = selectedNetwork
        let eventId = Self.disconnectEventId
        let deadline = disconnectNoticeNanoseconds
        let logger = logger
        let notices = Task { () -> Bool in
            await withTaskGroup(of: Bool.self) { group in
                for session in bridged {
                    group.addTask {
                        do {
                            let bridge = try await service.bridgeURL(for: session, selectedNetwork: network)
                            let event = try JSONSerialization.data(withJSONObject: [
                                "event": "disconnect", "id": eventId, "payload": [String: String]()
                            ])
                            try await transport.send(event, session: session, bridge: bridge, topic: "disconnect")
                            return true
                        } catch {
                            return false
                        }
                    }
                }
                return await group.reduce(true) { $0 && $1 }
            }
        }
        // A user who disconnects and switches straight to the application still has it told.
        let endBackgroundTime = requestBackgroundTime { notices.cancel() }
        let id = UUID()
        // Registered before the task can run (both on the main actor); the task removes itself as it ends.
        disconnectNotices[id] = Task { @MainActor [weak self] in
            let delivered = await LegacyTonConnectCoordinator.value(of: notices, within: deadline)
            if delivered != true {
                notices.cancel()
                logger.warning("A TON Connect application was not told about a disconnect; the session is removed")
            }
            endBackgroundTime()
            self?.disconnectNotices[id] = nil
        }
    }

    /// The task's value, or nil once the time runs out first. The wait never depends on the task ending.
    private static func value<T>(of task: Task<T, Never>, within nanoseconds: UInt64) async -> T? {
        let gate = LegacyTonConnectOnceGate()
        return await withCheckedContinuation { continuation in
            let timer = Task {
                try? await Task.sleep(nanoseconds: nanoseconds)
                if gate.claim() {
                    continuation.resume(returning: nil)
                }
            }
            Task {
                let value = await task.value
                if gate.claim() {
                    timer.cancel()
                    continuation.resume(returning: value)
                }
            }
        }
    }

    @MainActor
    func connectJS(request: LegacyTonConnectConnectRequest, origin: URL) async throws -> Data {
        guard ready, let wallet = selectedWallet() else { throw LegacyTonConnectError.unavailableWallet }
        guard isEnabled() else { throw LegacyTonConnectError.disabled }
        let manifest = try await transport.manifest(at: request.manifestUrl)
        guard LegacyTonConnectProtocol.origin(manifest.url) == LegacyTonConnectProtocol.origin(origin) else { throw LegacyTonConnectError.invalidRequest }
        return try await connect(
            walletId: wallet.metaId, clientId: "", request: request, manifest: manifest, connectionType: "js", pageOrigin: origin
        )
    }

    @MainActor
    private func present(error: Error) {
        if let reportError {
            reportError(error)
            return
        }
        guard !ApplicationLockState.shared.isLocked else { return }
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

// MARK: - Decided replies and the approval PIN

extension LegacyTonConnectCoordinator {
    func createAuthorizationView(
        with wireframe: ScreenAuthorizationWireframeProtocol,
        cancellable: Bool
    ) -> PinSetupViewProtocol? {
        authorizationViewFactory(wireframe, cancellable)
    }

    /// Sends a decided connection's reply to the application's bridge. A reply the bridge did not take keeps its
    /// session and bridge and is sent again in the background a bounded number of times: the decision stands and
    /// the user is not asked again. It stops once TON Connect is vetoed or an approved session was disconnected,
    /// and the user hears only if every try failed.
    @MainActor
    private func deliverConnectReply(
        _ reply: Data, session: LegacyTonConnectSession, bridge: URL, sessionIsSaved: Bool
    ) async {
        // Claimed before the first try: an older reply still pending for the session is superseded at once.
        let token = UUID()
        replyDeliveries.removeValue(forKey: session.identifier)?.task?.cancel()
        replyDeliveries[session.identifier] = (token, nil)
        do {
            try await transport.send(reply, session: session, bridge: bridge, topic: "connect")
            endReplyDelivery(token, session: session, link: nil)
            return
        } catch {}
        // A disconnect or a newer reply for the session during that try made this one moot.
        guard replyDeliveries[session.identifier]?.token == token else { return }
        let link = Self.linkDecision?.url
        let delivery = Task { @MainActor [weak self, replyRetryNanoseconds, replyRetryWait] in
            // Ends with the task itself, so a link opened after the last try is a new request.
            defer { self?.endReplyDelivery(token, session: session, link: link) }
            for delay in replyRetryNanoseconds {
                do { try await replyRetryWait(delay) } catch { return }
                guard let self else { return }
                switch await self.replyDeliveryCheck(session: session, sessionIsSaved: sessionIsSaved) {
                case .stop: return
                case .later: continue
                case .send: break
                }
                do {
                    try await self.transport.send(reply, session: session, bridge: bridge, topic: "connect")
                    return
                } catch {}
            }
            // Every try failed. A throttle, veto or disconnect meanwhile made the reply moot: nothing to tell then.
            guard let self else { return }
            let check = await self.replyDeliveryCheck(session: session, sessionIsSaved: sessionIsSaved)
            guard check != .stop, self.ready else { return }
            self.present(error: LegacyTonConnectError.transportFailed)
        }
        // Registered before the task can run (both on the main actor).
        replyDeliveries[session.identifier] = (token, delivery)
        if let link {
            answeredURLs[link] = token
        }
    }

    private enum ReplyDeliveryCheck {
        case send
        /// The session list cannot be read now (Keychain locked): try at the next step.
        case later
        case stop
    }

    /// A kept reply never goes after a veto or a disconnect, including one that happened during the lookup.
    @MainActor
    private func replyDeliveryCheck(
        session: LegacyTonConnectSession, sessionIsSaved: Bool
    ) async -> ReplyDeliveryCheck {
        guard !Task.isCancelled, isEnabled() else { return .stop }
        guard sessionIsSaved else { return .send }
        let stored = try? await store.sessions().contains(session)
        // Looked up across a suspension: a veto, or a disconnect (which cancels this task first), still stops it.
        guard !Task.isCancelled, isEnabled() else { return .stop }
        guard let stored else { return .later }
        return stored ? .send : .stop
    }

    /// Every disconnect path (the user, the application, a replayed request) ends the session's pending reply before
    /// the row is removed.
    func sessionWillDisconnect(_ session: LegacyTonConnectSession) async {
        await MainActor.run { replyDeliveries.removeValue(forKey: session.identifier)?.task?.cancel() }
    }

    private func endReplyDelivery(_ token: UUID, session: LegacyTonConnectSession, link: URL?) {
        if replyDeliveries[session.identifier]?.token == token {
            replyDeliveries[session.identifier] = nil
        }
        if let link, answeredURLs[link] == token {
            answeredURLs[link] = nil
        }
    }
}

/// Time iOS gives the app to finish work after it leaves the screen.
enum LegacyTonConnectBackgroundTime {
    /// Begins a background task; `expired` runs if iOS ends it first. The returned closure ends it, once, whichever
    /// side gets there first; later calls do nothing.
    static func request(expired: @escaping () -> Void) -> () -> Void {
        let gate = LegacyTonConnectOnceGate()
        var identifier = UIBackgroundTaskIdentifier.invalid
        let end = {
            // The identifier first: the gate is spent only by a call that can end the task.
            guard identifier != .invalid, gate.claim() else { return }
            UIApplication.shared.endBackgroundTask(identifier)
        }
        // Called on the main thread like this function, so `identifier` is set by then.
        identifier = UIApplication.shared.beginBackgroundTask(withName: "TON Connect disconnect notice") {
            expired()
            end()
        }
        return end
    }
}

/// Lets exactly one of several racing callers through.
private final class LegacyTonConnectOnceGate {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !claimed else { return false }
        claimed = true
        return true
    }
}
