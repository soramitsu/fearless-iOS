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
        case .status:
            let valueView = LabelValueView(text: "Claimable")
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
}
