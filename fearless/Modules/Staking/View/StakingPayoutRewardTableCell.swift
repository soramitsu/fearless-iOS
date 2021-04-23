import UIKit

final class StakingPayoutRewardTableCell: StakingPayoutBaseTableCell {
    let tokenAmountLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    let usdAmountLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorGray()
        return label
    }()

    override func setupLayout() {
        super.setupLayout()

        contentView.addSubview(usdAmountLabel)
        usdAmountLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
        }

        contentView.addSubview(tokenAmountLabel)
        tokenAmountLabel.snp.makeConstraints { make in
            make.trailing.equalTo(usdAmountLabel.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(UIConstants.horizontalInset)
        }
    }

    func bind(model: StakingRewardTokenUsdViewModel) {
        titleLabel.text = model.title
        tokenAmountLabel.text = model.tokenAmountText
        usdAmountLabel.text = model.usdAmountText

        let isPriceEmpty = model.usdAmountText?.isEmpty ?? true

        tokenAmountLabel.snp.updateConstraints { make in
            let offset = !isPriceEmpty ? -8 : 0
            make.trailing.equalTo(usdAmountLabel.snp.leading).offset(offset)
        }

        setNeedsLayout()
    }
}
