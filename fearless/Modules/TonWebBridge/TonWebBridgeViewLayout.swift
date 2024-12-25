import UIKit
import WebKit

final class TonWebBridgeViewLayout: UIView {
    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    lazy var headerView = TonWebBridgeHeaderView()
    lazy var webView = WKWebView(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        headerView.closeButton.rounded()
        headerView.backButton.rounded()
    }

    func setupWebView(with configuration: WKWebViewConfiguration) {
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.backgroundColor = R.color.colorBlack19()
        webView.scrollView.backgroundColor = R.color.colorBlack19()
        webView.isOpaque = false
        webView.scrollView.layer.masksToBounds = false
        webView.layer.masksToBounds = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        setupLayout()
    }

    // MARK: - Private methods

    private func setupLayout() {
        backgroundColor = R.color.colorBlack19()
        addSubview(webView)
        addSubview(headerView)

        headerView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
            make.leading.trailing.equalToSuperview()
        }
        webView.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
        }
    }

    private func applyLocalization() {}
}
