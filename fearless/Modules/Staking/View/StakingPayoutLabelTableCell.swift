import UIKit

/**
 Used in Staking reward flow.
 For example:
     "Date"......."3 March 2020" or
     "Era"......."#1,690" or
     "Reward destination"......."Restake"
  */
final class StakingPayoutLabelTableCell: StakingPayoutBaseTableCell {
    let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    override func setupLayout() {
        super.setupLayout()

        contentView.addSubview(valueLabel)
        valueLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(UIConstants.horizontalInset)
        }
    }

    func bind(model: StakingRewardDetailsSimpleLabelViewModel) {
        titleLabel.text = model.titleText
        valueLabel.text = model.valueText
    }
}
