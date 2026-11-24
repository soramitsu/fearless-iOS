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
    /// Decided replies being sent again, by session: a disconnect or a newer reply for that session ends one.
    private var replyDeliveries: [String: (token: UUID, task: Task<Void, Never>)] = [:]
    /// Waits before each further try of a decided connection's reply that the bridge did not take.
    private let replyRetryNanoseconds: [UInt64]
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
        replyRetryNanoseconds: [UInt64] = [1, 2, 4, 8, 16].map { $0 * 1_000_000_000 },
        authorizationViewFactory: @escaping (ScreenAuthorizationWireframeProtocol, Bool) -> PinSetupViewProtocol? = {
            PinViewFactory.createScreenAuthorizationView(with: $0, cancellable: $1)
        },
        reportError: ((Error) -> Void)? = nil
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
        self.replyRetryNanoseconds = replyRetryNanoseconds
        self.authorizationViewFactory = authorizationViewFactory
        self.reportError = reportError
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

    func disconnect(_ session: LegacyTonConnectSession) async throws {
        try await service.disconnect(session)
        // Its connect reply, if still being sent again, is moot now.
        await MainActor.run { replyDeliveries.removeValue(forKey: session.identifier)?.task.cancel() }
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
        do {
            try await transport.send(reply, session: session, bridge: bridge, topic: "connect")
            return
        } catch {}
        let token = UUID()
        let link = Self.linkDecision?.url
        let delivery = Task { @MainActor [weak self, replyRetryNanoseconds] in
            // Ends with the task itself, so a link opened after the last try is a new request.
            defer { self?.endReplyDelivery(token, session: session, link: link) }
            for delay in replyRetryNanoseconds {
                do { try await Task.sleep(nanoseconds: delay) } catch { return }
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
            guard let self, self.ready else { return }
            let check = await self.replyDeliveryCheck(session: session, sessionIsSaved: sessionIsSaved)
            guard check != .stop else { return }
            self.present(error: LegacyTonConnectError.transportFailed)
        }
        // Registered before the task can run (both on the main actor); a newer reply for the session replaces it.
        replyDeliveries.removeValue(forKey: session.identifier)?.task.cancel()
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
        guard let stored = try? await store.sessions().contains(session) else { return .later }
        guard stored, !Task.isCancelled, isEnabled() else { return .stop }
        return .send
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
