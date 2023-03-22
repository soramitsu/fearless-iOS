import WebKit
import UIKit
import SoraSwiftUI

final class SCXOneViewController: UIViewController {
    // MARK: Private properties

    private let output: SCXOneViewOutput
    private var rootView: WKWebView {
        view as! WKWebView
    }

    // MARK: - Constructor

    init(
        output: SCXOneViewOutput
    ) {
        self.output = output
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        super.loadView()
        view = WKWebView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        rootView.navigationDelegate = self
        output.didLoad(view: self)
    }

    // MARK: - Private methods
}

// MARK: - SCXOneViewInput

extension SCXOneViewController: SCXOneViewInput {
    func startLoading(with htmlString: String) {
        rootView.loadHTMLString(htmlString, baseURL: nil)
    }
}

extension SCXOneViewController: LoadableViewProtocol, WKNavigationDelegate {
    func webView(_: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
        didStartLoading()
    }

    func webView(_: WKWebView, didFail _: WKNavigation!, withError _: Error) {
        didStopLoading()
    }

    func webView(_: WKWebView, didFinish _: WKNavigation!) {
        didStopLoading()
    }
}
