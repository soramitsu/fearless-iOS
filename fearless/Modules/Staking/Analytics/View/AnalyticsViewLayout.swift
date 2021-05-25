import UIKit
import SoraUI

final class AnalyticsViewLayout: UIView {
    let segmentedControl: PlainSegmentedControl = {
        let segmentedControl = PlainSegmentedControl()
        segmentedControl.selectionWidth = 1
        segmentedControl.titleColor = R.color.colorGray()!
        segmentedControl.selectionColor = R.color.colorWhite()!
        segmentedControl.selectedTitleColor = R.color.colorWhite()!
        segmentedControl.titleFont = .p1Paragraph
        return segmentedControl
    }()

    let rewardsView = AnalyticsRewardsView()

    let periodView = AnalyticsPeriodView()

    let receivedSummaryView = AnalyticsSummaryRewardView()
    let payableSummaryView = AnalyticsSummaryRewardView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(segmentedControl)
        segmentedControl.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(40)
        }

        addSubview(rewardsView)
        rewardsView.snp.makeConstraints { make in
            make.top.equalTo(segmentedControl.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }

        addSubview(periodView)
        periodView.snp.makeConstraints { make in
            make.top.equalTo(rewardsView.snp.bottom)
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
