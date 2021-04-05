import Foundation
import SnapKit
import CommonWallet

final class HistoryItemTableViewCell: UITableViewCell {
    private enum Constants {
        static let verticalInset: CGFloat = 11
        static let iconSize: CGFloat = 32
        static let statusOffset: CGFloat = 4.0
    }

    private let transactionTypeView = UIImageView()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        return label
    }()

    private let amountLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorLightGray()
        return label
    }()

    private var statusImageView: UIImageView?

    var viewModel: WalletViewModelProtocol?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        backgroundColor = .clear

        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = R.color.colorCellSelection()!

        setupLayout()
    }

    private func setupLayout() {
        contentView.addSubview(transactionTypeView)

        transactionTypeView.snp.makeConstraints { make in
            make.leading.equalTo(contentView).offset(UIConstants.horizontalInset)
            make.centerY.equalTo(contentView)
            make.width.equalTo(Constants.iconSize)
        }

        contentView.addSubview(titleLabel)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(transactionTypeView.snp.trailing).offset(UIConstants.horizontalInset / 2.0)
            make.top.equalTo(contentView).offset(Constants.verticalInset)
        }

        contentView.addSubview(subtitleLabel)

        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(transactionTypeView.snp.trailing).offset(UIConstants.horizontalInset / 2.0)
            make.top.equalTo(titleLabel.snp.bottom)
            make.bottom.equalTo(contentView).offset(-Constants.verticalInset)
        }

        contentView.addSubview(amountLabel)

        amountLabel.snp.makeConstraints { make in
            make.trailing.equalTo(contentView.snp.trailing).offset(-UIConstants.horizontalInset)
            make.top.equalTo(contentView.snp.top).offset(Constants.verticalInset)
            make.leading.equalTo(titleLabel.snp.trailing).offset(UIConstants.horizontalInset)
        }

        amountLabel.snp.contentHuggingHorizontalPriority = titleLabel.snp.contentHuggingHorizontalPriority + 1
        amountLabel.snp.contentCompressionResistanceHorizontalPriority =
            titleLabel.snp.contentCompressionResistanceHorizontalPriority + 1

        contentView.addSubview(timeLabel)

        timeLabel.snp.makeConstraints { make in
            make.trailing.equalTo(contentView).offset(-UIConstants.horizontalInset)
            make.top.equalTo(amountLabel.snp.bottom)
            make.bottom.equalTo(contentView).offset(-Constants.verticalInset)
            make.leading.equalTo(subtitleLabel.snp.trailing).offset(-UIConstants.horizontalInset)
        }

        timeLabel.snp.contentHuggingHorizontalPriority = subtitleLabel.snp.contentHuggingHorizontalPriority + 1
        timeLabel.snp.contentCompressionResistanceHorizontalPriority =
            subtitleLabel.snp.contentCompressionResistanceHorizontalPriority + 1
    }

    private func addStatusViewIfNeeded() {
        guard statusImageView == nil else {
            return
        }

        let statusImageView = UIImageView()
        contentView.addSubview(statusImageView)

        statusImageView.snp.makeConstraints { make in
            make.trailing.equalTo(contentView).offset(-UIConstants.horizontalInset)
            make.centerY.equalTo(amountLabel)
        }

        self.statusImageView = statusImageView
    }

    private func removeStatusView() {
        guard statusImageView != nil else {
            return
        }

        statusImageView?.removeFromSuperview()
        statusImageView = nil
    }

    private func updateAmountConstraints() {
        amountLabel.snp.updateConstraints { make in
            if let statusSize = statusImageView?.image?.size {
                let offset = UIConstants.horizontalInset + statusSize.width + Constants.statusOffset
                make.trailing.equalTo(contentView).offset(-offset)
            } else {
                make.trailing.trailing.equalTo(contentView).offset(-UIConstants.horizontalInset)
            }
        }

        amountLabel.snp.contentHuggingHorizontalPriority = titleLabel.snp.contentHuggingHorizontalPriority + 1
        statusImageView?.snp.contentHuggingHorizontalPriority =
            amountLabel.snp.contentHuggingHorizontalPriority + 1

        amountLabel.snp.contentCompressionResistanceHorizontalPriority =
            titleLabel.snp.contentCompressionResistanceHorizontalPriority + 1
        statusImageView?.snp.contentCompressionResistanceHorizontalPriority =
            amountLabel.snp.contentCompressionResistanceHorizontalPriority + 1
    }
}

extension HistoryItemTableViewCell: WalletViewProtocol {
    func bind(viewModel: WalletViewModelProtocol) {
        if let itemViewModel = viewModel as? HistoryItemViewModel {
            self.viewModel = viewModel

            titleLabel.text = itemViewModel.title
            subtitleLabel.text = itemViewModel.subtitle
            timeLabel.text = itemViewModel.time

            switch itemViewModel.type {
            case .incoming, .reward:
                amountLabel.text = "+ \(itemViewModel.amount)"
                amountLabel.textColor = R.color.colorGreen()!
            case .outgoing, .slash, .extrinsic:
                amountLabel.text = "- \(itemViewModel.amount)"
                amountLabel.textColor = R.color.colorWhite()!
            }

            switch itemViewModel.status {
            case .commited:
                removeStatusView()
            case .rejected:
                addStatusViewIfNeeded()
                statusImageView?.image = R.image.iconTxFailed()
                amountLabel.textColor = R.color.colorGray()!
            case .pending:
                addStatusViewIfNeeded()
                statusImageView?.image = R.image.iconTxPending()
                amountLabel.textColor = R.color.colorWhite()
            }

            transactionTypeView.image = nil

            itemViewModel.imageViewModel?.loadImage { [weak self] image, _ in
                self?.transactionTypeView.image = image
            }

            updateAmountConstraints()

            setNeedsLayout()
        }
    }
}
