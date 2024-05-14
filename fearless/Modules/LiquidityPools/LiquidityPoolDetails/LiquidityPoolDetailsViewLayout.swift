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
    
    let infoViewsStackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.bigOffset)
    
    let reservesView: TitleMultiValueView = makeRowView()
    let apyView: TitleMultiValueView = makeRowView()
    let rewardTokenView: TitleMultiValueView = makeRowView()
    let baseAssetPooledView: TitleMultiValueView = makeRowView()
    let targetAssetPooledView: TitleMultiValueView = makeRowView()

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

    private func drawSubviews() {
        addSubview(navigationBar)
        addSubview(contentView)
        
        contentView.stackView.addArrangedSubview(infoBackground)
        infoBackground.addSubview(infoViewsStackView)
        infoViewsStackView.addArrangedSubview(doubleImageView)
        infoViewsStackView.addArrangedSubview(swapStubTitle)

    }

    private func setupConstraints() {
        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }
        contentView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
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
        
    }
}
