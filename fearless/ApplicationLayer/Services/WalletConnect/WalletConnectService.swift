import Foundation
import UIKit
import SoraFoundation
import Combine
import FearlessWalletConnect

/// WalletConnect signing is on, because its confirmation meets the wallet's signing rules: it shows what is
/// actually signed (network, recipient, amount and fee), the request is bound to an account the session approved,
/// signing asks for the PIN or trusted biometrics (`SubmissionAuthorizer`), the requesting site is shown as
/// WalletConnect Verify reports it, and messages use the standard `<Bytes>` envelope. The remote config can only
/// pause it, per network (`WalletConnectSigningVeto`); it has no override that turns it on.
struct WalletConnectSigningPolicy: Equatable {
    let isEnabled: Bool

    private init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    static let production = WalletConnectSigningPolicy(isEnabled: true)
    /// Signing off: every request is declined before any key is read. It can only turn signing off.
    static let disabled = WalletConnectSigningPolicy(isEnabled: false)
    #if DEBUG
        static let enabledForTests = WalletConnectSigningPolicy(isEnabled: true)
    #endif
}

/// The remote vetoes that pause signing for apps, by the request's network (its CAIP-2 namespace). Absent keys
/// keep signing on; only an explicit `false` pauses it (`RemoteKillSwitch`). Networks other than EVM and Polkadot
/// are never signed over WalletConnect.
enum WalletConnectSigningVeto {
    static func isSigningAllowed(
        on blockchain: Blockchain,
        policy: FeatureToggleConfig = MultiChainFeaturePolicy.current
    ) -> Bool {
        switch blockchain.namespace {
        case "eip155":
            return policy.evmDappSigningEnabled
        case "polkadot":
            return policy.polkadotDappSigningEnabled
        default:
            return false
        }
    }
}

enum WalletConnectSigningError: Error {
    case unavailable
    /// The user did not confirm with the PIN or biometrics.
    case notAuthorized
    /// The remote config paused signing for the request's network while it was open.
    case paused
    /// The dApp stopped waiting for the request while it was open: it expired, or its session ended.
    case requestEnded
}

enum WalletConnectServiceError: Error {
    /// The app identity has no WalletConnect app group, or the service was not set up.
    case unavailable
}

protocol WalletConnectService: ApplicationServiceProtocol {
    func set(listener: WalletConnectServiceDelegate)
    func connect(uri: String) async throws
    func disconnect(topic: String) async throws
    /// Ends every session and pairing, as logging out does.
    func disconnectAll() async throws
    func getSessions() -> [Session]
    /// Whether the dApp still waits for the request: checked before the PIN and again before anything is signed.
    func isPending(request: Request) async -> Bool
    func legacySessionsNeedingReconnect() -> [WalletConnectLegacySession]

    func submit(proposalDecision: WalletConnectProposalDecision) async throws
    func submit(signDecision: WalletConnectSignDecision) async throws
}

protocol WalletConnectServiceDelegate: AnyObject {
    func session(proposal: Session.Proposal, verification: WalletConnectVerification)
    func sign(request: Request, session: Session?, verification: WalletConnectVerification)
    /// A dApp asked for a signature while signing is unavailable. The request was
    /// already declined; nothing was signed.
    func signingUnavailable(request: Request, session: Session?)
    /// WalletConnect Verify flags the app as a known scam. Its proposal or request was
    /// already declined; nothing was connected or signed.
    func blockedScam(origin: String)
    /// The remote config paused signing for the request's network. The request was
    /// already declined; nothing was signed.
    func signingPaused(request: Request, session: Session?)
    /// A pairing link (`wc:` or `fearless://wc?uri=`) could not be paired.
    func pairingFailed(error: Error)
    func didChange(sessions: [Session])
    /// The dApp no longer waits for this request: it expired.
    func requestEnded(id: Int64, topic: String)
    /// A session ended: the dApp no longer waits for any of its requests.
    func sessionEnded(topic: String)
    /// The dApp no longer waits for this proposal: it expired.
    func proposalEnded(id: Int64)
}

extension WalletConnectServiceDelegate {
    func session(proposal _: Session.Proposal, verification _: WalletConnectVerification) {}
    func sign(request _: Request, session _: Session?, verification _: WalletConnectVerification) {}
    func signingUnavailable(request _: Request, session _: Session?) {}
    func blockedScam(origin _: String) {}
    func signingPaused(request _: Request, session _: Session?) {}
    func pairingFailed(error _: Error) {}
    func didChange(sessions _: [Session]) {}
    func requestEnded(id _: Int64, topic _: String) {}
    func sessionEnded(topic _: String) {}
    func proposalEnded(id _: Int64) {}
}

enum WalletConnectGroupIdentifierResolver {
    static let productionBundleIdentifier = "jp.co.soramitsu.fearlesswallet"
    static let developmentBundleIdentifier = "jp.co.soramitsu.fearlesswallet.dev"
    static let productionGroupIdentifier = "group.jp.co.soramitsu.fearlesswallet"
    static let developmentGroupIdentifier = "group.jp.co.soramitsu.fearlesswallet.walletconnect"

    static func resolve(bundleIdentifier: String?) -> String? {
        if bundleIdentifier == productionBundleIdentifier {
            return productionGroupIdentifier
        }

        if bundleIdentifier == developmentBundleIdentifier {
            return developmentGroupIdentifier
        }

        return nil
    }
}

/// The app side of WalletConnect, on the app's own open-source client (`Packages/FearlessWalletConnect`).
///
/// Sessions, pairings and keys stay in the WalletConnect app group. On its first start the client carries over what
/// the earlier SDKs saved (WalletConnectSwiftV2 in releases up to 4.1.0, Reown in 4.2.x) and leaves their records in
/// place, so paired dApps keep working after the update and an earlier build still finds them.
final class WalletConnectServiceImpl: WalletConnectService {
    static let shared = WalletConnectServiceImpl()

    typealias ClientFactory = (_ groupIdentifier: String) -> WalletConnectClient?
    typealias Responder = (Request, RPCResult) async throws -> Void
    typealias Pairer = (WalletConnectURI) async throws -> Void
    typealias ProposalRejecter = (Session.Proposal) async throws -> Void
    typealias SigningVeto = (Blockchain) -> Bool
    typealias PendingCheck = (Request) async -> Bool

    private let signingPolicy: WalletConnectSigningPolicy
    private let responder: Responder?
    private let pairer: Pairer?
    private let proposalRejecter: ProposalRejecter?
    private let isSigningAllowed: SigningVeto
    private let pendingCheck: PendingCheck?
    /// Pairing links that arrived before the service was set up (the app opened from a link while locked). Only the
    /// latest few are kept: a page that opens links in a loop cannot pile up pairings for later.
    private(set) var pendingLinkURIs: [String] = []
    static let maxPendingLinks = 3
    private let clientFactory: ClientFactory
    private let notificationCenter: NotificationCenter
    private var listeners: [WeakWrapper] = []
    private var cancellablesBag = Set<AnyCancellable>()
    private var lifecycleObservers: [NSObjectProtocol] = []
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var pendingSuspension: DispatchWorkItem?
    private var legacyStorageMigrator: WalletConnectLegacyStorageMigrator?
    private(set) var client: WalletConnectClient?
    /// The client's start: its stored sessions are loaded once this finishes.
    private(set) var startTask: Task<Void, Never>?

    init(
        signingPolicy: WalletConnectSigningPolicy = .production,
        respond: Responder? = nil,
        pair: Pairer? = nil,
        rejectProposal: ProposalRejecter? = nil,
        isSigningAllowed: @escaping SigningVeto = { WalletConnectSigningVeto.isSigningAllowed(on: $0) },
        isPending: PendingCheck? = nil,
        clientFactory: @escaping ClientFactory = WalletConnectServiceImpl.makeClient,
        notificationCenter: NotificationCenter = .default
    ) {
        self.signingPolicy = signingPolicy
        responder = respond
        pairer = pair
        proposalRejecter = rejectProposal
        self.isSigningAllowed = isSigningAllowed
        pendingCheck = isPending
        self.clientFactory = clientFactory
        self.notificationCenter = notificationCenter
    }

    deinit {
        removeLifecycleObservers()
    }

    // MARK: - ApplicationServiceProtocol

    func setup() {
        guard
            let groupIdentifier = WalletConnectGroupIdentifierResolver.resolve(
                bundleIdentifier: Bundle.main.bundleIdentifier
            )
        else {
            Logger.shared.error(
                "WalletConnect setup skipped for an unsupported application identity"
            )
            return
        }

        // Releases up to 4.1.0 kept sessions outside the app group; remember them for the reconnect notice.
        if legacyStorageMigrator == nil {
            let legacyStorageMigrator = WalletConnectLegacyStorageMigrator(groupIdentifier: groupIdentifier)
            legacyStorageMigrator.recordLegacySessionsIfNeeded()
            self.legacyStorageMigrator = legacyStorageMigrator
        }

        if client == nil {
            client = clientFactory(groupIdentifier)
        }
        guard let client = client else {
            Logger.shared.error("WalletConnect storage is unavailable")
            return
        }

        setupSubscription(client: client)
        observeApplicationLifecycle(client: client)

        let previousStart = startTask
        startTask = Task { [weak self] in
            await previousStart?.value
            do {
                try await client.start()
            } catch {
                Logger.shared.error("WalletConnect could not start: \(error)")
            }
            await MainActor.run {
                self?.logContinuity()
            }
        }
        // Each pairing waits for the start above before it uses the client.
        pairPendingLinks()
    }

    func throttle() {
        cancellablesBag.forEach {
            $0.cancel()
        }
        cancellablesBag.removeAll()
        removeLifecycleObservers()

        guard let client = client else {
            return
        }
        Task {
            await client.stop()
        }
    }

    // MARK: - WalletConnectService

    func set(listener: WalletConnectServiceDelegate) {
        let weakListener = WeakWrapper(target: listener)
        listeners.append(weakListener)
    }

    func connect(uri: String) async throws {
        let preferredLanguages = LocalizationManager.shared.selectedLocale.rLanguages

        // A new connection is only useful for signing, so it opens together with signing.
        guard signingPolicy.isEnabled else {
            let title = R.string.localizable.walletConnectConnectionUnavailableTitle(
                preferredLanguages: preferredLanguages
            )
            let message = R.string.localizable.walletConnectConnectionUnavailableMessage(
                preferredLanguages: preferredLanguages
            )
            throw ConvenienceContentError(title: title, message: message)
        }

        let walletConnectUri: WalletConnectURI

        do {
            walletConnectUri = try WalletConnectURI(uriString: uri)
        } catch {
            let title = R.string.localizable.walletConnectInvalidUrlTitle(preferredLanguages: preferredLanguages)
            let message = R.string.localizable.walletConnectInvalidUrlMessage(preferredLanguages: preferredLanguages)
            throw ConvenienceContentError(title: title, message: message)
        }

        if let pairer = pairer {
            try await pairer(walletConnectUri)
            return
        }
        guard let client = client else {
            throw WalletConnectServiceError.unavailable
        }
        await startTask?.value
        try await client.pair(uri: walletConnectUri)
    }

    func getSessions() -> [Session] {
        client?.currentSessions ?? []
    }

    func legacySessionsNeedingReconnect() -> [WalletConnectLegacySession] {
        guard let legacyStorageMigrator = legacyStorageMigrator else {
            return []
        }

        return legacyStorageMigrator.legacySessionsNeedingReconnect(
            activeTopics: Set(getSessions().map(\.topic))
        )
    }

    func submit(proposalDecision: WalletConnectProposalDecision) async throws {
        guard let client = client else {
            throw WalletConnectServiceError.unavailable
        }

        switch proposalDecision {
        case let .approve(proposal, namespaces):
            _ = try await client.approve(proposalId: proposal.id, namespaces: namespaces)
        case let .reject(proposal):
            try await client.reject(proposalId: proposal.id, reason: .userRejected)
        }
    }

    func submit(signDecision: WalletConnectSignDecision) async throws {
        switch signDecision {
        case let .signed(request, signature):
            // A signature never reaches a dApp while signing is unavailable.
            guard signingPolicy.isEnabled else {
                throw WalletConnectSigningError.unavailable
            }
            try await respond(request, .response(signature))
        case let .rejected(request, error):
            try await respond(request, .error(error))
        }
    }

    /// Routes a session proposal with what WalletConnect Verify reports about the app.
    /// A proposal from an app Verify flags as a scam is declined and never shown.
    func handle(proposal: Session.Proposal, context: VerifyContext?) {
        let verification = WalletConnectVerification(context: context)
        guard verification != .scam else {
            Task { [weak self] in
                do {
                    try await self?.reject(proposal: proposal)
                } catch {
                    Logger.shared.error("WalletConnect could not decline a proposal from a flagged app")
                }
            }
            notifyBlockedScam(origin: context?.origin ?? proposal.proposer.url)
            return
        }

        listeners.forEach {
            ($0.target as? WalletConnectServiceDelegate)?.session(proposal: proposal, verification: verification)
        }
    }

    /// Routes a dApp request. While signing is unavailable, or when WalletConnect Verify
    /// flags the app as a scam, the dApp is told the user rejected it, no confirmation
    /// opens and no key is read.
    func handle(request: Request, session: Session?, context: VerifyContext? = nil) {
        let verification = WalletConnectVerification(context: context)
        guard verification != .scam, signingPolicy.isEnabled else {
            Task { [weak self] in
                do {
                    try await self?.respond(request, .error(.userRejected))
                } catch {
                    Logger.shared.error("WalletConnect could not decline a request")
                }
            }

            if verification == .scam {
                notifyBlockedScam(origin: context?.origin ?? session?.peer.url ?? "")
            } else {
                listeners.forEach {
                    ($0.target as? WalletConnectServiceDelegate)?.signingUnavailable(request: request, session: session)
                }
            }
            return
        }

        guard isSigningAllowed(request.chainId) else {
            Task { [weak self] in
                do {
                    try await self?.respond(request, .error(.userRejected))
                } catch {
                    Logger.shared.error("WalletConnect could not decline a request while signing is paused")
                }
            }
            listeners.forEach {
                ($0.target as? WalletConnectServiceDelegate)?.signingPaused(request: request, session: session)
            }
            return
        }

        listeners.forEach {
            ($0.target as? WalletConnectServiceDelegate)?.sign(
                request: request,
                session: session,
                verification: verification
            )
        }
    }

    // MARK: - Pairing links

    /// Pairs from a `wc:` link. A link that arrives before the service is set up (the app opened from the link,
    /// before the wallet was unlocked) waits for `setup()`; a failure is reported to the listeners, since no screen
    /// asked for it.
    func pairFromLink(uri: String) {
        guard startTask != nil else {
            pendingLinkURIs.removeAll { $0 == uri }
            pendingLinkURIs.append(uri)
            if pendingLinkURIs.count > Self.maxPendingLinks {
                pendingLinkURIs.removeFirst(pendingLinkURIs.count - Self.maxPendingLinks)
            }
            return
        }

        Task { [weak self] in
            do {
                try await self?.connect(uri: uri)
            } catch WalletConnectClient.ClientError.pairingAlreadyActive {
                // The same link opened twice: its proposal is already on its way.
            } catch {
                await MainActor.run {
                    self?.listeners.forEach {
                        ($0.target as? WalletConnectServiceDelegate)?.pairingFailed(error: error)
                    }
                }
            }
        }
    }

    private func pairPendingLinks() {
        let uris = pendingLinkURIs
        pendingLinkURIs = []
        uris.forEach { pairFromLink(uri: $0) }
    }

    func disconnect(topic: String) async throws {
        guard let client = client else {
            throw WalletConnectServiceError.unavailable
        }
        try await client.disconnect(topic: topic)
    }

    func disconnectAll() async throws {
        guard let client = client else {
            throw WalletConnectServiceError.unavailable
        }
        await startTask?.value
        try await client.disconnectAll()
    }

    func isPending(request: Request) async -> Bool {
        if let pendingCheck = pendingCheck {
            return await pendingCheck(request)
        }
        guard let client = client else {
            return false
        }
        return await client.isPending(topic: request.topic, requestId: request.id)
    }

    // MARK: - Client

    static func makeClient(groupIdentifier: String) -> WalletConnectClient? {
        guard let groupDefaults = UserDefaults(suiteName: groupIdentifier) else {
            return nil
        }

        #if canImport(FearlessKeys)
            #if F_DEV
                let projectId = WalletConnectDebug.projectId
            #else
                let projectId = WalletConnect.projectId
            #endif
        #else
            let projectId = WalletConnect.projectId
        #endif

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let configuration = WalletConnectClient.Configuration(
            projectId: projectId,
            metadata: AppMetadata.createFearlessMetadata(),
            bundleId: Bundle.main.bundleIdentifier,
            userAgent: "wc-2/fearless-wallet-ios-\(version)/iOS-\(UIDevice.current.systemVersion)"
        )

        return WalletConnectClient(
            configuration: configuration,
            stateStore: UserDefaultsStateStore(defaults: groupDefaults),
            secretStore: KeychainSecretStore(accessGroup: groupIdentifier),
            legacyStorage: SystemLegacyWalletConnectStorage(
                groupIdentifier: groupIdentifier,
                groupDefaults: groupDefaults
            ),
            logger: WalletConnectLoggerAdapter()
        )
    }

    // MARK: - Private methods

    private func respond(_ request: Request, _ response: RPCResult) async throws {
        if let responder = responder {
            try await responder(request, response)
            return
        }
        guard let client = client else {
            throw WalletConnectServiceError.unavailable
        }
        try await client.respond(topic: request.topic, requestId: request.id, response: response)
    }

    private func reject(proposal: Session.Proposal) async throws {
        if let proposalRejecter = proposalRejecter {
            try await proposalRejecter(proposal)
            return
        }
        guard let client = client else {
            throw WalletConnectServiceError.unavailable
        }
        try await client.reject(proposalId: proposal.id, reason: .userRejected)
    }

    private func notifyBlockedScam(origin: String) {
        let host = WalletConnectVerification.host(of: origin)
        listeners.forEach {
            ($0.target as? WalletConnectServiceDelegate)?.blockedScam(origin: host)
        }
    }

    private func logContinuity() {
        legacyStorageMigrator?.logContinuity(activeTopics: Set(getSessions().map(\.topic)))
    }

    private func setupSubscription(client: WalletConnectClient) {
        guard cancellablesBag.isEmpty else {
            return
        }

        client.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self = self else {
                    return
                }

                switch event {
                case let .sessionProposal(proposal, context):
                    self.handle(proposal: proposal, context: context)
                case let .sessionsChanged(sessions):
                    self.listeners.forEach {
                        ($0.target as? WalletConnectServiceDelegate)?.didChange(sessions: sessions)
                    }
                case let .sessionRequest(request, context):
                    let session = client.currentSessions.first { $0.topic == request.topic }
                    self.handle(request: request, session: session, context: context)
                case let .requestExpired(id, topic):
                    for listener in self.listeners {
                        (listener.target as? WalletConnectServiceDelegate)?.requestEnded(id: id, topic: topic)
                    }
                case let .sessionDeleted(topic):
                    for listener in self.listeners {
                        (listener.target as? WalletConnectServiceDelegate)?.sessionEnded(topic: topic)
                    }
                case let .proposalExpired(id):
                    for listener in self.listeners {
                        (listener.target as? WalletConnectServiceDelegate)?.proposalEnded(id: id)
                    }
                case .sessionPinged:
                    break
                }
            }
            .store(in: &cancellablesBag)
    }

    /// The relay connection closes a little after the app goes to the background, so what is in flight (an
    /// approval's settlement, an answer) still reaches the dApp when the person switches back to it at once. On
    /// return the client reconnects and fetches what the relay held meanwhile.
    private func observeApplicationLifecycle(client: WalletConnectClient) {
        guard lifecycleObservers.isEmpty else {
            return
        }

        lifecycleObservers = [
            notificationCenter.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.applicationDidEnterBackground(client: client)
            },
            notificationCenter.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.applicationWillEnterForeground(client: client)
            }
        ]
    }

    private func applicationDidEnterBackground(client: WalletConnectClient) {
        pendingSuspension?.cancel()
        if backgroundTask == .invalid {
            backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "WalletConnect relay") { [weak self] in
                self?.suspend(client: client)
            }
        }
        let suspension = DispatchWorkItem { [weak self] in
            self?.suspend(client: client)
        }
        pendingSuspension = suspension
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.backgroundGrace, execute: suspension)
    }

    private func applicationWillEnterForeground(client: WalletConnectClient) {
        pendingSuspension?.cancel()
        pendingSuspension = nil
        endBackgroundTask()
        Task {
            await client.resume()
        }
    }

    private func suspend(client: WalletConnectClient) {
        pendingSuspension?.cancel()
        pendingSuspension = nil
        Task {
            await client.suspend()
        }
        endBackgroundTask()
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else {
            return
        }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    private static let backgroundGrace: TimeInterval = 20

    private func removeLifecycleObservers() {
        lifecycleObservers.forEach {
            notificationCenter.removeObserver($0)
        }
        lifecycleObservers.removeAll()
        pendingSuspension?.cancel()
        pendingSuspension = nil
    }
}

/// The client's log lines in the app's log. The client never logs keys, topics or message contents.
struct WalletConnectLoggerAdapter: WalletConnectLogging {
    func debug(_ message: String) {
        Logger.shared.debug(message)
    }

    func info(_ message: String) {
        Logger.shared.info(message)
    }

    func warning(_ message: String) {
        Logger.shared.warning(message)
    }

    func error(_ message: String) {
        Logger.shared.error(message)
    }
}
