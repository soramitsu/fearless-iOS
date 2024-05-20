import UIKit

final class LiquidityPoolDetailsViewLayout: UIView {
    let navigationBar: BaseNavigationBar = {
        let bar = BaseNavigationBar()
        bar.set(.push)
        bar.backButton.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.08)
        bar.backButton.layer.cornerRadius = bar.backButton.frame.size.height / 2
        bar.backgroundColor = R.color.colorBlack19()
        return bar
    }()

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 24.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.stackView.spacing = UIConstants.bigOffset
        return view
    }()

    let doubleImageView = PolkaswapDoubleSymbolView()
    let pairTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = R.color.colorWhite()
        label.textAlignment = .center
        return label
    }()

    let amountsLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 2
        return label
    }()

    let infoBackground: TriangularedView = {
        let view = TriangularedView()
        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!
        view.strokeColor = R.color.colorWhite16()!
        view.highlightedStrokeColor = R.color.colorWhite16()!
        view.strokeWidth = 0.5
        view.shadowOpacity = 0.0

        return view
    }()

    let supplyButton = UIFactory.default.createMainActionButton()
    let removeButton: TriangularedButton = {
        let button = UIFactory.default.createDisabledButton()
        button.isHidden = true
        return button
    }()

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    let infoViewsStackView: UIStackView = {
        let stackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.bigOffset)
        stackView.alignment = .center
        stackView.layoutMargins = UIEdgeInsets(top: 24.0, left: 0.0, bottom: 0.0, right: 0.0)
        return stackView
    }()

    let reservesView: TitleMultiValueView = makeRowView()
    let apyView: TitleMultiValueView = makeRowView()
    let rewardTokenView: TitleMultiValueView = makeRowView()

    let baseAssetPooledView: TitleMultiValueView = {
        let view = makeRowView()
        view.isHidden = true
        return view
    }()

    let targetAssetPooledView: TitleMultiValueView = {
        let view = makeRowView()
        view.isHidden = true
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack19()
        drawSubviews()
        setupConstraints()
        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        navigationBar.backButton.rounded()
    }

    func bind(viewModel: LiquidityPoolDetailsViewModel?) {
        if let tokenPairIconsViewModel = viewModel?.tokenPairIconsViewModel {
            doubleImageView.bind(viewModel: tokenPairIconsViewModel)
        }
        pairTitleLabel.text = viewModel?.pairTitleLabelText
        reservesView.bind(viewModel: viewModel?.reservesViewModel)
        apyView.bind(viewModel: viewModel?.apyViewModel)
        rewardTokenView.valueTop.text = viewModel?.rewardTokenLabelText

        baseAssetPooledView.isHidden = viewModel?.userPoolFieldsHidden == true
        targetAssetPooledView.isHidden = viewModel?.userPoolFieldsHidden == true
        removeButton.isHidden = viewModel?.userPoolFieldsHidden == true

        baseAssetPooledView.bindBalance(viewModel: viewModel?.baseAssetViewModel)
        targetAssetPooledView.bindBalance(viewModel: viewModel?.targetAssetViewModel)

        if let baseAssetName = viewModel?.baseAssetName.uppercased() {
            baseAssetPooledView.titleLabel.text = "Your \(baseAssetName) Pooled"
        }

        if let targetAssetName = viewModel?.targetAssetName.uppercased() {
            targetAssetPooledView.titleLabel.text = "Your \(targetAssetName) Pooled"
        }
    }

    private func drawSubviews() {
        addSubview(navigationBar)
        addSubview(contentView)

        contentView.stackView.addArrangedSubview(infoBackground)
        infoBackground.addSubview(infoViewsStackView)
        infoViewsStackView.addArrangedSubview(doubleImageView)
        infoViewsStackView.addArrangedSubview(pairTitleLabel)
        infoViewsStackView.addArrangedSubview(reservesView)
        infoViewsStackView.addArrangedSubview(apyView)
        infoViewsStackView.addArrangedSubview(rewardTokenView)
        infoViewsStackView.addArrangedSubview(baseAssetPooledView)
        infoViewsStackView.addArrangedSubview(targetAssetPooledView)
        contentView.stackView.addArrangedSubview(supplyButton)
        contentView.stackView.addArrangedSubview(removeButton)
    }

    private func setupConstraints() {
        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }
        contentView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        infoBackground.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview().inset(16)
        }
        infoViewsStackView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().inset(16)
        }
        pairTitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }

        doubleImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(24)
        }

        [
            reservesView,
            apyView,
            rewardTokenView,
            baseAssetPooledView,
            targetAssetPooledView
        ].forEach {
            setupDefaultRowConstraints(for: $0)
        }

        [supplyButton, removeButton].forEach {
            $0.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(16)
                make.height.equalTo(UIConstants.actionHeight)
            }
        }
    }

    private func setupDefaultRowConstraints(for view: UIView) {
        view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
        }
    }

    private func setupDefaultSectionConstraints(for view: UIView) {
        view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(56)
        }
    }

    private static func makeRowView() -> TitleMultiValueView {
        let view = TitleMultiValueView()
        view.titleLabel.font = .p1Paragraph
        view.titleLabel.textColor = R.color.colorWhite()
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
        reservesView.titleLabel.text = "TVL"
        apyView.titleLabel.text = "Strategic Bonus APY"
        rewardTokenView.titleLabel.text = "Rewards Payout In"
        supplyButton.imageWithTitleView?.title = "Supply Liquidity"
        removeButton.imageWithTitleView?.title = "Remove Liquidity"
        navigationBar.setTitle("Pool details")
    }
}
