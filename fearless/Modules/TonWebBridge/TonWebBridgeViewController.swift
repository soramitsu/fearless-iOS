import UIKit
import WebKit
import SoraFoundation

protocol TonWebBridgeViewOutput: AnyObject {
    func didLoad(view: TonWebBridgeViewInput)
    func didLoadInitialURL()
}

final class TonWebBridgeViewController: UIViewController, ViewHolder, HiddableBarWhenPushed, LoadableViewProtocol {
    typealias RootViewType = TonWebBridgeViewLayout
    
    var loadableContentView: UIView {
        rootView.webView
    }

    // MARK: Private properties

    private let output: TonWebBridgeViewOutput

    // MARK: - State

    private var url: URL {
        didSet {
            guard url.host != oldValue.host else {
                return
            }
            didUpdateUrl()
        }
    }

    private var didLoadInitialURL = false {
        didSet {
            guard didLoadInitialURL else { return }
            output.didLoadInitialURL()
            didStopLoading()
        }
    }

    private var canGoBack: NSKeyValueObservation?

    // MARK: - Constructor

    init(
        title: String,
        initialUrl: URL,
        output: TonWebBridgeViewOutput,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.output = output
        url = initialUrl
        super.init(nibName: nil, bundle: nil)
        self.title = title
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        view = TonWebBridgeViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        setupDelegate()
        bindActions()
        didUpdateUrl()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !didLoadInitialURL {
            didStartLoading()
        }
    }

    // MARK: - Private methods

    private func setupDelegate() {
        rootView.webView.navigationDelegate = self
        rootView.webView.uiDelegate = self
    }

    private func bindActions() {
        rootView.headerView.closeButton.addAction { [weak self] in
            self?.rootView.webView.scrollView.layer.masksToBounds = true
            self?.rootView.webView.layer.masksToBounds = true
            self?.dismiss(animated: true)
        }
        rootView.headerView.backButton.addAction { [weak self] in
            self?.rootView.webView.goBack()
        }

        rootView.headerView.backButton.isHidden = true
        canGoBack = rootView.webView.observe(\.canGoBack, options: .new) { [weak self] _, value in
            guard let canGoBack = value.newValue else { return }
            self?.rootView.headerView.backButton.isHidden = !canGoBack
        }
    }

    private func didUpdateUrl() {
        rootView.headerView.setTitle(title)
        if let serverTrust = rootView.webView.serverTrust {
            SecTrustEvaluateAsyncWithError(serverTrust, .main) { _, isSecured, _ in
                self.rootView.headerView.setSubtitle(self.url.host ?? "", isSecured: isSecured)
            }
        } else {
            let components = URLComponents(string: url.absoluteString)
            let isSecured = components?.scheme == "https"
            rootView.headerView.setSubtitle(url.host ?? "", isSecured: isSecured)
        }
    }
}

// MARK: - TonWebBridgeViewInput

extension TonWebBridgeViewController: TonWebBridgeViewInput {
    func didReceive(configuration: WKWebViewConfiguration) {
        rootView.setupWebView(with: configuration)
        setupDelegate()

        var urlRequest = URLRequest(url: url)
        urlRequest.httpShouldHandleCookies = false
        urlRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        rootView.webView.load(urlRequest)
    }

    func evaulateJavaScript(_ javaScript: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Swift.Error>) in
            rootView.webView.evaluateJavaScript(javaScript) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - Localizable

extension TonWebBridgeViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

// MARK: - WKNavigationDelegate

extension TonWebBridgeViewController: WKNavigationDelegate {
    public func webView(
        _ webView: WKWebView,
        didFinish _: WKNavigation!
    ) {
        guard let url = webView.url else { return }
        if !didLoadInitialURL {
            didLoadInitialURL = true
        }
        self.url = url
    }

    public func webView(
        _: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        if let url = navigationAction.request.url, let host = url.host, host.contains("t.me") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            return .cancel
        }
        return .allow
    }
}

// MARK: - WKUIDelegate

extension TonWebBridgeViewController: WKUIDelegate {
    public func webView(
        _ webView: WKWebView,
        createWebViewWith _: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures _: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}
