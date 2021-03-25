import UIKit

final class StakingRewardDetailsTableCell: UITableViewCell {

    private let keyViewLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorLightGray()
        return label
    }()

    private let valueContainerView = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        separatorInset = .init(
            top: 0,
            left: UIConstants.horizontalInset,
            bottom: 0,
            right: UIConstants.horizontalInset)
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        contentView.addSubview(keyViewLabel)
        keyViewLabel.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview().inset(16)
        }

        contentView.addSubview(valueContainerView)
        valueContainerView.snp.makeConstraints { make in
            make.top.bottom.trailing.equalToSuperview().inset(16)
            make.leading.greaterThanOrEqualTo(keyViewLabel.snp.trailing).inset(16)
        }
    }

    func bind(model: RewardDetailsRow) {
        keyViewLabel.text = model.title

        switch model {
        case .status(let status):
            let valueView = StakingRewardStatusView(status: status)
            addValueView(valueView)
        case .date(let date):
            let valueView = LabelValueView(text: date)
            addValueView(valueView)
        case .era(let era):
            let valueView = LabelValueView(text: era)
            addValueView(valueView)
        case .reward:
            let valueView = LabelValueView(text: "0.00005 KSM")
            addValueView(valueView)
        }
    }

    private func addValueView(_ value: UIView) {
        valueContainerView.subviews.forEach { $0.removeFromSuperview() }
        valueContainerView.addSubview(value)
        value.snp.makeConstraints { $0.edges.equalToSuperview() }
    }
}

private extension StakingRewardDetailsTableCell {

    class LabelValueView: UIView {

        init(text: String) {
            super.init(frame: .zero)

            let label = UILabel()
            label.font = .p1Paragraph
            label.textColor = R.color.colorWhite()
            label.text = text
            addSubview(label)
            label.snp.makeConstraints { $0.edges.equalToSuperview() }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    class StakingRewardStatusView: UIView {

        init(status: StakingRewardStatus) {
            super.init(frame: .zero)

            let label = UILabel()
            label.font = .p1Paragraph
            label.textColor = R.color.colorWhite()
            label.text = status.text
            addSubview(label)
            label.snp.makeConstraints { make in
                make.leading.centerY.equalToSuperview()
            }

            let icon = UIImageView(image: status.icon)
            addSubview(icon)
            icon.snp.makeConstraints { make in
                make.centerY.trailing.equalToSuperview()
                make.leading.equalTo(label.snp.trailing).inset(-9)
                make.size.equalTo(22)
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}
