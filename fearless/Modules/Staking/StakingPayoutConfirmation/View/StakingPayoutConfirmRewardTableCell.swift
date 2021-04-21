import UIKit

final class StakingPayoutConfirmRewardTableCell: StakingPayoutConfirmBaseTableCell {
    let tokenAmountLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    let fiatAmountLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorGray()
        return label
    }()

    override func setupLayout() {
        super.setupLayout()

        contentView.addSubview(fiatAmountLabel)
        fiatAmountLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
        }

        contentView.addSubview(tokenAmountLabel)
        tokenAmountLabel.snp.makeConstraints { make in
            make.trailing.equalTo(fiatAmountLabel.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(UIConstants.horizontalInset)
        }
    }

    func bind(
        model: PayoutRewardAmountViewModel
    ) {
        titleLabel.text = model.title
        tokenAmountLabel.text = model.priceData.amount
        fiatAmountLabel.text = model.priceData.price
    }
}
