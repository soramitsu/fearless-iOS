import UIKit
import WebKit

final class LegacyTonConnectApprovalViewController: UIViewController, ControllerBackedProtocol {
    var onApprove: (() -> Void)?
    /// true: approved; false: declined by the user; nil: not answered (closed by the lock or a throttle).
    var completion: ((Bool?) -> Void)?
    /// Asked when a dismissal starts, never after it: whether the sheet is closing for the lock or a throttle.
    var isInterrupted: () -> Bool = { false }
    private var externalDismissalOutcome: Bool??
    /// A swipe is still being dragged: nothing is decided until UIKit commits or cancels it.
    private var isInteractivelyDismissing = false
    /// The first outcome requested during that drag (for example a throttle's interruption), resolved when it was
    /// requested and applied unchanged once a cancelled swipe has settled. `nil`: none requested.
    private var finishAfterInteraction: Bool??
    private let details: String

    init(title: String, details: String) {
        self.details = details
        super.init(nibName: nil, bundle: nil)
        self.title = title
        modalPresentationStyle = .formSheet
    }

    required init?(coder _: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let scroll = UIScrollView()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        let body = UILabel()
        body.text = details
        body.font = .preferredFont(forTextStyle: .body)
        body.adjustsFontForContentSizeCategory = true
        body.numberOfLines = 0
        body.accessibilityIdentifier = "tonconnect.request.details"
        let approve = UIButton(type: .system)
        approve.setTitle("Approve", for: .normal)
        approve.accessibilityIdentifier = "tonconnect.approve"
        approve.addTarget(self, action: #selector(approvePressed), for: .touchUpInside)
        let cancel = UIButton(type: .system)
        cancel.setTitle("Decline", for: .normal)
        cancel.addTarget(self, action: #selector(cancelPressed), for: .touchUpInside)
        [titleLabel, body, approve, cancel].forEach(stack.addArrangedSubview)
        view.addSubview(scroll)
        scroll.addSubview(stack)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40),
            approve.heightAnchor.constraint(greaterThanOrEqualToConstant: 48),
            cancel.heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
        ])
    }

    @objc private func approvePressed() { onApprove?() }
    @objc private func cancelPressed() { finish(approved: false) }

    func finish(approved: Bool) {
        guard completion != nil else { return }
        // Decided now, as the sheet starts to close; a lock or throttle during the animation changes nothing.
        finish(resolved: approved ? true : (isInterrupted() ? nil : false))
    }

    /// Closes the sheet with no answer (the PIN closed when the app went to the background): nothing is declined.
    func finishUnanswered() {
        guard completion != nil else { return }
        finish(resolved: nil)
    }

    private func finish(resolved outcome: Bool?) {
        guard let callback = completion else { return }
        guard !isInteractivelyDismissing else {
            // Keep the callbacks until UIKit has settled the swipe; the first request wins, unchanged.
            if finishAfterInteraction == nil {
                finishAfterInteraction = .some(outcome)
            }
            return
        }
        completion = nil
        onApprove = nil
        if let captured = externalDismissalOutcome {
            // Already closing from outside (a committed swipe, the lock): that decided it, once.
            callback(captured)
            return
        }
        if let presentingViewController {
            presentingViewController.dismiss(animated: true) { callback(outcome) }
        } else {
            callback(outcome == true ? false : outcome)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Back on screen after a cancelled swipe (UIKit balances the appearance calls): nothing was decided, and a
        // finish requested during the drag applies now, as resolved when it was requested.
        externalDismissalOutcome = nil
        guard isInteractivelyDismissing else { return }
        isInteractivelyDismissing = false
        if let pending = finishAfterInteraction {
            finishAfterInteraction = nil
            finish(resolved: pending)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Closed from outside (the lock, a swipe): what it means is decided as the dismissal starts. A swipe can
        // still be cancelled, so until it ends nothing is delivered and finishes wait.
        guard completion != nil, isBeingDismissed || presentingViewController == nil else { return }
        externalDismissalOutcome = .some(isInterrupted() ? nil : false)
        isInteractivelyDismissing = transitionCoordinator?.isInteractive == true
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard isBeingDismissed || presentingViewController == nil else { return }
        // Gone, a committed swipe included: its outcome is delivered once; a finish requested meanwhile is moot.
        isInteractivelyDismissing = false
        finishAfterInteraction = nil
        deliverExternalDismissal()
    }

    private func deliverExternalDismissal() {
        guard let callback = completion else { return }
        completion = nil
        onApprove = nil
        callback(externalDismissalOutcome ?? (isInterrupted() ? nil : false))
    }
}

/// The one-time offer to retire transport keys an older version kept in the database: one warning, one action, and
/// the hosts it applies to.
enum LegacyTonConnectReconnectOffer {
    /// Hosts named before the rest are left out.
    static let maximumListedHosts = 5

    static func alert(
        for sessions: [LegacyTonConnectSession],
        languages: [String]?,
        disconnect: @escaping () -> Void,
        keep: @escaping () -> Void
    ) -> UIAlertController {
        var hosts: [String] = []
        for session in sessions {
            let host = session.appUrl.host ?? session.appUrl.absoluteString
            if !hosts.contains(host) {
                hosts.append(host)
            }
        }
        var listed = hosts.prefix(maximumListedHosts).joined(separator: "\n")
        if hosts.count > maximumListedHosts {
            listed += "\n…"
        }
        let alert = UIAlertController(
            title: R.string.localizable.tonconnectReconnectTitle(preferredLanguages: languages),
            message: R.string.localizable.tonconnectReconnectMessage(preferredLanguages: languages) + "\n\n" + listed,
            preferredStyle: .alert
        )
        let keepConnected = UIAlertAction(
            title: R.string.localizable.tonconnectReconnectKeep(preferredLanguages: languages),
            style: .cancel
        ) { _ in keep() }
        let reconnect = UIAlertAction(
            title: R.string.localizable.tonconnectReconnectAction(preferredLanguages: languages),
            style: .destructive
        ) { _ in disconnect() }
        alert.addAction(keepConnected)
        alert.addAction(reconnect)
        // No preferred action: Return on a hardware keyboard must never choose the destructive answer.
        return alert
    }
}

final class LegacyTonConnectSessionsViewController: UITableViewController {
    private let coordinator: LegacyTonConnectCoordinator
    /// Where the lock, protected-data and activation notices that resume a held-back load arrive.
    private let notificationCenter: NotificationCenter
    /// The app is in front and the device unlocked (protected data available). A Keychain read can fail for either
    /// alone, like it can behind the app's own lock.
    private let isDeviceReadable: () -> Bool
    private var sessions: [LegacyTonConnectSession] = []
    /// The offer to reconnect is on screen or its answer is being carried out.
    private var isOfferingReconnect = false
    /// The last load failed, so `sessions` is not the stored list: the next appearance or unlock loads again.
    private var needsReload = false
    /// That failure was not shown because the lock, a locked device or an inactive app held it back.
    private var failureWasHeldBack = false
    /// A load is running; one asked for meanwhile runs once it ends, and a failure it supersedes is not shown.
    private var isLoading = false
    private var loadsAgain = false
    /// An offer check asked for while another ran (for example on an unlock) runs once that one ends unanswered.
    private var checksOfferAgain = false
    private var resumeObservers: [NSObjectProtocol] = []

    init(
        coordinator: LegacyTonConnectCoordinator,
        notificationCenter: NotificationCenter = .default,
        isDeviceReadable: @escaping () -> Bool = {
            UIApplication.shared.applicationState == .active && UIApplication.shared.isProtectedDataAvailable
        }
    ) {
        self.coordinator = coordinator
        self.notificationCenter = notificationCenter
        self.isDeviceReadable = isDeviceReadable
        super.init(style: .insetGrouped)
    }

    required init?(coder _: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "TonConnect"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(close))
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Connect", style: .plain, target: self, action: #selector(connect)),
            UIBarButtonItem(title: "Browser", style: .plain, target: self, action: #selector(browse))
        ]
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(reload), for: .valueChanged)
        // A load or offer held back by the lock, a locked device or an inactive app happens once the wallet and the
        // device are unlocked and the app is in front, while this list is on screen.
        // Each runs at once, ahead of any load completion already queued on the main actor.
        resumeObservers = [
            notificationCenter.addObserver(
                forName: ApplicationLockState.didChangeNotification, object: ApplicationLockState.shared, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.resume() }
            }
        ]
        let deviceTriggers: [Notification.Name] = [
            UIApplication.protectedDataDidBecomeAvailableNotification,
            UIApplication.didBecomeActiveNotification
        ]
        for name in deviceTriggers {
            let observer = notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.resume(fromDevice: true) }
            }
            resumeObservers.append(observer)
        }
        reload()
    }

    deinit {
        resumeObservers.forEach { notificationCenter.removeObserver($0) }
    }

    /// The wallet is locked, or the device is, or the app is not in front: a read may fail for that alone, and
    /// nothing is offered.
    private var isHeldBack: Bool {
        ApplicationLockState.shared.isLocked || !isDeviceReadable()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // The first load can finish before the sheet is on screen; the offer is made once it is.
        resume()
    }

    /// On screen and not held back: loads again after a failed load or one still running (each load then offers),
    /// otherwise offers. `fromDevice`: the device was unlocked or the app came to the front. A failure that was shown
    /// is not loaded (and shown) again for that each time, only one that was held back.
    private func resume(fromDevice: Bool = false) {
        guard viewIfLoaded?.window != nil, !isHeldBack else { return }
        if isLoading || (needsReload && (failureWasHeldBack || !fromDevice)) {
            reload()
        } else if !needsReload {
            requestOffer()
        }
    }

    @objc private func reload() {
        guard !isLoading else {
            loadsAgain = true
            return
        }
        isLoading = true
        let startedLocked = isHeldBack
        Task { @MainActor in
            let outcome: Result<[LegacyTonConnectSession], Error>
            do {
                outcome = .success(try await coordinator.selectedSessions())
            } catch {
                outcome = .failure(error)
            }
            isLoading = false
            let again = loadsAgain
            loadsAgain = false
            switch outcome {
            case let .success(loaded):
                sessions = loaded
                needsReload = false
                failureWasHeldBack = false
                tableView.reloadData()
            case let .failure(error):
                needsReload = true
                guard !again else { break }
                refreshControl?.endRefreshing()
                // A load that ran behind the lock, on a locked device or in an inactive app (the Keychain may have
                // been unreadable) is not reported: the list loads again once that ends, at once if it ended while
                // the load ran, with or without a notice.
                failureWasHeldBack = startedLocked || isHeldBack
                if failureWasHeldBack {
                    if !isHeldBack, viewIfLoaded?.window != nil {
                        reload()
                    }
                } else {
                    show(error)
                }
                return
            }
            if again {
                // Asked for while this load ran (an unlock, a refresh): that load decides what is shown.
                reload()
                return
            }
            refreshControl?.endRefreshing()
            requestOffer()
        }
    }

    private func requestOffer() {
        guard !isOfferingReconnect else {
            checksOfferAgain = true
            return
        }
        Task { @MainActor in await offerReconnectIfNeeded() }
    }

    /// Offers, once, to reconnect the listed bridge sessions whose keys an older version kept in the database. Asked
    /// only while this list is on screen with nothing over it and nothing holds it back: after each load, each time
    /// the list appears and after an unlock or activation. Until the user answers, the next of those asks again.
    private func offerReconnectIfNeeded() async {
        guard !isOfferingReconnect else {
            checksOfferAgain = true
            return
        }
        isOfferingReconnect = true
        checksOfferAgain = false
        let waiting = ((try? await coordinator.sessionsToReconnect()) ?? []).filter { sessions.contains($0) }
        guard !waiting.isEmpty, viewIfLoaded?.window != nil, presentedViewController == nil, !isHeldBack else {
            isOfferingReconnect = false
            if checksOfferAgain {
                // Something that may change the answer (an unlock) happened during this check.
                checksOfferAgain = false
                requestOffer()
            }
            return
        }
        let alert = LegacyTonConnectReconnectOffer.alert(
            for: waiting,
            languages: LegacyTonConnectProtocol.languages,
            disconnect: { [weak self] in self?.answerReconnectOffer(waiting, reconnect: true) },
            keep: { [weak self] in self?.answerReconnectOffer(waiting, reconnect: false) }
        )
        present(alert, animated: true)
        if alert.presentingViewController == nil {
            // UIKit refused it (for example mid-transition): nothing was asked, so the next load asks.
            isOfferingReconnect = false
            if checksOfferAgain {
                checksOfferAgain = false
                requestOffer()
            }
        }
    }

    private func answerReconnectOffer(_ waiting: [LegacyTonConnectSession], reconnect: Bool) {
        Task { @MainActor in
            defer { isOfferingReconnect = false }
            do {
                if reconnect {
                    try await coordinator.reconnect(waiting)
                } else {
                    try await coordinator.keepWithoutReconnecting(waiting)
                }
            } catch {
                show(error)
            }
            if reconnect {
                reload()
            }
        }
    }

    @objc private func close() { dismiss(animated: true) }

    @objc private func connect() {
        let prompt = UIAlertController(title: "Connect a TON application", message: "Paste the TonConnect link from the application.", preferredStyle: .alert)
        prompt.addTextField { $0.placeholder = "tc://…"; $0.autocapitalizationType = .none }
        prompt.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        prompt.addAction(UIAlertAction(title: "Continue", style: .default) { [weak self, weak prompt] _ in
            guard let self, let text = prompt?.textFields?.first?.text, let url = URL(string: text) else { return }
            coordinator.open(url)
        })
        present(prompt, animated: true)
    }

    @objc private func browse() {
        let prompt = UIAlertController(title: "Open a TON application", message: "Enter the application's HTTPS address.", preferredStyle: .alert)
        prompt.addTextField { $0.placeholder = "https://…"; $0.keyboardType = .URL; $0.autocapitalizationType = .none }
        prompt.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        prompt.addAction(UIAlertAction(title: "Open", style: .default) { [weak self, weak prompt] _ in
            guard let self, let text = prompt?.textFields?.first?.text, let url = URL(string: text), LegacyTonConnectProtocol.origin(url) != nil else { return }
            navigationController?.pushViewController(LegacyTonConnectBrowserViewController(url: url, coordinator: coordinator), animated: true)
        })
        present(prompt, animated: true)
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int { max(sessions.count, 1) }

    override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        guard sessions.indices.contains(indexPath.row) else {
            cell.textLabel?.text = "No connected applications"
            cell.selectionStyle = .none
            return cell
        }
        let session = sessions[indexPath.row]
        cell.textLabel?.text = session.name
        cell.detailTextLabel?.text = session.appUrl.absoluteString
        cell.detailTextLabel?.numberOfLines = 0
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard sessions.indices.contains(indexPath.row) else { return }
        navigationController?.pushViewController(LegacyTonConnectBrowserViewController(url: sessions[indexPath.row].appUrl, coordinator: coordinator), animated: true)
    }

    override func tableView(_: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard sessions.indices.contains(indexPath.row) else { return nil }
        let session = sessions[indexPath.row]
        let action = UIContextualAction(style: .destructive, title: "Disconnect") { [weak self] _, _, completion in
            guard let self else { completion(false); return }
            Task { @MainActor in
                do {
                    // Returns once the session is removed here; the application is told in the background.
                    try await self.coordinator.disconnect(session)
                    self.reload()
                    completion(true)
                } catch {
                    self.show(error)
                    if error is LegacyTonConnectUnfinishedRemoval {
                        // Retired for good: it leaves the list now; the next read finishes its removal.
                        self.reload()
                    }
                    completion(false)
                }
            }
        }
        return UISwipeActionsConfiguration(actions: [action])
    }

    private func show(_ error: Error) {
        let alert = UIAlertController(title: "TonConnect", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

private final class LegacyTonConnectWeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var receiver: LegacyTonConnectBrowserViewController?
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        receiver?.userContentController(userContentController, didReceive: message)
    }
}

final class LegacyTonConnectBrowserViewController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate {
    private let startURL: URL
    private let coordinator: LegacyTonConnectCoordinator
    private(set) var webView: WKWebView!

    init(url: URL, coordinator: LegacyTonConnectCoordinator) {
        startURL = url
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder _: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        let content = WKUserContentController()
        let handler = LegacyTonConnectWeakScriptHandler()
        handler.receiver = self
        content.add(handler, name: "legacyTonConnect")
        content.addUserScript(WKUserScript(source: Self.script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = content
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        if LegacyTonConnectProtocol.origin(startURL) != nil { webView.load(URLRequest(url: startURL)) }
        title = startURL.host
    }

    func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame,
              let originURL = message.frameInfo.request.url,
              let currentURL = webView.url,
              let origin = LegacyTonConnectProtocol.origin(originURL),
              LegacyTonConnectProtocol.origin(currentURL) == origin,
              message.frameInfo.securityOrigin.protocol == "https",
              let raw = message.body as? String, raw.utf8.count <= LegacyTonConnectProtocol.maximumMessageBytes,
              let invocation = try? LegacyTonConnectJSInvocation.decode(Data(raw.utf8)) else { return }
        Task { @MainActor in
            let result: Data
            let success: Bool
            do {
                result = try await invoke(invocation, origin: originURL)
                success = true
            } catch {
                result = Data(error.localizedDescription.utf8)
                success = false
            }
            guard let currentURL = webView.url, LegacyTonConnectProtocol.origin(currentURL) == origin else { return }
            try? await webView.callAsyncJavaScript(
                "window.Fearless?.tonconnect?._complete(id, success, result);",
                arguments: ["id": invocation.id, "success": success, "result": String(data: result, encoding: .utf8) ?? ""],
                in: nil, contentWorld: .page
            )
        }
    }

    private func invoke(_ invocation: LegacyTonConnectJSInvocation, origin: URL) async throws -> Data {
        switch invocation.method {
        case "restoreConnection": return try await coordinator.restoreJS(origin: origin)
        case "connect":
            guard invocation.version == 2, let payload = invocation.payload else { throw LegacyTonConnectError.invalidRequest }
            let request = try JSONDecoder().decode(LegacyTonConnectConnectRequest.self, from: Data(payload.utf8)).validated()
            return try await coordinator.connectJS(request: request, origin: origin)
        case "send":
            guard let payload = invocation.payload else { throw LegacyTonConnectError.invalidRequest }
            return try await coordinator.handleJS(Data(payload.utf8), origin: origin)
        case "disconnect":
            let data = try JSONSerialization.data(withJSONObject: ["id": invocation.id, "method": "disconnect", "params": []])
            return try await coordinator.handleJS(data, origin: origin)
        default: throw LegacyTonConnectError.unsupportedRequest
        }
    }

    func webView(_: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if LegacyTonConnectProtocol.canonicalLink(url) != nil {
            coordinator.open(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(LegacyTonConnectProtocol.origin(url) == nil ? .cancel : .allow)
        }
    }

    static var script: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let encodedVersion = (try? JSONSerialization.data(withJSONObject: version, options: [.fragmentsAllowed]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "\"unknown\""
        return """
        (() => {
          const pending = new Map(), listeners = new Set();
          const invoke = (method, payload, version) => new Promise((resolve, reject) => {
            if (pending.size >= 32) { reject(new Error('Too many pending requests')); return; }
            const id = crypto.getRandomValues(new Uint32Array(4)).join('-');
            pending.set(id, { resolve, reject });
            window.webkit.messageHandlers.legacyTonConnect.postMessage(JSON.stringify({ id, method, payload, version }));
          });
          const wallet = {
            isWalletBrowser: true, protocolVersion: 2,
            deviceInfo: { platform: 'iphone', appName: 'Fearless', appVersion: \(encodedVersion), maxProtocolVersion: 2, features: [{ name: 'SendTransaction', maxMessages: 4 }] },
            connect: (version, request) => invoke('connect', JSON.stringify(request), version),
            restoreConnection: () => invoke('restoreConnection'),
            send: (request) => invoke('send', JSON.stringify(request)),
            disconnect: () => invoke('disconnect').then(() => listeners.forEach(cb => cb({ event: 'disconnect', id: Date.now(), payload: {} }))),
            listen: (callback) => { listeners.add(callback); return () => listeners.delete(callback); },
            _complete: (id, success, result) => {
              const request = pending.get(id); if (!request) return; pending.delete(id);
              if (success) { try { request.resolve(JSON.parse(result)); } catch { request.reject(new Error('Invalid wallet response')); } }
              else request.reject(new Error(result));
            }
          };
          window.Fearless = { ...(window.Fearless || {}), tonconnect: wallet };
        })();
        """
    }
}

struct LegacyTonConnectJSInvocation: Decodable {
    let id: String
    let method: String
    let payload: String?
    let version: Int?

    static func decode(_ data: Data) throws -> Self {
        guard data.count <= LegacyTonConnectProtocol.maximumMessageBytes else { throw LegacyTonConnectError.invalidRequest }
        let value = try JSONDecoder().decode(Self.self, from: data)
        guard !value.id.isEmpty, value.id.utf8.count <= 128,
              ["connect", "restoreConnection", "send", "disconnect"].contains(value.method) else { throw LegacyTonConnectError.invalidRequest }
        return value
    }
}
