import UIKit
import SnapKit

final class LiquidityPoolSupplyViewLayout: UIView {
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
        view.stackView.spacing = UIConstants.bigOffset
        return view
    }()

    let swapFromInputView = AmountInputViewV2(type: .bonded)
    let swapToInputView = AmountInputViewV2(type: .bonded)
    let switchSwapButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconAddTokenPair(), for: .normal)
        return button
    }()

    let swapRouteView: TitleMultiValueView = {
        let view = UIFactory.default.createMultiView()
        return view
    }()

    let slippageView = UIFactory.default.createMultiView()
    let apyView = UIFactory.default.createMultiView()
    let rewardTokenView = UIFactory.default.createMultiView()
    let networkFeeView = UIFactory.default.createMultiView()
    let apyInfoButton: UIButton = {
        let button = UIButton()
        button.isUserInteractionEnabled = false
        button.setImage(R.image.iconInfoFilled(), for: .normal)
        return button
    }()

    let tokenIconImageView = UIImageView()

    private lazy var multiViews = [
        slippageView,
        apyView,
        rewardTokenView,
        networkFeeView
    ]

    let previewButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    // MARK: - Lifecycle

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

    func bind(viewModel: LiquidityPoolSupplyViewModel) {
        slippageView.bind(viewModel: viewModel.slippageViewModel)
        apyView.bind(viewModel: viewModel.apyViewModel)
        rewardTokenView.bind(viewModel: viewModel.rewardTokenViewModel)

        viewModel.rewardTokenIconViewModel?.loadImage(
            on: tokenIconImageView,
            targetSize: CGSize(width: 12, height: 12),
            animated: true
        )
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
            make.leading.trailing.top.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(8)
        }

        multiViews.forEach {
            container.addArrangedSubview($0)
            makeCommonConstraints(for: $0)
            $0.titleLabel.isUserInteractionEnabled = true
        }

        apyView.addSubview(apyInfoButton)

        apyInfoButton.snp.makeConstraints { make in
            make.leading.equalTo(apyView.titleLabel.snp.trailing).offset(4)
            make.centerY.equalToSuperview()
            make.size.equalTo(12)
        }

        rewardTokenView.addSubview(tokenIconImageView)

        rewardTokenView.valueTop.snp.makeConstraints { make in
            make.leading.equalTo(tokenIconImageView.snp.trailing).offset(4)
        }
        tokenIconImageView.snp.makeConstraints { make in
            make.size.equalTo(12)
            make.centerY.equalToSuperview()
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
        titleLabel.text = "Supply Liquidity"

        swapFromInputView.locale = locale
        swapToInputView.locale = locale

        swapRouteView.titleLabel.text = R.string.localizable
            .polkaswapConfirmationRouteStub(preferredLanguages: locale.rLanguages)

        let texts = [
            R.string.localizable
                .polkaswapNetworkFee(preferredLanguages: locale.rLanguages)
        ]

        [
            networkFeeView.titleLabel
        ].enumerated().forEach { index, label in
            setInfoImage(for: label, text: texts[index])
        }

        previewButton.imageWithTitleView?.title = R.string.localizable
            .commonPreview(preferredLanguages: locale.rLanguages)

        slippageView.titleLabel.text = R.string.localizable.polkaswapSettingsSlippageTitle(preferredLanguages: locale.rLanguages)
        apyView.titleLabel.text = "Strategic Bonus APY"
        rewardTokenView.titleLabel.text = "Rewards Payout In"
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
