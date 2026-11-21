import UIKit

/// IrohaConnect is on: the wallet speaks the current Iroha Connect v1, signs only wallet-built approval
/// preimages and the hashes of Taira transactions it decoded and showed the person, and refuses raw requests
/// (`docs/irohaconnect-safe-signing.md`). The constant stays the single switch for the coordinator, the
/// Profile row and the account provider. There is intentionally no environment-variable, remote-config, or
/// runtime-toggle override.
struct IrohaConnectReleasePolicy: Equatable {
    let isEnabled: Bool

    private init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    static let production = IrohaConnectReleasePolicy(isEnabled: true)
    #if DEBUG
        static let enabledForTests = IrohaConnectReleasePolicy(isEnabled: true)
        static let disabledForTests = IrohaConnectReleasePolicy(isEnabled: false)
    #endif
}

protocol IrohaConnectUnavailableNoticePresenting: AnyObject {
    /// `true` while the notice is on screen, so repeated links don't stack sheets.
    var isPresentingNotice: Bool { get }

    /// Shows the notice over the visible screen. Returns `false` when nothing can
    /// present it yet; the coordinator then keeps it pending and tries again.
    func presentUnavailableNotice() -> Bool
}

final class IrohaConnectURLHandler: URLHandlingServiceProtocol {
    static let shared = IrohaConnectURLHandler()

    private let startSession: (URL) -> Void

    private init() {
        startSession = { url in
            IrohaConnectCoordinator.shared.start(with: url)
        }
    }

    init(startSession: @escaping (URL) -> Void) {
        self.startSession = startSession
    }

    func handle(url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "iroha" || scheme == "irohaconnect",
              url.host?.lowercased() == "connect" else {
            return false
        }

        DispatchQueue.main.async { [startSession] in
            startSession(url)
        }
        return true
    }
}

final class IrohaConnectCoordinator: NSObject, AuthorizationPresentable {
    static let shared = IrohaConnectCoordinator()

    private enum PendingApproval {
        case connection(IrohaConnectAccountDescriptor, IrohaConnectPermissions?)
        case signature(IrohaConnectPendingSignature)
    }

    private let policy: IrohaConnectReleasePolicy
    private let sessionFactory: (IrohaConnectWalletURI) throws -> IrohaConnectSessionService
    private let unavailableNotice: IrohaConnectUnavailableNoticePresenting
    private let notificationCenter: NotificationCenter
    private let pasteboard: PasteboardStringAccessing

    private var session: IrohaConnectSessionService?
    private var pendingApproval: PendingApproval?
    private var coveringWindow: UIWindow?
    private weak var previousKeyWindow: UIWindow?
    private weak var promptViewController: IrohaConnectPromptViewController?
    private var appName = IrohaConnectCoordinator.defaultAppName
    private var appURL: URL?
    private static let defaultAppName = "Iroha dApp"
    private var isWalletInterfaceReady = false
    private var isUnavailableNoticePending = false

    init(
        policy: IrohaConnectReleasePolicy = .production,
        sessionFactory: @escaping (IrohaConnectWalletURI) throws -> IrohaConnectSessionService = { handoff in
            IrohaConnectSessionService(handoff: handoff)
        },
        unavailableNotice: IrohaConnectUnavailableNoticePresenting = IrohaConnectUnavailableNoticePresenter(),
        notificationCenter: NotificationCenter = .default,
        pasteboard: PasteboardStringAccessing = UIPasteboard.general
    ) {
        self.policy = policy
        self.sessionFactory = sessionFactory
        self.unavailableNotice = unavailableNotice
        self.notificationCenter = notificationCenter
        self.pasteboard = pasteboard
        super.init()
        notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    deinit {
        notificationCenter.removeObserver(self)
    }

    /// Called once the unlocked wallet interface is in place. A link that arrived
    /// during launch or behind the PIN screen is answered only from here on.
    func setup() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            isWalletInterfaceReady = true
            presentUnavailableNoticeIfPossible()
        }
    }

    func throttle() {
        DispatchQueue.main.async { [weak self] in
            self?.isWalletInterfaceReady = false
        }
    }

    func start(with url: URL) {
        precondition(Thread.isMainThread)

        // Checked before the link is parsed: a disabled build never opens a
        // socket, creates a session, or loads signing material.
        guard policy.isEnabled else {
            requestUnavailableNotice()
            return
        }

        do {
            let handoff = try IrohaConnectWalletURI.parse(url)
            session?.delegate = nil
            session?.close()
            dismissPrompt()
            pendingApproval = nil
            appName = Self.defaultAppName
            appURL = nil

            let service = try sessionFactory(handoff)
            service.delegate = self
            session = service
            service.start()
        } catch let error as IrohaConnectError {
            presentError(message: error.localizedDescription)
        } catch {
            presentError(message: IrohaConnectError.invalidLink("").localizedDescription)
        }
    }

    func presentLanding(from presentingViewController: UIViewController?) {
        guard policy.isEnabled else {
            requestUnavailableNotice()
            return
        }

        guard let presentingViewController else {
            return
        }

        let landing = IrohaConnectLandingViewController()
        landing.onScan = { [weak self, weak landing] in
            guard let self, let landing else { return }
            presentScanner(from: landing)
        }
        landing.onPaste = { [weak self, weak landing] in
            guard let self, let landing else { return }
            handlePaste(from: landing)
        }

        let navigation = FearlessNavigationController(rootViewController: landing)
        navigation.modalPresentationStyle = .fullScreen
        landing.onClose = { [weak navigation] in
            navigation?.dismiss(animated: true)
        }
        presentingViewController.present(navigation, animated: true)
    }

    private func presentScanner(from viewController: UIViewController) {
        guard let scanner = ScanQRAssembly.configureRawModule(rawCodeOutput: self)?.view.controller else {
            presentError(message: "The QR scanner is unavailable on this device.", from: viewController)
            return
        }

        viewController.present(scanner, animated: true)
    }

    private func handlePaste(from viewController: UIViewController) {
        guard let literal = pasteboard.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: literal) else {
            presentError(message: "The clipboard doesn't contain an IrohaConnect link.", from: viewController)
            return
        }
        do {
            _ = try IrohaConnectWalletURI.parse(literal)
        } catch {
            presentError(message: error.localizedDescription, from: viewController)
            return
        }

        start(with: url)
    }

    private func presentPendingApprovalIfPossible() {
        guard UIApplication.shared.applicationState == .active,
              coveringWindow == nil,
              let pendingApproval else {
            return
        }

        let networkName = session?.handoff.profile.displayName ?? IrohaConnectProfile.taira.displayName
        let prompt: IrohaConnectPrompt
        switch pendingApproval {
        case let .connection(account, permissions):
            prompt = IrohaConnectPrompt(
                kind: .connection(permissions: permissions),
                appName: appName,
                appURL: appURL,
                networkName: networkName,
                accountID: account.accountID
            )
        case let .signature(request):
            prompt = IrohaConnectPrompt(
                kind: .transaction(request.review),
                appName: appName,
                appURL: appURL,
                networkName: networkName,
                accountID: request.account.accountID
            )
        }

        let controller = IrohaConnectPromptViewController(prompt: prompt)
        controller.onApprove = { [weak self, weak controller] in
            guard let self, let controller else { return }
            authorizePendingApproval(from: controller)
        }
        controller.onReject = { [weak self] in
            self?.rejectPendingApproval()
        }
        promptViewController = controller
        showCoveringWindow(controller: controller)
    }

    private func authorizePendingApproval(from controller: IrohaConnectPromptViewController) {
        authorize(animated: true, cancellable: true, from: controller) { [weak self, weak controller] approved in
            guard let self else { return }
            guard approved else {
                controller?.setActionsEnabled(true)
                return
            }
            guard let session else {
                dismissPrompt()
                return
            }

            switch pendingApproval {
            case let .connection(account, _):
                session.approveConnection(for: account)
            case let .signature(request):
                session.approveSignature(requestID: request.requestID)
            case .none:
                dismissPrompt()
            }
        }
    }

    private func rejectPendingApproval() {
        let rejected = pendingApproval
        pendingApproval = nil
        switch rejected {
        case let .signature(request):
            // Declining one transaction keeps the session; the dApp gets USER_REJECTED.
            session?.rejectSignature(requestID: request.requestID)
        case .connection, .none:
            let rejectedSession = session
            session = nil
            rejectedSession?.delegate = nil
            rejectedSession?.rejectConnection()
        }
        dismissPrompt()
    }

    private func showCoveringWindow(controller: UIViewController) {
        guard coveringWindow == nil,
              let scene = SceneWindowFinder.activeWindow()?.windowScene else {
            return
        }

        previousKeyWindow = SceneWindowFinder.activeWindow()
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .black
        window.rootViewController = controller
        window.alpha = 0
        window.isHidden = false
        window.makeKeyAndVisible()
        coveringWindow = window
        UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.22) {
            window.alpha = 1
        }
    }

    private func dismissPrompt(completion: (() -> Void)? = nil) {
        guard let window = coveringWindow else {
            completion?()
            return
        }

        let duration = UIAccessibility.isReduceMotionEnabled ? 0 : 0.18
        UIView.animate(withDuration: duration, animations: {
            window.alpha = 0
        }, completion: { [weak self] _ in
            window.isHidden = true
            window.rootViewController = nil
            self?.coveringWindow = nil
            self?.promptViewController = nil
            self?.previousKeyWindow?.makeKeyAndVisible()
            completion?()
            // A request that arrived while the previous prompt was fading out is shown now.
            self?.presentPendingApprovalIfPossible()
        })
    }

    private func presentError(message: String, from viewController: UIViewController? = nil) {
        let presenter = viewController ?? UIApplication.topViewController()
        guard let presenter else {
            return
        }

        let alert = UIAlertController(title: "IrohaConnect", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        presenter.present(alert, animated: true)
    }

    private func requestUnavailableNotice() {
        guard !isUnavailableNoticePending, !unavailableNotice.isPresentingNotice else {
            return
        }

        isUnavailableNoticePending = true
        presentUnavailableNoticeIfPossible()
    }

    private func presentUnavailableNoticeIfPossible() {
        guard isUnavailableNoticePending,
              isWalletInterfaceReady,
              !unavailableNotice.isPresentingNotice else {
            return
        }

        if unavailableNotice.presentUnavailableNotice() {
            isUnavailableNoticePending = false
        }
    }

    @objc private func applicationDidBecomeActive() {
        presentPendingApprovalIfPossible()
        presentUnavailableNoticeIfPossible()
    }
}

extension IrohaConnectCoordinator: IrohaConnectSessionServiceDelegate {
    func irohaConnectSession(
        _ session: IrohaConnectSessionService,
        requestsConnection open: IrohaConnectOpenFrame,
        account: IrohaConnectAccountDescriptor
    ) {
        guard session === self.session else { return }
        appName = irohaConnectSanitizedReviewText(open.appMetadata?.name ?? Self.defaultAppName, maximum: 128)
        appURL = Self.normalizedAppURL(open.appMetadata?.url)
        pendingApproval = .connection(account, open.permissions)
        presentPendingApprovalIfPossible()
    }

    /// The app's claimed origin, shown only when it is an https URL (or http on loopback) without credentials.
    static func normalizedAppURL(_ value: String?) -> URL? {
        guard let value, let components = URLComponents(string: value), let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil else {
            return nil
        }
        let isLoopback = host == "localhost" || host == "127.0.0.1" || host == "[::1]" || host == "::1"
        guard components.scheme == "https" || (components.scheme == "http" && isLoopback) else {
            return nil
        }
        return components.url
    }

    func irohaConnectSessionDidApprove(_ session: IrohaConnectSessionService) {
        guard session === self.session else { return }
        pendingApproval = nil
        dismissPrompt()
    }

    func irohaConnectSession(_ session: IrohaConnectSessionService, requestsSignature request: IrohaConnectPendingSignature) {
        guard session === self.session else { return }
        pendingApproval = .signature(request)
        presentPendingApprovalIfPossible()
    }

    func irohaConnectSession(_ session: IrohaConnectSessionService, didRefuse notice: IrohaConnectNotice) {
        guard session === self.session else { return }
        if notice == .requestExpired, case .signature = pendingApproval {
            pendingApproval = nil
            dismissPrompt { [weak self] in
                self?.presentError(message: Self.message(for: notice))
            }
            return
        }
        presentError(message: Self.message(for: notice))
    }

    /// One short sentence: what happened and that nothing was signed.
    static func message(for notice: IrohaConnectNotice) -> String {
        switch notice {
        case .rawSigningUnavailable:
            return "The app asked Fearless to sign raw data. Fearless only signs transactions it can show you, so nothing was signed."
        case .requestInProgress:
            return "The app sent another request while one was waiting, so Fearless declined it."
        case .permissionDenied:
            return "The app didn't ask permission to sign transactions when it connected, so nothing was signed."
        case .transactionInvalid:
            return "Fearless couldn't read this transaction, so it wasn't signed."
        case .transactionUnsupported:
            return "Fearless can't show this kind of transaction yet, so it wasn't signed."
        case .transactionWrongAccount:
            return "This transaction is for a different account, so it wasn't signed."
        case .requestExpired:
            return "The signature request expired, so nothing was signed."
        }
    }

    func irohaConnectSessionDidCompleteSignature(_ session: IrohaConnectSessionService) {
        guard session === self.session else { return }
        pendingApproval = nil
        dismissPrompt()
    }

    func irohaConnectSession(_ session: IrohaConnectSessionService, didCloseWith error: Error?) {
        guard session === self.session else { return }
        self.session = nil
        pendingApproval = nil

        let message = error.flatMap { ($0 as? LocalizedError)?.errorDescription ?? $0.localizedDescription }
        dismissPrompt { [weak self] in
            if let message {
                self?.presentError(message: message)
            }
        }
    }
}

extension IrohaConnectCoordinator: ScanQRRawCodeOutput {
    func shouldAccept(rawCode: String) -> Bool {
        guard let url = URL(string: rawCode) else {
            return false
        }
        return (try? IrohaConnectWalletURI.parse(url)) != nil
    }

    func didFinishWith(rawCode: String) {
        guard let url = URL(string: rawCode) else {
            presentError(message: IrohaConnectError.invalidLink("").localizedDescription)
            return
        }
        start(with: url)
    }
}
