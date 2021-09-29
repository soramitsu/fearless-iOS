import UIKit

final class AnalyticsValidatorsHeaderView: UIView {
    let pieChart = FWPieChartView()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p0Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(pieChart)
        pieChart.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(32)
            make.width.equalToSuperview()
            make.height.equalTo(240)
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview().inset(8)
        }
    }
}
