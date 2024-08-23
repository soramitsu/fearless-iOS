import UIKit

final class SelectValidatorsConfirmViewLayout: UIView {
    enum LayoutConstants {
        static let strokeWidth: CGFloat = 0.5
    }

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 8.0, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

    let infoBackground: TriangularedView = {
        let view = TriangularedView()
        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!
        view.strokeColor = R.color.colorWhite16()!
        view.highlightedStrokeColor = R.color.colorWhite16()!
        view.strokeWidth = LayoutConstants.strokeWidth
        view.shadowOpacity = 0.0

        return view
    }()

    let stakeAmountView = StakeAmountView()

    let infoStackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.bigOffset)

    let poolView: TitleMultiValueView = createTitleMultiValueView()

    let mainAccountView: TitleMultiValueView = createTitleMultiValueView()

    let rewardDestinationView: TitleMultiValueView = createTitleMultiValueView()

    var payoutAccountView: TitleMultiValueView?

    let amountView: TitleMultiValueView = createTitleMultiValueView()

    let validatorsView: TitleValueView = {
        let view = TitleValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueLabel.font = .h5Title
        view.valueLabel.textColor = R.color.colorWhite()
        view.borderView.isHidden = true
        view.equalsLabelsWidth = true
        return view
    }()

    let feeView: TitleMultiValueView = createTitleMultiValueView()

    let selectedCollatorContainer = UIView()
    let selectedCollatorTitle: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    let selectedCollatorView: TitleMultiValueView = createTitleMultiValueView()

    private(set) var hintViews: [UIView] = []

    let networkFeeFooterView = UIFactory().createCleanNetworkFeeFooterView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack19()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func createTitleMultiValueView() -> TitleMultiValueView {
        let view = TitleMultiValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueTop.font = .h5Title
        view.valueTop.textColor = R.color.colorWhite()
        view.valueBottom.font = .p1Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        view.borderView.isHidden = true
        view.equalsLabelsWidth = true
        view.valueTop.lineBreakMode = .byTruncatingTail
        view.valueBottom.lineBreakMode = .byTruncatingMiddle
        return view
    }

    func addPayoutAccountIfNeeded() {
        guard payoutAccountView == nil else {
            return
        }

        let view = createPayoutAccountView()

        infoStackView.insertArranged(view: view, after: rewardDestinationView)
        view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(52.0)
        }

        infoStackView.setCustomSpacing(13.0, after: view)

        payoutAccountView = view
    }

    func removePayoutAccountIfNeeded() {
        payoutAccountView?.removeFromSuperview()
        payoutAccountView = nil
    }

    func setHints(_ hints: [TitleIconViewModel]) {
        hintViews.forEach { $0.removeFromSuperview() }

        hintViews = hints.map { hint in
            let view = IconDetailsView()
            view.iconWidth = 24.0
            view.detailsLabel.text = hint.title
            view.imageView.image = hint.icon
            return view
        }

        for (index, view) in hintViews.enumerated() {
            if index > 0 {
                infoStackView.insertArranged(view: view, after: hintViews[index - 1])
            } else {
                infoStackView.insertArranged(view: view, after: validatorsView)
            }

            view.snp.makeConstraints { make in
                make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            }

            infoStackView.setCustomSpacing(9, after: view)
        }
    }

    private func createPayoutAccountView() -> TitleMultiValueView {
        let view = TitleMultiValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueTop.font = .h5Title
        view.valueTop.textColor = R.color.colorWhite()
        view.valueBottom.font = .p1Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        view.borderView.isHidden = true
        view.equalsLabelsWidth = true
        view.valueTop.lineBreakMode = .byTruncatingTail
        view.valueBottom.lineBreakMode = .byTruncatingMiddle
        return view
    }

    private func setupLayout() {
        addSubview(contentView)

        contentView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        contentView.stackView.addArrangedSubview(stakeAmountView)
        contentView.stackView.addArrangedSubview(infoBackground)

        contentView.stackView.setCustomSpacing(UIConstants.hugeOffset, after: stakeAmountView)

        infoBackground.addSubview(infoStackView)
        infoStackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.accessoryItemsSpacing)
            make.trailing.equalToSuperview().inset(UIConstants.accessoryItemsSpacing)
            make.top.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }

        infoStackView.addArrangedSubview(mainAccountView)
        infoStackView.addArrangedSubview(poolView)
        infoStackView.addArrangedSubview(amountView)
        infoStackView.addArrangedSubview(rewardDestinationView)
        infoStackView.addArrangedSubview(validatorsView)

        mainAccountView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight)
        }

        poolView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight)
        }

        amountView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight)
        }

        rewardDestinationView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight)
        }

        validatorsView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight)
        }

        addSubview(networkFeeFooterView)

        networkFeeFooterView.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview()
            make.top.equalTo(contentView.snp.bottom)
        }
    }
}
