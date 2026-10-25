import UIKit
import WebKit

final class LegacyTonConnectApprovalViewController: UIViewController, ControllerBackedProtocol {
    var onApprove: (() -> Void)?
    var completion: ((Bool) -> Void)?
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
        guard let callback = completion else { return }
        completion = nil
        onApprove = nil
        if let presentingViewController {
            presentingViewController.dismiss(animated: true) { callback(approved) }
        } else {
            callback(false)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || presentingViewController == nil { finish(approved: false) }
    }
}

final class LegacyTonConnectSessionsViewController: UITableViewController {
    private let coordinator: LegacyTonConnectCoordinator
    private var sessions: [LegacyTonConnectSession] = []

    init(coordinator: LegacyTonConnectCoordinator) {
        self.coordinator = coordinator
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
        reload()
    }

    @objc private func reload() {
        Task { @MainActor in
            defer { refreshControl?.endRefreshing() }
            do {
                sessions = try await coordinator.selectedSessions()
                tableView.reloadData()
            } catch { show(error) }
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
                    try await self.coordinator.disconnect(session)
                    self.reload()
                    completion(true)
                } catch {
                    self.show(error)
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
