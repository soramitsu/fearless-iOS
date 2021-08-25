import UIKit

final class AnalyticsRewardDetailsViewLayout: UIView {
    let detailsView = UIFactory.default.createDetailsView(with: .smallIconTitleSubtitle, filled: false)

    private let statusView: TitleValueView = {
        let view = TitleValueView()
        return view
    }()

    private let dateView: TitleValueView = {
        let view = TitleValueView()
        return view
    }()

    private let rewardView: TitleValueView = {
        let view = TitleValueView()
        return view
    }()

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
                detailsView,
                .vStack(
                    [
                        statusView,
                        dateView,
                        rewardView
                    ]
                )
            ]
        )

        addSubview(content)
        content.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).inset(8)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        detailsView.snp.makeConstraints { $0.height.equalTo(52) }
        [statusView, dateView, rewardView].forEach { view in
            view.snp.makeConstraints { make in
                make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
                make.height.equalTo(48.0)
            }
        }
    }

    private func applyLocalization() {
        statusView.titleLabel.text = R.string.localizable.transactionDetailStatus(preferredLanguages: locale.rLanguages)
        dateView.titleLabel.text = R.string.localizable.transactionDetailDate(preferredLanguages: locale.rLanguages)
        rewardView.titleLabel.text = R.string.localizable
            .stakingRewardDetailsReward(preferredLanguages: locale.rLanguages)
    }
}
