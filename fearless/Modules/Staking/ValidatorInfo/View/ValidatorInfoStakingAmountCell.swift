import UIKit

final class ValidatorInfoStakingAmountCell: ValidatorInfoBaseTableCell, ModalPickerCellProtocol {
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
        label.font = .p1Paragraph
        label.textColor = R.color.colorGray()
        return label
    }()

    // TODO: change layout
    override func setupLayout() {
        super.setupLayout()

        contentView.addSubview(priceLabel)
        priceLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
        }

        contentView.addSubview(amountLabel)
        amountLabel.snp.makeConstraints { make in
            make.trailing.equalTo(priceLabel.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(UIConstants.horizontalInset)
        }
    }

    func bind(model: StakingAmountViewModel) {
        titleLabel.text = model.title
        amountLabel.text = model.balance.amount
        priceLabel.text = model.balance.price ?? ""

        // TODO: Remove
        let isPriceEmpty = model.balance.price?.isEmpty ?? true

        amountLabel.snp.updateConstraints { make in
            let offset = !isPriceEmpty ? -8 : 0
            make.trailing.equalTo(priceLabel.snp.leading).offset(offset)
        }

        setNeedsLayout()
    }
}
