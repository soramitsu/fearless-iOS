import UIKit
import FearlessUtils
import Kingfisher

class WalletTransactionHistoryCell: UITableViewCell {
    let accountIconImageView = PolkadotIconView()
    let verticalContentStackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.minimalOffset)
    let firstlineStackView = UIFactory.default.createHorizontalStackView()
    let secondlineStackView = UIFactory.default.createHorizontalStackView()

    let addressLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.lineBreakMode = .byTruncatingMiddle
        label.textColor = .white
        return label
    }()

    let transactionAmountLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textAlignment = .right
        label.textColor = .white
        return label
    }()

    let transactionStatusIconImageView = UIImageView()

    let transactionTypeLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorAlmostWhite()
        return label
    }()

    let transactionTimeLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorAlmostWhite()
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        configure()
        setupLayout()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        backgroundColor = .clear

        selectionStyle = .none
    }

    private func setupLayout() {
        contentView.addSubview(accountIconImageView)
        contentView.addSubview(verticalContentStackView)

        verticalContentStackView.addArrangedSubview(firstlineStackView)
        verticalContentStackView.addArrangedSubview(secondlineStackView)

        firstlineStackView.addArrangedSubview(addressLabel)
        firstlineStackView.addArrangedSubview(transactionAmountLabel)
        firstlineStackView.addArrangedSubview(transactionStatusIconImageView)

        secondlineStackView.addArrangedSubview(transactionTypeLabel)
        secondlineStackView.addArrangedSubview(transactionTimeLabel)

        addressLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        transactionTypeLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }

    func bind(to viewModel: WalletTransactionHistoryCellViewModel) {
        addressLabel.text = viewModel.address
        transactionAmountLabel.text = viewModel.amountString
        transactionTypeLabel.text = viewModel.transactionType
        transactionTimeLabel.text = viewModel.timeString
        transactionStatusIconImageView.image = viewModel.statusIcon

        if let icon = viewModel.icon {
            accountIconImageView.bind(icon: icon)
        }
    }
}
