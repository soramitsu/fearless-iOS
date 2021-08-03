import Foundation
import SnapKit
import CommonWallet

final class HistoryItemTableViewCell: UITableViewCell {
    private enum Constants {
        static let verticalInset: CGFloat = 11
        static let iconSize: CGFloat = 32
        static let statusOffset: CGFloat = 4.0
        static let titleSpacingForTransfer: CGFloat = 64.0
        static let titleSpacingForOthers: CGFloat = 8.0
    }

    private let transactionTypeView = UIImageView()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorTransparentText()
        return label
    }()

    private let amountLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        return label
    }()

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorTransparentText()
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
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.width.equalTo(Constants.iconSize)
        }

        contentView.addSubview(amountLabel)

        amountLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().inset(Constants.verticalInset)
        }

        contentView.addSubview(titleLabel)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(transactionTypeView.snp.trailing).offset(UIConstants.horizontalInset / 2.0)
            make.top.equalToSuperview().inset(Constants.verticalInset)
            make.trailing.lessThanOrEqualTo(amountLabel.snp.leading)
                .offset(-Constants.titleSpacingForTransfer)
        }

        contentView.addSubview(timeLabel)

        timeLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(amountLabel.snp.bottom)
            make.bottom.equalToSuperview().inset(Constants.verticalInset)
        }

        contentView.addSubview(subtitleLabel)

        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(transactionTypeView.snp.trailing).offset(UIConstants.horizontalInset / 2.0)
            make.top.equalTo(titleLabel.snp.bottom)
            make.bottom.equalToSuperview().inset(Constants.verticalInset)
            make.trailing.lessThanOrEqualTo(timeLabel.snp.leading)
                .offset(-UIConstants.horizontalInset)
        }
    }

    private func addStatusViewIfNeeded() {
        guard statusImageView == nil else {
            return
        }

        let statusImageView = UIImageView()
        contentView.addSubview(statusImageView)

        statusImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
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
                let inset = UIConstants.horizontalInset + statusSize.width + Constants.statusOffset
                make.trailing.equalToSuperview().inset(inset)
            } else {
                make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            }
        }
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

            switch itemViewModel.type {
            case .incoming, .outgoing:
                titleLabel.lineBreakMode = .byTruncatingMiddle

                titleLabel.snp.updateConstraints { make in
                    make.trailing.lessThanOrEqualTo(amountLabel.snp.leading)
                        .offset(-Constants.titleSpacingForTransfer)
                }

            case .slash, .reward, .extrinsic:
                titleLabel.lineBreakMode = .byTruncatingTail

                titleLabel.snp.updateConstraints { make in
                    make.trailing.lessThanOrEqualTo(amountLabel.snp.leading)
                        .offset(-Constants.titleSpacingForOthers)
                }
            }

            switch itemViewModel.status {
            case .commited:
                removeStatusView()
            case .rejected:
                addStatusViewIfNeeded()
                statusImageView?.image = R.image.iconTxFailed()
                amountLabel.textColor = R.color.colorTransparentText()
            case .pending:
                addStatusViewIfNeeded()
                statusImageView?.image = R.image.iconPending()
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
