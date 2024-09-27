import UIKit

final class CrossChainTxTrackingViewLayout: UIView {
    let navigationBar: BaseNavigationBar = {
        let bar = BaseNavigationBar()
        bar.set(.present)
        bar.backButtonAlignment = .right
        bar.backButton.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.08)
        bar.backButton.layer.cornerRadius = bar.backButton.frame.size.height / 2
        bar.backgroundColor = R.color.colorBlack19()
        return bar
    }()

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(
            top: 24.0,
            left: 0.0,
            bottom: UIConstants.actionHeight + UIConstants.bigOffset * 2,
            right: 0.0
        )
        view.stackView.alignment = .center
        view.stackView.spacing = UIConstants.bigOffset
        return view
    }()

    let statusView = CrossChainTransactionTrackingOverallView()
    let statusTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .h2Title
        label.textAlignment = .center
        return label
    }()

    let statusDescriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .p0Paragraph
        label.numberOfLines = 0
        label.textColor = R.color.colorGray()
        label.textAlignment = .center
        return label
    }()

    let walletNameView = createMultiView()
    let dateView = createMultiView()
    let amountView = createMultiView()
    let fromHashView = createMultiView()
    let toHashView = createMultiView()
    let fromChainFeeView = createMultiView()
    let toChainFeeView = createMultiView()
    let statusRowLabel = createMultiView()

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBlack19()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        navigationBar.backButton.rounded()
    }

    func bind(viewModel: CrossChainTxTrackingViewModel) {
        statusView.bind(viewModels: viewModel.statusViewModels)
        statusTitleLabel.text = viewModel.statusTitle
        statusDescriptionLabel.text = viewModel.statusDescription
        walletNameView.valueTop.text = viewModel.walletName
        dateView.valueTop.text = viewModel.date
        amountView.bindBalance(viewModel: viewModel.amount)
        fromHashView.valueTop.text = viewModel.fromChainTxHash
        toHashView.valueTop.text = viewModel.toChainTxHash
        toChainFeeView.bindBalance(viewModel: viewModel.toChainFee)
        fromChainFeeView.bindBalance(viewModel: viewModel.fromChainFee)
        statusRowLabel.valueTop.text = viewModel.detailStatus

        fromHashView.isHidden = viewModel.fromHashViewTitle.isNullOrEmpty
        toHashView.isHidden = viewModel.toHashViewTitle.isNullOrEmpty
        fromChainFeeView.isHidden = viewModel.fromChainFee == nil
        toChainFeeView.isHidden = viewModel.toChainFee == nil

        fromHashView.titleLabel.text = viewModel.fromHashViewTitle
        toHashView.titleLabel.text = viewModel.toHashViewTitle
        fromChainFeeView.titleLabel.text = viewModel.fromFeeViewTitle
        toChainFeeView.titleLabel.text = viewModel.toFeeViewTitle
    }

    // MARK: - Private methods

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(contentView)

        contentView.addArrangedSubview(statusView)
        contentView.addArrangedSubview(statusTitleLabel)
        contentView.addArrangedSubview(statusDescriptionLabel)
        contentView.addArrangedSubview(walletNameView)
        contentView.addArrangedSubview(dateView)
        contentView.addArrangedSubview(amountView)
        contentView.addArrangedSubview(fromHashView)
        contentView.addArrangedSubview(toHashView)
        contentView.addArrangedSubview(fromChainFeeView)
        contentView.addArrangedSubview(toChainFeeView)
        contentView.addArrangedSubview(statusRowLabel)

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview()
            make.top.equalTo(navigationBar.snp.bottom)
        }

        statusView.snp.makeConstraints { make in
            make.height.equalTo(50)
            make.centerX.equalToSuperview()
        }

        [walletNameView, dateView, amountView, fromHashView, toHashView, fromChainFeeView, toChainFeeView, statusRowLabel].forEach {
            $0.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(16)
            }
        }
    }

    private func applyLocalization() {
        navigationBar.setTitle(R.string.localizable.transactionDetailStatus(preferredLanguages: locale.rLanguages))

        walletNameView.titleLabel.text = R.string.localizable.commonWallet(preferredLanguages: locale.rLanguages)
        dateView.titleLabel.text = R.string.localizable.transactionDetailDate(preferredLanguages: locale.rLanguages)
        amountView.titleLabel.text = R.string.localizable.walletSendAmountTitle(preferredLanguages: locale.rLanguages)
        statusRowLabel.titleLabel.text = R.string.localizable.transactionDetailStatus(preferredLanguages: locale.rLanguages)
    }

    private static func createMultiView() -> TitleMultiValueView {
        let view = UIFactory.default.createMultiView()
        view.titleLabel.font = .h6Title
        view.valueTop.font = .h5Title
        view.valueTop.numberOfLines = 1
        view.valueTop.lineBreakMode = .byTruncatingMiddle
        return view
    }
}
