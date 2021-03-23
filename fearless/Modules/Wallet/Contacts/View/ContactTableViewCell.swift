import UIKit
import CommonWallet

final class ContactTableViewCell: UITableViewCell {
    struct Constants {
        static let iconRadius: CGFloat = 12.0
        static let horizontalSpacing: CGFloat = 12.0
        static let contentInsets = UIEdgeInsets(top: 8.0, left: 16.0, bottom: 8.0, right: 16.0)
    }

    private var titleLabel: UILabel = UILabel()
    private var subtitleLabel: UILabel?
    private var iconImageView: UIImageView = UIImageView()

    var viewModel: WalletViewModelProtocol?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorAccent()!.withAlphaComponent(0.3)
        self.selectedBackgroundView = selectedBackgroundView

        setupTitleLabel()
        setupImageView()

        accessoryView = UIImageView(image: R.image.iconSmallArrow())
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let bounds = contentView.bounds
        let insets = Constants.contentInsets
        let iconRadius = Constants.iconRadius

        iconImageView.frame = CGRect(x: bounds.minX + insets.left,
                                     y: bounds.midY - iconRadius,
                                     width: 2.0 * iconRadius,
                                     height: 2.0 * iconRadius)

        let position = iconImageView.frame.maxX + Constants.horizontalSpacing
        let width = bounds.width - position - insets.right

        let titleHeight = titleLabel.intrinsicContentSize.height

        if let subtitleLabel = subtitleLabel {
            titleLabel.frame = CGRect(x: position,
                                      y: bounds.minY + insets.top,
                                      width: width,
                                      height: titleHeight)

            let subtitleHeight = subtitleLabel.intrinsicContentSize.height
            subtitleLabel.frame = CGRect(x: position,
                                         y: bounds.maxY - insets.bottom - subtitleHeight,
                                         width: width,
                                         height: subtitleHeight)
        } else {
            titleLabel.frame = CGRect(x: position,
                                      y: bounds.midY - titleHeight / 2.0,
                                      width: width,
                                      height: titleHeight)
        }
    }

    private func setupTitleLabel() {
        addSubview(titleLabel)

        titleLabel.textColor = R.color.colorWhite()
        titleLabel.font = UIFont.p1Paragraph
        titleLabel.lineBreakMode = .byTruncatingMiddle
    }

    private func setupSubtitleLabel() {
        guard subtitleLabel == nil else {
            return
        }

        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = UIFont.p2Paragraph
        label.lineBreakMode = .byTruncatingMiddle
        contentView.addSubview(label)

        subtitleLabel = label
    }

    private func setupImageView() {
        iconImageView.contentMode = .scaleAspectFill
        contentView.addSubview(iconImageView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ContactTableViewCell: WalletViewProtocol {
    func bind(viewModel: WalletViewModelProtocol) {
        if let contactsViewModel = viewModel as? ContactViewModelProtocol {
            self.viewModel = contactsViewModel

            let title = contactsViewModel.lastName.isEmpty ?
                contactsViewModel.firstName : contactsViewModel.lastName
            let optionalSubtitle = !contactsViewModel.lastName.isEmpty ? contactsViewModel.firstName : nil

            titleLabel.text = title

            if let subtitle = optionalSubtitle {
                setupSubtitleLabel()

                subtitleLabel?.text = subtitle
            } else {
                subtitleLabel?.removeFromSuperview()
                subtitleLabel = nil
            }

            imageView?.image = contactsViewModel.image

            setNeedsLayout()
        }
    }
}
