import UIKit
import SSFModels

final class SwapTransactionDetailViewLayout: UIView {
    private enum Constants {
        static let navigationBarHeight: CGFloat = 56.0
        static let closeButtonSize = CGSize(width: 32, height: 32)
        static let imageVerticalPosition: CGFloat = 3
        static let imageWidth: CGFloat = 15
        static let imageHeight: CGFloat = 15
        static let multiViewHeight: CGFloat = 60
    }

    let navigationViewContainer = UIView()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = R.color.colorWhite()
        return label
    }()

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: UIConstants.bigOffset, left: 0.0, bottom: 0.0, right: 0.0)
        view.stackView.spacing = UIConstants.bigOffset
        return view
    }()

    let doubleImageView = PolkaswapDoubleSymbolView()
    let swapStubTitle: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = R.color.colorStrokeGray()
        return label
    }()

    let amountsLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 2
        return label
    }()

    let infoBackground = UIFactory.default.createInfoBackground()
    let infoViewsStackView = UIFactory.default.createVerticalStackView()

    private let transactionHashView: TitleValueView = {
        let view = TitleValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueLabel.font = .h5Title
        view.valueLabel.textColor = R.color.colorWhite()
        view.valueLabel.lineBreakMode = .byTruncatingMiddle
        view.borderView.isHidden = true
        view.equalsLabelsWidth = true
        return view
    }()

    let statusView = UIFactory.default.createConfirmationMultiView()
    let fromView: TitleMultiValueView = {
        let view = UIFactory.default.createConfirmationMultiView()
        view.equalsLabelsWidth = true
        view.valueBottom.lineBreakMode = .byTruncatingMiddle
        return view
    }()

    let dateView = UIFactory.default.createConfirmationMultiView()
    let networkFeeView = UIFactory.default.createConfirmationMultiView()

    private lazy var multiViews = [
        transactionHashView,
        statusView,
        fromView,
        dateView,
        networkFeeView
    ]

    let closeButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconClose(), for: .normal)
        button.layer.masksToBounds = true
        button.backgroundColor = R.color.colorWhite8()
        return button
    }()

    let shareButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    let subscanButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDisabledStyle()
        return button
    }()

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    var copyOnTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBlack19()
        setupLayout()
        setupCopyHashTap()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        closeButton.rounded()
    }

    // MARK: - Public methods

    func updateState(for explorer: ChainModel.ExternalApiExplorer?) {
        subscanButton.isHidden = explorer == nil
        shareButton.isHidden = explorer == nil
    }

    func bind(viewModel: SwapTransactionViewModel) {
        amountsLabel.attributedText = viewModel.amountsText
        doubleImageView.bind(viewModel: viewModel.doubleImageViewViewModel)
        dateView.valueTop.text = viewModel.date
        statusView.valueTop.attributedText = viewModel.status
        fromView.valueTop.text = viewModel.walletName
        fromView.valueBottom.text = viewModel.address
        networkFeeView.bindBalance(viewModel: viewModel.networkFee)

        let hashString = NSMutableAttributedString(string: viewModel.txHash + "  ")

        let imageAttachment = NSTextAttachment()
        imageAttachment.bounds = CGRect(
            x: 0,
            y: -Constants.imageVerticalPosition,
            width: Constants.imageWidth,
            height: Constants.imageHeight
        )
        if let iconAboutArrowImage = R.image.iconCopy() {
            imageAttachment.image = iconAboutArrowImage
        }

        let imageString = NSAttributedString(attachment: imageAttachment)
        hashString.append(imageString)
        transactionHashView.valueLabel.attributedText = hashString
    }

    // MARK: - Private methods

    private func setupCopyHashTap() {
        let tapGesture = UITapGestureRecognizer()
        tapGesture.addTarget(self, action: #selector(handleHashCopyTapped))
        transactionHashView.valueLabel.addGestureRecognizer(tapGesture)
        transactionHashView.valueLabel.isUserInteractionEnabled = true
    }

    private func applyLocalization() {
        titleLabel.text = R.string.localizable
            .commonPreview(preferredLanguages: locale.rLanguages)
        statusView.titleLabel.text = R.string.localizable
            .transactionDetailStatus(preferredLanguages: locale.rLanguages)
        fromView.titleLabel.text = R.string.localizable
            .commonAccount(preferredLanguages: locale.rLanguages)
        networkFeeView.titleLabel.text = R.string.localizable
            .commonNetworkFee(preferredLanguages: locale.rLanguages)
        shareButton.imageWithTitleView?.title = R.string.localizable
            .commonShare(preferredLanguages: locale.rLanguages)
        swapStubTitle.text = R.string.localizable
            .polkaswapConfirmationSwapStub(preferredLanguages: locale.rLanguages)
        dateView.titleLabel.text = R.string.localizable
            .transactionDetailDate(preferredLanguages: locale.rLanguages)
        transactionHashView.titleLabel.text = R.string.localizable.allDoneAlertHashStub(preferredLanguages: locale.rLanguages)
        subscanButton.imageWithTitleView?.title = R.string.localizable.allDoneSubscanButtonTitle(preferredLanguages: locale.rLanguages)
    }

    private func setupLayout() {
        func makeCommonConstraints(for view: UIView) {
            view.snp.makeConstraints { make in
                make.height.equalTo(Constants.multiViewHeight)
                make.leading.trailing.equalToSuperview()
            }
        }

        addSubview(navigationViewContainer)
        navigationViewContainer.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(Constants.navigationBarHeight)
        }

        navigationViewContainer.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(UIConstants.bigOffset).inset(UIConstants.bigOffset)
            make.size.equalTo(Constants.closeButtonSize)
        }

        navigationViewContainer.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        addSubview(contentView)
        addSubview(shareButton)
        addSubview(subscanButton)

        contentView.snp.makeConstraints { make in
            make.top.equalTo(navigationViewContainer.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(shareButton.snp.bottom).offset(UIConstants.bigOffset)
        }

        contentView.stackView.addArrangedSubview(doubleImageView)
        contentView.stackView.addArrangedSubview(swapStubTitle)
        contentView.stackView.addArrangedSubview(amountsLabel)
        contentView.stackView.addArrangedSubview(infoBackground)

        infoBackground.addSubview(infoViewsStackView)
        infoBackground.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }
        infoViewsStackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.accessoryItemsSpacing)
            make.top.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }

        multiViews.forEach { view in
            infoViewsStackView.addArrangedSubview(view)
            makeCommonConstraints(for: view)
        }

        subscanButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(safeAreaLayoutGuide)
            make.height.equalTo(UIConstants.actionHeight)
        }

        shareButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(safeAreaLayoutGuide)
            make.height.equalTo(UIConstants.actionHeight)
            make.width.equalTo(subscanButton.snp.width)
            make.leading.equalTo(subscanButton.snp.trailing).offset(UIConstants.bigOffset)
        }
    }

    // MARK: - Private actions

    @objc private func handleHashCopyTapped() {
        copyOnTap?()
    }
}
