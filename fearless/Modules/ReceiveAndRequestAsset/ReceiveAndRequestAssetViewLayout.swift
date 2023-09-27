import UIKit

final class ReceiveAndRequestAssetViewLayout: UIView {
    private enum LayoutConstants {
        static let cornerRadius: CGFloat = 20.0
        static let headerHeight: CGFloat = 56.0
        static let qrImageSize: CGFloat = 240
        static let verticalOffset: CGFloat = 12
        static let infoIconSize: CGFloat = 12
        static let infoViewsOffset: CGFloat = 10
        static let noteLabelMaxHeight: CGFloat = 33
        static let segmentedControlHeight: CGFloat = 32
        static let animateDuration = 0.4
    }

    private let indicator = UIFactory.default.createIndicatorView()
    let navigationBar: BaseNavigationBar = {
        let view = BaseNavigationBar()
        view.backgroundColor = R.color.colorBlack19()
        return view
    }()

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.spacing = LayoutConstants.verticalOffset
        view.stackView.alignment = .center
        return view
    }()

    let segmentedControl = FWSegmentedControl()
    let amountView = SelectableAmountInputView(type: .send)
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
        segmentedControl.delegate = self
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: ReceiveAssetViewModel) {
        let title = R.string.localizable.walletReceiveNavigationTitle(viewModel.asset, preferredLanguages: locale.rLanguages)
        navigationBar.setTitle(title)
        walletLabel.text = viewModel.accountName
        addressLabel.text = viewModel.address
    }

    func bind(assetViewModel: AssetBalanceViewModelProtocol?) {
        segmentedControl.isHidden = assetViewModel == nil
        amountView.bind(viewModel: assetViewModel)
    }

    private func applyLocale() {
        copyButton.imageWithTitleView?.title = R.string.localizable.commonCopy(preferredLanguages: locale.rLanguages)
        shareButton.imageWithTitleView?.title = R.string.localizable.commonShare(preferredLanguages: locale.rLanguages)

        let segmentTitles = [
            R.string.localizable.commonActionReceive(preferredLanguages: locale.rLanguages),
            R.string.localizable.commonRequest(preferredLanguages: locale.rLanguages)
        ]
        segmentedControl.setSegmentItems(segmentTitles)
        amountView.locale = locale
    }

    private func setupLayout() {
        backgroundColor = R.color.colorBlack19()
        layer.cornerRadius = LayoutConstants.cornerRadius
        clipsToBounds = true
        amountView.isHidden = true
        amountView.alpha = 0
        walletLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)
        addressLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)

        addSubview(navigationBar)
        addSubview(contentView)
        addSubview(shareButton)
        addSubview(copyButton)

        contentView.stackView.addArrangedSubview(segmentedControl)
        contentView.stackView.addArrangedSubview(amountView)
        contentView.stackView.addArrangedSubview(qrView)
        contentView.stackView.addArrangedSubview(walletLabel)
        contentView.stackView.addArrangedSubview(addressLabel)

        navigationBar.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(LayoutConstants.headerHeight)
        }

        contentView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom).offset(UIConstants.bigOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(copyButton.snp.top)
        }

        amountView.snp.makeConstraints { make in
            make.width.equalToSuperview()
            make.height.equalTo(UIConstants.amountViewV2Height)
        }

        qrView.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.qrImageSize)
        }

        shareButton.snp.makeConstraints { make in
            make.bottom.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        copyButton.snp.makeConstraints { make in
            make.bottom.equalTo(shareButton.snp.top).offset(-LayoutConstants.verticalOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        segmentedControl.snp.makeConstraints { make in
            make.height.equalTo(LayoutConstants.segmentedControlHeight)
            make.width.equalTo(contentView.snp.width)
        }

        [walletLabel, addressLabel].forEach { view in
            view.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
            }
        }
    }
}

extension ReceiveAndRequestAssetViewLayout: FWSegmentedControlDelegate {
    func didSelect(_ segmentIndex: Int) {
        UIView.animate(withDuration: LayoutConstants.animateDuration) {
            self.amountView.isHidden = segmentIndex == 0
            let alpha = segmentIndex == 0 ? 0.0 : 1.0
            self.amountView.alpha = alpha
            self.layoutIfNeeded()
        }
    }
}
