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
    let fromAmountView = createMultiView()
    let toAmountView = createMultiView()
    let fromHashView = createTitleCopyableValueView()
    let toHashView = createTitleCopyableValueView()
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
        fromAmountView.bindBalance(viewModel: viewModel.amount)
        toAmountView.bindBalance(viewModel: viewModel.receivedAmount)
        fromHashView.valueLabel.text = viewModel.fromChainTxHash
        toHashView.valueLabel.text = viewModel.toChainTxHash
        toChainFeeView.bindBalance(viewModel: viewModel.toChainFee)
        fromChainFeeView.bindBalance(viewModel: viewModel.fromChainFee)
        statusRowLabel.valueTop.text = viewModel.statusViewModel.title
        statusRowLabel.valueTop.textColor = viewModel.statusViewModel.color

        fromHashView.isHidden = viewModel.fromChainTxHash.isNullOrEmpty
        toHashView.isHidden = viewModel.toChainTxHash.isNullOrEmpty
        fromChainFeeView.isHidden = viewModel.fromChainFee == nil
        toChainFeeView.isHidden = viewModel.toChainFee == nil
        toAmountView.isHidden = viewModel.receivedAmount == nil
        fromAmountView.isHidden = viewModel.amount == nil
        walletNameView.isHidden = viewModel.walletName == nil
        dateView.isHidden = viewModel.date == nil
        statusRowLabel.isHidden = false
        statusDescriptionLabel.isHidden = viewModel.statusDescription == nil
        statusTitleLabel.isHidden = viewModel.statusTitle == nil

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
        contentView.addArrangedSubview(fromAmountView)
        contentView.addArrangedSubview(toAmountView)
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

        [walletNameView, dateView, fromAmountView, toAmountView, fromHashView, toHashView, fromChainFeeView, toChainFeeView, statusRowLabel].forEach {
            $0.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(16)
                make.height.equalTo(60)
            }
            $0.isHidden = true
        }
    }

    private func applyLocalization() {
        navigationBar.setTitle(R.string.localizable.transactionDetailStatus(preferredLanguages: locale.rLanguages))

        walletNameView.titleLabel.text = R.string.localizable.commonWallet(preferredLanguages: locale.rLanguages)
        dateView.titleLabel.text = R.string.localizable.transactionDetailDate(preferredLanguages: locale.rLanguages)
        fromAmountView.titleLabel.text = R.string.localizable.commonActionSend(preferredLanguages: locale.rLanguages)
        toAmountView.titleLabel.text = R.string.localizable.stakingRewardDetailsStatusReceived(preferredLanguages: locale.rLanguages)
        statusRowLabel.titleLabel.text = R.string.localizable.transactionDetailStatus(preferredLanguages: locale.rLanguages)
    }

    private static func createMultiView() -> TitleMultiValueView {
        let view = UIFactory.default.createMultiView()
        view.equalsLabelsWidth = true
        view.titleLabel.font = .h6Title
        view.valueTop.font = .h5Title
        view.valueTop.numberOfLines = 1
        view.valueTop.lineBreakMode = .byTruncatingMiddle
        return view
    }

    private static func createTitleCopyableValueView() -> TitleCopyableValueView {
        let view = TitleCopyableValueView()
        view.equalsLabelsWidth = true
        view.titleLabel.font = .h6Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueLabel.font = .h5Title
        view.valueLabel.textColor = R.color.colorWhite()
        view.valueLabel.lineBreakMode = .byTruncatingMiddle
        view.borderView.borderType = .none
        return view
    }
}
