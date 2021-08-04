import UIKit

final class AnalyticsStakeViewLayout: UIView {
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

    private let lineChartView: FWChartViewProtocol = FWLineChartView()

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()

    private let stakeChangeStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        return stackView
    }()

    let periodSelectorView = AnalyticsPeriodSelectorView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let verticalInset = periodSelectorView.bounds.height
        scrollView.contentInset = .init(top: 0, left: 0, bottom: verticalInset, right: 0)
    }

    private func setupLayout() {
        addSubview(scrollView)
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }

        let containerView = UIView()
        scrollView.addSubview(containerView)
        containerView.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.width.equalTo(self)
        }

        let verticalInsetView = UIView()
        let statsStack: UIView = .vStack(
            spacing: 4,
            [
                selectedPeriodLabel,
                .hStack(spacing: 8, [tokenAmountLabel, usdAmountLabel, UIView()]),
                verticalInsetView,
                lineChartView
            ]
        )

        verticalInsetView.snp.makeConstraints { $0.height.equalTo(16) }
        lineChartView.snp.makeConstraints { $0.height.equalTo(168) }

        containerView.addSubview(statsStack)
        statsStack.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        containerView.addSubview(stakeChangeStackView)
        stakeChangeStackView.snp.makeConstraints { make in
            make.top.equalTo(statsStack.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }

        addSubview(periodSelectorView)
        periodSelectorView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    func bind(viewModel: AnalyticsStakeViewModel) {
        selectedPeriodLabel.text = viewModel.summaryViewModel.title
        tokenAmountLabel.text = viewModel.summaryViewModel.tokenAmount
        usdAmountLabel.text = viewModel.summaryViewModel.usdAmount

        lineChartView.setChartData(viewModel.chartData)

        let sections = viewModel.sections.map { section -> [UIView] in
            let header = UIView()
            let itemViews = section.items.map { viewModel -> UIView in
                let itemView = AnalyticsRewardsItemView()
                itemView.bind(model: viewModel)
                return itemView
            }
            return [header] + itemViews
        }

        stakeChangeStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        sections.flatMap { $0 }.forEach { stakeChangeStackView.addArrangedSubview($0) }
        periodSelectorView.bind(viewModel: viewModel.periodViewModel)
    }
}
