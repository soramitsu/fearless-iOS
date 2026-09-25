import UIKit

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
        case connection(IrohaConnectAccountDescriptor)
        case signature(IrohaConnectAccountDescriptor, IrohaConnectSignRawRequest)
    }

    private var session: IrohaConnectSessionService?
    private var pendingApproval: PendingApproval?
    private var coveringWindow: UIWindow?
    private weak var previousKeyWindow: UIWindow?
    private weak var promptViewController: IrohaConnectPromptViewController?
    private var appName = "SORA dApp"
    private var appURL: URL?

    override private init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func start(with url: URL) {
        precondition(Thread.isMainThread)

        do {
            let handoff = try IrohaConnectWalletURI.parse(url)
            session?.delegate = nil
            session?.close()
            dismissPrompt()
            pendingApproval = nil
            appName = "SORA dApp"
            appURL = nil

            let service = try IrohaConnectSessionService(handoff: handoff)
            service.delegate = self
            session = service
            service.start()
        } catch {
            presentError(
                message: "This link is not a canonical Taira IrohaConnect request. " +
                    "Create a fresh pairing request in Uranai and try again."
            )
        }
    }

    func presentLanding(from presentingViewController: UIViewController?) {
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
        guard let literal = UIPasteboard.general.string,
              let url = URL(string: literal),
              (try? IrohaConnectWalletURI.parse(url)) != nil else {
            presentError(
                message: "The clipboard does not contain a valid Taira IrohaConnect pairing link.",
                from: viewController
            )
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

        let prompt: IrohaConnectPrompt
        switch pendingApproval {
        case let .connection(account):
            prompt = IrohaConnectPrompt(
                kind: .connection,
                appName: appName,
                appURL: appURL,
                networkName: "Taira Testnet",
                accountID: account.accountID
            )
        case let .signature(account, request):
            prompt = IrohaConnectPrompt(
                kind: .signature(payload: request.message),
                appName: appName,
                appURL: appURL,
                networkName: "Taira Testnet",
                accountID: account.accountID
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
            case let .connection(account):
                session.approveConnection(for: account)
            case let .signature(account, _):
                session.approveSignature(for: account)
            case .none:
                dismissPrompt()
            }
        }
    }

    private func rejectPendingApproval() {
        pendingApproval = nil
        let rejectedSession = session
        session = nil
        rejectedSession?.delegate = nil
        rejectedSession?.close()
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

    @objc private func applicationDidBecomeActive() {
        presentPendingApprovalIfPossible()
    }
}

extension IrohaConnectCoordinator: IrohaConnectSessionServiceDelegate {
    func irohaConnectSession(
        _ session: IrohaConnectSessionService,
        requestsConnection open: IrohaConnectOpenFrame,
        account: IrohaConnectAccountDescriptor
    ) {
        guard session === self.session else { return }
        appName = open.appMetadata?.name ?? "SORA dApp"
        appURL = open.appMetadata?.url
        pendingApproval = .connection(account)
        presentPendingApprovalIfPossible()
    }

    func irohaConnectSessionDidApprove(_ session: IrohaConnectSessionService) {
        guard session === self.session else { return }
        pendingApproval = nil
        dismissPrompt()
    }

    func irohaConnectSession(
        _ session: IrohaConnectSessionService,
        requestsSignature request: IrohaConnectSignRawRequest,
        account: IrohaConnectAccountDescriptor
    ) {
        guard session === self.session else { return }
        pendingApproval = .signature(account, request)
        presentPendingApprovalIfPossible()
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

        let message = error?.localizedDescription
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
            presentError(message: "The scanned pairing request is invalid.")
            return
        }
        start(with: url)
    }
}
