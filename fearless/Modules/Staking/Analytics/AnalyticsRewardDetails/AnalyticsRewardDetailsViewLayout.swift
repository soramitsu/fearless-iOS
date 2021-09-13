import UIKit

final class AnalyticsRewardDetailsViewLayout: UIView {
    let blockNumberView: DetailsTriangularedView = {
        let detailsView = UIFactory.default.createDetailsView(with: .smallIconTitleSubtitle, filled: false)
        detailsView.actionImage = R.image.iconMore()
        return detailsView
    }()

    let dateView = TitleValueView()
    let typeView = TitleValueView()
    let amountView = TitleValueView()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        applyLocalization()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let content: UIView = .vStack(
            spacing: 16,
            [
                blockNumberView,
                .vStack(
                    [
                        dateView,
                        typeView,
                        amountView
                    ]
                )
            ]
        )

        addSubview(content)
        content.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).inset(8)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        blockNumberView.snp.makeConstraints { $0.height.equalTo(52) }
        [dateView, typeView, amountView].forEach { view in
            view.snp.makeConstraints { make in
                make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
                make.height.equalTo(48.0)
            }
        }
    }

    private func applyLocalization() {
        // TODO:
        blockNumberView.title = "Block number"
        dateView.titleLabel.text = R.string.localizable.transactionDetailDate(preferredLanguages: locale.rLanguages)
        typeView.titleLabel.text = R.string.localizable
            .stakingAnalyticsDetailsType(preferredLanguages: locale.rLanguages)
        amountView.titleLabel.text = R.string.localizable.walletSendAmountTitle(preferredLanguages: locale.rLanguages)
    }
}
