import UIKit

final class AnalyticsStakeHeaderView: UIView, AnalyticsRewardsHeaderViewProtocol {
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

    let chartView: FWChartViewProtocol = FWLineChartView()

    let periodView = AnalyticsPeriodView()

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
        let separator = UIView.createSeparator(color: R.color.colorDarkGray())
        let statsStack = UIView.vStack(
            spacing: 24,
            [
                amountsStack,
                chartView,
                .hStack(
                    distribution: .equalSpacing,
                    [UIView(), periodView, UIView()]
                ),
                separator,
                historyTitleLabel
            ]
        )

        separator.snp.makeConstraints { $0.height.equalTo(UIConstants.separatorHeight) }
        periodView.snp.makeConstraints { $0.centerX.equalToSuperview() }
        chartView.snp.makeConstraints { $0.height.equalTo(180) }

        addSubview(statsStack)
        statsStack.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(24)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview().inset(8)
            make.height.equalTo(396)
        }
    }

    func bind(
        summaryViewModel: AnalyticsSummaryRewardViewModel,
        chartData: ChartData,
        animateChart: Bool,
        selectedPeriod: AnalyticsPeriod
    ) {
        bind(summaryViewModel: summaryViewModel)

        periodView.bind(selectedPeriod: selectedPeriod)
        chartView.setChartData(chartData, animated: animateChart)
    }

    func bind(
        summaryViewModel: AnalyticsSummaryRewardViewModel
    ) {
        selectedPeriodLabel.text = summaryViewModel.title
        tokenAmountLabel.text = summaryViewModel.tokenAmount
        usdAmountLabel.text = summaryViewModel.usdAmount
    }

    private func applyLocalization() {
        historyTitleLabel.text = R.string.localizable
            .walletHistoryTitle_v190(preferredLanguages: locale.rLanguages)
        periodView.locale = locale
    }
}
