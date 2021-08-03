import UIKit

final class AnalyticsRewardsHeaderView: UIView {
    let selectedPeriodLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    private let tokenAmountLabel: UILabel = {
        let label = UILabel()
        label.font = .h2Title
        label.textColor = R.color.colorWhite()
        return label
    }()

    private let usdAmountLabel: UILabel = {
        let label = UILabel()
        label.font = .h2Title
        label.textColor = R.color.colorGray()
        return label
    }()

    private let chartView = ChartView()

    let pendingRewardsView: RowView<TitleValueSelectionView> = {
        let row = RowView(contentView: TitleValueSelectionView(), preferredHeight: 48.0)
        row.borderView.borderType = .bottom
        row.rowContentView.iconView.image = R.image.iconPendingRewards()
        return row
    }()

    private let historyTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .p0Paragraph
        label.textColor = R.color.colorWhite()
        return label
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

        setupLayout()
        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let amountsStack = UIView.hStack(spacing: 8, [tokenAmountLabel, usdAmountLabel, UIView()])
        let statsStack = UIView.vStack(
            spacing: 4,
            [
                selectedPeriodLabel,
                amountsStack,
                chartView
            ]
        )

        statsStack.setCustomSpacing(24, after: amountsStack)
        statsStack.setCustomSpacing(24, after: chartView)
        chartView.snp.makeConstraints { $0.height.equalTo(168) }

        addSubview(statsStack)
        statsStack.snp.makeConstraints {
            $0.leading.top.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(pendingRewardsView)
        pendingRewardsView.snp.makeConstraints { make in
            make.top.equalTo(statsStack.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview()
        }

        addSubview(historyTitleLabel)
        historyTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(pendingRewardsView.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview().inset(8)
        }
    }

    func bind(
        summaryViewModel: AnalyticsSummaryRewardViewModel,
        chartData: ChartData
    ) {
        selectedPeriodLabel.text = summaryViewModel.title
        tokenAmountLabel.text = summaryViewModel.tokenAmount
        usdAmountLabel.text = summaryViewModel.usdAmount

        chartView.setChartData(chartData)
    }

    private func applyLocalization() {
        pendingRewardsView.rowContentView.titleLabel.text = R.string.localizable
            .stakingPendingRewards(preferredLanguages: locale.rLanguages)
        historyTitleLabel.text = R.string.localizable
            .walletHistoryTitle_v190(preferredLanguages: locale.rLanguages)
    }
}
