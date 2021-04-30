import UIKit

final class ValidatorInfoStakingAmountCell: ValidatorInfoBaseTableCell, ModalPickerCellProtocol {
    enum Constants {
        static let verticalInset: CGFloat = 10.0
    }

    typealias Model = StakingAmountViewModel

    var checkmarked: Bool = false

    let amountLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    let priceLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorGray()
        return label
    }()

    override func setupLayout() {
        super.setupLayout()

        contentView.addSubview(priceLabel)
        priceLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview().inset(Constants.verticalInset)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(UIConstants.horizontalInset)
        }

        contentView.addSubview(amountLabel)
        amountLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().inset(Constants.verticalInset)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(UIConstants.horizontalInset)
        }
    }

    func bind(model: StakingAmountViewModel) {
        titleLabel.text = model.title
        amountLabel.text = model.balance.amount
        priceLabel.text = model.balance.price ?? ""

        setNeedsLayout()
    }
}
