import UIKit

final class AnalyticsRewardsView: UIView {
    private let selectedPeriodLabel: UILabel = {
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

    private let receivedSummaryView = AnalyticsSummaryRewardView()
    private let payableSummaryView = AnalyticsSummaryRewardView()

    let payoutButton: TriangularedButton = UIFactory.default.createMainActionButton()

    let periodSelectorView = AnalyticsPeriodSelectorView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let scrollView = UIScrollView()
        addSubview(scrollView)
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }

        let containerView = UIView()
        scrollView.addSubview(containerView)
        containerView.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.width.equalTo(self)
        }

        let statsStack: UIView = .vStack(
            spacing: 4,
            [
                selectedPeriodLabel,
                .hStack(spacing: 8, [tokenAmountLabel, usdAmountLabel, UIView()]),
                chartView
            ]
        )

        chartView.snp.makeConstraints { $0.height.equalTo(168) }

        containerView.addSubview(statsStack)
        statsStack.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(periodSelectorView)
        periodSelectorView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    func bind(viewModel: AnalyticsRewardsViewModel) {
        selectedPeriodLabel.text = viewModel.summaryViewModel.title
        tokenAmountLabel.text = viewModel.summaryViewModel.tokenAmount
        usdAmountLabel.text = viewModel.summaryViewModel.usdAmount

        chartView.setChartData(viewModel.chartData)
        payableSummaryView.configure(with: viewModel.payableViewModel)
        receivedSummaryView.configure(with: viewModel.receivedViewModel)
        periodSelectorView.periodLabel.text = viewModel.periodTitle
        periodSelectorView.periodView.configure(periods: viewModel.periods, selected: viewModel.selectedPeriod)
        periodSelectorView.nextButton.isEnabled = viewModel.canSelectNextPeriod
    }
}
