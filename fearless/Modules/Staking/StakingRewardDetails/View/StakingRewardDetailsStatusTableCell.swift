import UIKit

final class StakingRewardDetailsStatusTableCell: StakingRewardDetailsBaseTableCell {

    let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    let statusImageView = UIImageView()

    override func setupLayout() {
        super.setupLayout()

        contentView.addSubview(statusImageView)
        statusImageView.snp.makeConstraints { make in
            make.centerY.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.size.equalTo(22)
        }

        contentView.addSubview(statusLabel)
        statusLabel.snp.makeConstraints { make in
            make.trailing.equalTo(statusImageView.snp.leading).offset(-9)
            make.centerY.equalTo(statusImageView.snp.centerY)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(UIConstants.horizontalInset)
        }
    }

    func bind(model: StakingRewardStatusViewModel) {
        titleLabel.text = model.title
        statusLabel.text = model.statusText
        statusImageView.image = model.icon
    }
}
