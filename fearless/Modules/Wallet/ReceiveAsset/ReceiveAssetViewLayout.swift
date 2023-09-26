import UIKit

final class ReceiveAssetViewLayout: UIView {
    private enum LayoutConstants {
        static let cornerRadius: CGFloat = 20.0
        static let headerHeight: CGFloat = 56.0
        static let qrImageSize: CGFloat = 240
        static let verticalOffset: CGFloat = 12
        static let infoIconSize: CGFloat = 12
        static let infoViewsOffset: CGFloat = 10
    }

    private let indicator = UIFactory.default.createIndicatorView()

    private let titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.font = .h3Title
        titleLabel.textAlignment = .left
        return titleLabel
    }()

    let qrView = QRView()

    private let walletLabel: UILabel = {
        let label = UILabel()
        label.font = .h2Title
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    let addressLabel: UILabel = {
        let label = UILabel()
        label.font = .p0Paragraph
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingMiddle
        label.textColor = R.color.colorWhite50()!
        return label
    }()

    let copyButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    let shareButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDisabledStyle()
        return button
    }()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocale()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: ReceiveAssetViewModel) {
        titleLabel.text =
            R.string.localizable.walletReceiveNavigationTitle(viewModel.asset, preferredLanguages: locale.rLanguages)
        walletLabel.text = viewModel.accountName
        addressLabel.text = viewModel.address
    }

    private func applyLocale() {
        copyButton.imageWithTitleView?.title = R.string.localizable.commonCopy(preferredLanguages: locale.rLanguages)
        shareButton.imageWithTitleView?.title = R.string.localizable.commonShare(preferredLanguages: locale.rLanguages)
    }

    private func setupLayout() {
        backgroundColor = R.color.colorAlmostBlack()!
        layer.cornerRadius = LayoutConstants.cornerRadius
        clipsToBounds = true
        walletLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)
        addressLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)

        let navView = UIView()
        addSubview(navView)
        navView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(LayoutConstants.headerHeight)
        }

        navView.addSubview(indicator)
        indicator.snp.makeConstraints { make in
            make.size.equalTo(UIConstants.indicatorSize)
            make.top.equalTo(navView.snp.top)
            make.centerX.equalTo(navView.snp.centerX)
        }

        navView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
        }

        addSubview(qrView)
        qrView.snp.makeConstraints { make in
            make.top.equalTo(navView.snp.bottom).offset(UIConstants.hugeOffset)
            make.centerX.equalToSuperview()
            make.size.equalTo(LayoutConstants.qrImageSize)
        }

        addSubview(walletLabel)
        walletLabel.snp.makeConstraints { make in
            make.top.equalTo(qrView.snp.bottom).offset(UIConstants.hugeOffset)
            make.centerX.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        addSubview(addressLabel)
        addressLabel.snp.makeConstraints { make in
            make.top.equalTo(walletLabel.snp.bottom).offset(UIConstants.defaultOffset)
            make.centerX.equalToSuperview()
            make.width.equalTo(LayoutConstants.qrImageSize)
        }

        addSubview(shareButton)
        shareButton.snp.makeConstraints { make in
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-LayoutConstants.verticalOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(copyButton)
        copyButton.snp.makeConstraints { make in
            make.bottom.equalTo(shareButton.snp.top).offset(-LayoutConstants.verticalOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
            make.top.equalTo(addressLabel.snp.bottom).offset(UIConstants.hugeOffset)
        }
    }
}
