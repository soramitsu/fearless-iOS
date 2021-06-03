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

    let periodView = AnalyticsPeriodView()

    private let receivedSummaryView = AnalyticsSummaryRewardView()
    private let payableSummaryView = AnalyticsSummaryRewardView()

    let payoutButton: TriangularedButton = UIFactory.default.createMainActionButton()

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
            spacing: 4,
            [
                selectedPeriodLabel,
                .hStack(spacing: 8, [tokenAmountLabel, usdAmountLabel, UIView()]),
                chartView
            ]
        )

        chartView.snp.makeConstraints { $0.height.equalTo(168) }

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

        addSubview(payoutButton)
        payoutButton.snp.makeConstraints { make in
            make.top.equalTo(summaryStack.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(50)
            make.bottom.equalToSuperview()
        }
    }

    func bind(viewModel: AnalyticsRewardsViewModel) {
        selectedPeriodLabel.text = viewModel.summaryViewModel.title
        tokenAmountLabel.text = viewModel.summaryViewModel.tokenAmount
        usdAmountLabel.text = viewModel.summaryViewModel.usdAmount

        chartView.setChartData(viewModel.chartData)
        payableSummaryView.configure(with: viewModel.payableViewModel)
        receivedSummaryView.configure(with: viewModel.receivedViewModel)
    }
}
