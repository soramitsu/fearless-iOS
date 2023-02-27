import UIKit
import FearlessUtils
import Kingfisher

class WalletTransactionHistoryCell: UITableViewCell {
    private enum LayoutConstants {
        static let accountImageViewSize = CGSize(width: 32, height: 32)
        static let accountImageSize: CGFloat = 32
        static let statusImageViewSize = CGSize(width: 16, height: 16)
    }

    let accountIconImageView: UIImageView = {
        let iconView = UIImageView()
        iconView.backgroundColor = .clear
        return iconView
    }()

    let verticalContentStackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.minimalOffset)
    let firstlineStackView = UIFactory.default.createHorizontalStackView(spacing: UIConstants.bigOffset)
    let secondlineStackView = UIFactory.default.createHorizontalStackView()

    let addressLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.lineBreakMode = .byTruncatingMiddle
        label.textColor = R.color.colorWhite()
        return label
    }()

    let transactionAmountLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textAlignment = .right
        label.textColor = R.color.colorWhite()
        return label
    }()

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
        label.textAlignment = .right
        return label
    }()

    let transactionStatusIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconTxFailed()
        imageView.contentMode = .scaleAspectFit
        return imageView
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

        firstlineStackView.setCustomSpacing(UIConstants.defaultOffset, after: transactionAmountLabel)

        transactionAmountLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        transactionAmountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        transactionTypeLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        accountIconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.size.equalTo(LayoutConstants.accountImageSize)
            make.centerY.equalToSuperview()
        }

        verticalContentStackView.snp.makeConstraints { make in
            make.leading.equalTo(accountIconImageView.snp.trailing).offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }

        transactionStatusIconImageView.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.statusImageViewSize)
        }
    }

    func bind(to viewModel: WalletTransactionHistoryCellViewModel) {
        addressLabel.text = viewModel.address
        transactionAmountLabel.text = viewModel.amountString
        transactionTypeLabel.text = viewModel.transactionType
        transactionTimeLabel.text = viewModel.timeString
        transactionStatusIconImageView.image = viewModel.statusIcon
        transactionStatusIconImageView.isHidden = viewModel.statusIcon == nil

        if let icon = viewModel.icon {
            accountIconImageView.image = icon
        } else if let imageViewModel = viewModel.imageViewModel {
            imageViewModel.loadImage(
                on: accountIconImageView,
                targetSize: LayoutConstants.accountImageViewSize,
                animated: true,
                cornerRadius: 0
            )
        }

        switch viewModel.status {
        case .commited:
            transactionAmountLabel.textColor = viewModel.incoming ? R.color.colorGreen() : R.color.colorWhite()
        case .pending, .rejected:
            transactionAmountLabel.textColor = R.color.colorWhite16()
        }
    }
}
