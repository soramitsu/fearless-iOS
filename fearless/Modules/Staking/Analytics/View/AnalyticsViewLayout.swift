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

    let stakeContainerView = UIView()

    let horizontalScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bounces = false
        return scrollView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBlack()
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

        addSubview(horizontalScrollView)
        horizontalScrollView.snp.makeConstraints { make in
            make.top.equalTo(segmentedControl.snp.bottom)
            make.leading.bottom.trailing.equalToSuperview()
        }

        let container = UIView()
        horizontalScrollView.addSubview(container)
        container.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.height.equalTo(self).inset(88)
        }

        let inner = [rewardsView, stakeContainerView]
        let scrollContentView = UIStackView(arrangedSubviews: inner)
        container.addSubview(scrollContentView)
        scrollContentView.snp.makeConstraints { $0.edges.equalToSuperview() }

        inner.forEach { view in
            view.snp.makeConstraints { $0.width.equalTo(self) }
        }
    }
}
