import UIKit

final class AnalyticsRewardsHeaderView: UIView, AnalyticsRewardsHeaderViewProtocol {
    let selectedPeriodLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    private let tokenAmountLabel: UILabel = {
        let label = UILabel()
        label.font = .h1Title
        label.textColor = R.color.colorWhite()
        return label
    }()

    private let usdAmountLabel: UILabel = {
        let label = UILabel()
        label.font = .h2Title
        label.textColor = R.color.colorStrokeGray()
        return label
    }()

    private let barChartView: FWChartViewProtocol = FWBarChartView()

    let periodView = AnalyticsPeriodView()

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
        let amountsStack = UIView.vStack(
            alignment: .center,
            [selectedPeriodLabel, tokenAmountLabel, usdAmountLabel]
        )
        let statsStack = UIView.vStack(
            spacing: 4,
            [
                amountsStack,
                barChartView,
                .hStack(
                    distribution: .equalSpacing,
                    [UIView(), periodView, UIView()]
                ),
                historyTitleLabel
            ]
        )

        statsStack.setCustomSpacing(24, after: amountsStack)
        statsStack.setCustomSpacing(32, after: periodView)
        periodView.snp.makeConstraints { $0.centerX.equalToSuperview() }
        barChartView.snp.makeConstraints { $0.height.equalTo(180) }

        addSubview(statsStack)
        statsStack.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(24)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(336)
        }

        addSubview(pendingRewardsView)
        pendingRewardsView.snp.makeConstraints { make in
            make.top.equalTo(statsStack.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().inset(8)
        }
    }

    func bind(
        summaryViewModel: AnalyticsSummaryRewardViewModel,
        chartData: ChartData,
        selectedPeriod: AnalyticsPeriod
    ) {
        selectedPeriodLabel.text = summaryViewModel.title
        tokenAmountLabel.text = summaryViewModel.tokenAmount
        usdAmountLabel.text = summaryViewModel.usdAmount

        periodView.bind(selectedPeriod: selectedPeriod)
        barChartView.setChartData(chartData)
    }

    private func applyLocalization() {
        pendingRewardsView.rowContentView.titleLabel.text = R.string.localizable
            .stakingPendingRewards(preferredLanguages: locale.rLanguages)
        historyTitleLabel.text = R.string.localizable
            .walletHistoryTitle_v190(preferredLanguages: locale.rLanguages)
    }
}
