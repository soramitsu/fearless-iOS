import UIKit

final class AnalyticsRewardsView: UIView {
    private let selectedPeriodLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        label.text = "May 12—19"
        return label
    }()

    private let tokenAmountLabel: UILabel = {
        let label = UILabel()
        label.font = .h2Title
        label.textColor = R.color.colorWhite()
        label.text = "0.03805 KSM"
        return label
    }()

    private let usdAmountLabel: UILabel = {
        let label = UILabel()
        label.font = .h2Title
        label.textColor = R.color.colorGray()
        label.text = "$15.22"
        return label
    }()

    private let percentageLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.text = "+1.03%  ($0.001)"
        return label
    }()

    private let copmaredPeriodLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        label.text = "vs May 4—11"
        return label
    }()

    let periodView = AnalyticsPeriodView()

    let receivedSummaryView = AnalyticsSummaryRewardView()
    let payableSummaryView = AnalyticsSummaryRewardView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let statsStack: UIView = .vStack(
            alignment: .leading,
            distribution: .fill,
            spacing: 4,
            margins: nil,
            [
                selectedPeriodLabel,
                .hStack(spacing: 8, [tokenAmountLabel, usdAmountLabel]),
                .hStack(spacing: 4, [percentageLabel, copmaredPeriodLabel]),
            ]
        )

        addSubview(statsStack)
        statsStack.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(periodView)
        periodView.snp.makeConstraints { make in
            make.top.equalTo(statsStack.snp.bottom)
            make.height.equalTo(24)
            make.leading.trailing.equalToSuperview()
        }

        let separator = UIView.createSeparator()
        let summaryStack: UIView = .vStack([receivedSummaryView, separator, payableSummaryView])
        addSubview(summaryStack)
        summaryStack.snp.makeConstraints { make in
            make.top.equalTo(periodView.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }
        separator.snp.makeConstraints { $0.height.equalTo(UIConstants.separatorHeight) }
    }
}
