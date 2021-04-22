import UIKit

final class StakingPayoutConfirmInfoViewCell: StakingPayoutConfirmBaseTableCell {
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

    func bind(model: TitleWithSubtitleViewModel) {
        titleLabel.text = model.title
        valueLabel.text = model.subtitle
    }
}
