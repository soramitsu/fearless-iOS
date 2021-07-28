import UIKit

final class SelectValidatorsConfirmViewLayout: UIView {
    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 8.0, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

    var stackView: UIStackView { contentView.stackView }

    let mainAccountView: DetailsTriangularedView = UIFactory.default.createAccountView()

    let amountView: AmountInputView = {
        let view = UIFactory().createAmountInputView(filled: true)
        view.isUserInteractionEnabled = false
        return view
    }()

    let rewardDestinationView: TitleValueView = {
        let view = UIFactory.default.createTitleValueView()
        view.borderView.borderType = .none
        return view
    }()

    private(set) var payoutAccountView: DetailsTriangularedView?

    let validatorsView: TitleValueView = {
        let view = UIFactory.default.createTitleValueView()
        view.borderView.strokeWidth = UIConstants.separatorHeight
        view.borderView.borderType = [.top, .bottom]
        return view
    }()

    let networkFeeConfirmView: NetworkFeeConfirmView = UIFactory().createNetworkFeeConfirmView()

    private(set) var hintViews: [UIView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addPayoutAccountIfNeeded() {
        guard payoutAccountView == nil else {
            return
        }

        let view = UIFactory.default.createAccountView()

        stackView.insertArranged(view: view, after: rewardDestinationView)
        view.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(52.0)
        }

        stackView.setCustomSpacing(13.0, after: view)

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
                stackView.insertArranged(view: view, after: validatorsView)
            } else {
                stackView.insertArranged(view: view, after: hintViews[index - 1])
            }

            view.snp.makeConstraints { make in
                make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            }

            stackView.setCustomSpacing(9, after: view)
        }
    }

    private func setupLayout() {
        addSubview(networkFeeConfirmView)
        networkFeeConfirmView.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview()
        }

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(networkFeeConfirmView.snp.top)
        }

        stackView.addArrangedSubview(mainAccountView)
        mainAccountView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(52.0)
        }

        stackView.setCustomSpacing(16.0, after: mainAccountView)

        stackView.addArrangedSubview(amountView)
        amountView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(72.0)
        }

        stackView.setCustomSpacing(16.0, after: amountView)

        stackView.addArrangedSubview(rewardDestinationView)
        rewardDestinationView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(48.0)
        }

        stackView.addArrangedSubview(validatorsView)
        validatorsView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(48.0)
        }

        stackView.setCustomSpacing(13.0, after: amountView)
    }
}
