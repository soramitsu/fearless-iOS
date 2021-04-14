import UIKit

final class StakingRewardHistoryTableCell: UITableViewCell {
    private enum Constants {
        static let verticalInset: CGFloat = 11
        static let iconSize: CGFloat = 32
    }

    private let transactionTypeView: UIView = {
        UIImageView(image: R.image.iconStakingTransactionType())
    }()

    private let addressLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    private let daysLeftLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        return label
    }()

    private let ksmAmountLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    private let usdAmountLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorLightGray()
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // swiftlint:disable function_body_length
    private func setupLayout() {
        contentView.addSubview(transactionTypeView)
        transactionTypeView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            transactionTypeView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: UIConstants.horizontalInset
            ),
            transactionTypeView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            transactionTypeView.widthAnchor.constraint(equalToConstant: Constants.iconSize)
        ])

        contentView.addSubview(addressLabel)
        addressLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            addressLabel.leadingAnchor.constraint(
                equalTo: transactionTypeView.trailingAnchor,
                constant: UIConstants.horizontalInset / 2
            ),
            addressLabel.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: Constants.verticalInset
            )
        ])

        contentView.addSubview(daysLeftLabel)
        daysLeftLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            daysLeftLabel.leadingAnchor.constraint(
                equalTo: transactionTypeView.trailingAnchor,
                constant: UIConstants.horizontalInset / 2
            ),
            daysLeftLabel.topAnchor.constraint(equalTo: addressLabel.bottomAnchor),
            daysLeftLabel.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -Constants.verticalInset
            )
        ])

        contentView.addSubview(ksmAmountLabel)
        ksmAmountLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            ksmAmountLabel.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -UIConstants.horizontalInset
            ),
            ksmAmountLabel.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: Constants.verticalInset
            ),
            addressLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: ksmAmountLabel.leadingAnchor,
                constant: -UIConstants.horizontalInset
            )
        ])

        contentView.addSubview(usdAmountLabel)
        usdAmountLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            usdAmountLabel.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -UIConstants.horizontalInset
            ),
            usdAmountLabel.topAnchor.constraint(equalTo: ksmAmountLabel.bottomAnchor),
            usdAmountLabel.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -Constants.verticalInset
            )
        ])
    }
    // swiftlint:enable function_body_length
}

extension StakingRewardHistoryTableCell {
    func bind(model: StakingRewardHistoryCellViewModel) {
        addressLabel.text = model.addressOrName
        daysLeftLabel.text = model.daysLeftText
        ksmAmountLabel.text = model.ksmAmountText
        usdAmountLabel.text = model.usdAmountText
    }
}
