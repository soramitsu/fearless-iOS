import UIKit
import SnapKit

final class LiquidityPoolRemoveLiquidityViewLayout: UIView {
    private enum Constants {
        static let navigationBarHeight: CGFloat = 56.0
        static let backButtonSize = CGSize(width: 32, height: 32)
        static let imageWidth: CGFloat = 12
        static let imageHeight: CGFloat = 12
        static let imageVerticalPosition: CGFloat = 2
        static let disclaimerMinHeight: CGFloat = 42.0
    }

    var keyboardAdoptableConstraint: Constraint?

    // MARK: navigation

    let navigationViewContainer = UIView()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = R.color.colorWhite()
        return label
    }()

    let backButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconBack(), for: .normal)
        button.layer.masksToBounds = true
        button.backgroundColor = R.color.colorWhite8()
        return button
    }()

    // MARK: content

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: UIConstants.bigOffset, left: 0.0, bottom: 0.0, right: 0.0)
        view.stackView.spacing = 8
        return view
    }()

    let swapFromInputView = AmountInputViewV2()
    let swapToInputView = AmountInputViewV2()
    let switchSwapButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconAddTokenPair(), for: .normal)
        return button
    }()

    let networkFeeView = UIFactory.default.createMultiView()
    let balanceView = UIFactory.default.createMultiView()

    private lazy var multiViews = [
        balanceView,
        networkFeeView
    ]

    let previewButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    let warningView = WarningView()

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
        backButton.rounded()
    }

    // MARK: - Public methods

    func bind(fee: BalanceViewModelProtocol?) {
        networkFeeView.bindBalance(viewModel: fee)
        networkFeeView.isHidden = false
    }

    func bindSwapFrom(assetViewModel: AssetBalanceViewModelProtocol?) {
        guard let assetViewModel else {
            return
        }

        swapFromInputView.bind(viewModel: assetViewModel)
    }

    func bindSwapTo(assetViewModel: AssetBalanceViewModelProtocol?) {
        guard let assetViewModel else {
            return
        }

        swapToInputView.bind(viewModel: assetViewModel)
    }

    func bindXorBalanceViewModel(_ viewModel: BalanceViewModelProtocol?) {
        balanceView.bindBalance(viewModel: viewModel)
    }

    // MARK: - Private methods

    private func setupLayout() {
        addSubview(navigationViewContainer)
        setupNavigationLayout(for: navigationViewContainer)
        setupContentsLayout()
    }

    private func setupNavigationLayout(for container: UIView) {
        container.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(Constants.navigationBarHeight)
        }

        container.addSubview(backButton)
        container.addSubview(titleLabel)

        backButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(UIConstants.bigOffset)
            make.size.equalTo(Constants.backButtonSize)
        }

        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    private func setupContentsLayout() {
        addSubview(contentView)
        addSubview(previewButton)
        addSubview(warningView)

        contentView.snp.makeConstraints { make in
            make.top.equalTo(navigationViewContainer.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(previewButton.snp.top).offset(-16)
        }

        previewButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(UIConstants.actionHeight)
            keyboardAdoptableConstraint = make.bottom.equalToSuperview().inset(16).constraint
        }

        warningView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(previewButton.snp.top).offset(-16)
        }

        let switchInputsView = createSwitchInputsView()
        contentView.stackView.addArrangedSubview(switchInputsView)
        switchInputsView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }

        let feesView = createFeesView()
        contentView.stackView.addArrangedSubview(feesView)
        feesView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
        }
    }

    private func createSwitchInputsView() -> UIView {
        let container = UIView()
        container.addSubview(swapFromInputView)
        container.addSubview(swapToInputView)
        container.addSubview(switchSwapButton)

        swapFromInputView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        swapToInputView.snp.makeConstraints { make in
            make.top.equalTo(swapFromInputView.snp.bottom).offset(UIConstants.defaultOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalToSuperview()
        }

        switchSwapButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(swapFromInputView.snp.bottom).offset(UIConstants.defaultOffset / 2)
        }

        return container
    }

    private func createFeesView() -> UIView {
        func makeCommonConstraints(for view: UIView) {
            view.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
            }
        }

        let backgroundView = UIFactory.default.createInfoBackground()
        let container = UIFactory.default.createVerticalStackView()

        backgroundView.addSubview(container)
        container.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(8)
            make.top.equalToSuperview()
        }

        multiViews.forEach {
            container.addArrangedSubview($0)
            makeCommonConstraints(for: $0)
            $0.titleLabel.isUserInteractionEnabled = true
        }

        return backgroundView
    }

    private func createMultiView() -> TitleMultiValueView {
        let view = TitleMultiValueView()
        view.titleLabel.font = .h6Title
        view.titleLabel.textColor = R.color.colorWhite50()
        view.valueTop.font = .p1Paragraph
        view.valueTop.textColor = R.color.colorWhite()
        view.valueBottom.font = .p2Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        view.borderView.isHidden = true
        view.equalsLabelsWidth = true
        view.valueTop.lineBreakMode = .byTruncatingTail
        view.valueBottom.lineBreakMode = .byTruncatingMiddle
        return view
    }

    private func applyLocalization() {
        warningView.titleLabel.text = "NOTE"
        warningView.textLabel.text = "Removing pool tokens converts your position back into underlying tokens at the current rate, proportional to your share of the pool. Accrued fees are included in the amounts you receive."
        titleLabel.text = "Remove Liquidity"

        swapFromInputView.locale = locale
        swapToInputView.locale = locale

        let texts = [
            R.string.localizable
                .polkaswapNetworkFee(preferredLanguages: locale.rLanguages)
        ]

        [
            networkFeeView.titleLabel
        ].enumerated().forEach { index, label in
            setInfoImage(for: label, text: texts[index])
        }

        balanceView.titleLabel.text = R.string.localizable.assetdetailsBalanceTransferable(preferredLanguages: locale.rLanguages)
        previewButton.imageWithTitleView?.title = R.string.localizable
            .commonPreview(preferredLanguages: locale.rLanguages)
    }

    private func setInfoImage(for label: UILabel, text: String) {
        let attributedString = NSMutableAttributedString(string: text)

        let imageAttachment = NSTextAttachment()
        imageAttachment.image = R.image.iconInfoFilled()
        imageAttachment.bounds = CGRect(
            x: 0,
            y: -Constants.imageVerticalPosition,
            width: Constants.imageWidth,
            height: Constants.imageHeight
        )

        let imageString = NSAttributedString(attachment: imageAttachment)
        attributedString.append(NSAttributedString(string: " "))
        attributedString.append(imageString)

        label.attributedText = attributedString
    }
}
