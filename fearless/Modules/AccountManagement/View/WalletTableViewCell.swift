import UIKit
import FearlessUtils
import SoraUI

protocol WalletTableViewCellDelegate: AnyObject {
    func didSelectInfo(_ cell: WalletTableViewCell)
}

final class WalletTableViewCell: UITableViewCell {
    enum LayoutConstants {
        static let selectionImageSize: CGFloat = 24
        static let walletIconSize: CGFloat = 32
        static let infoButtonSize: CGFloat = 20
    }

    private var mainStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.spacing = 0
        stackView.axis = .horizontal
        stackView.distribution = .fillProportionally
        stackView.alignment = .fill
        stackView.spacing = UIConstants.defaultOffset
        return stackView
    }()

    private var selectionImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = R.color.colorWhite()
        return imageView
    }()

    private var walletIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = R.image.iconBirdGreen()
        return imageView
    }()

    private var infoStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.spacing = 0
        stackView.axis = .vertical
        stackView.distribution = .fillProportionally
        stackView.alignment = .leading
        return stackView
    }()

    private var walletLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    private var totalBalanceLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorStrokeGray()
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    private var infoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        return imageView
    }()

    weak var delegate: WalletTableViewCellDelegate?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        configure()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(to viewModel: ManagedAccountViewModelItem) {
        if viewModel.isSelected {
            selectionImageView.image = R.image.listCheckmarkIcon()
            infoImageView.image = R.image.iconInfo()
        } else {
            selectionImageView.image = nil
            infoImageView.image = R.image.iconInfoFilled()
        }
        walletLabel.text = viewModel.name
        totalBalanceLabel.text = viewModel.totalBalance
    }

    func setReordering(_ reordering: Bool, animated: Bool) {
        let closure = {
            self.infoImageView.alpha = reordering ? 0.0 : 1.0
        }

        if animated {
            BlockViewAnimator().animate(block: closure, completionBlock: nil)
        } else {
            closure()
        }

        if reordering {
            recolorReorderControl(R.color.colorWhite()!)
        }
    }
}

private extension WalletTableViewCell {
    func configure() {
        backgroundColor = .clear

        separatorInset = UIEdgeInsets(
            top: 0.0,
            left: UIConstants.horizontalInset,
            bottom: 0.0,
            right: UIConstants.horizontalInset
        )

        selectionStyle = .none

        showsReorderControl = false

        let recognizer = UITapGestureRecognizer()
        recognizer.addTarget(self, action: #selector(actionInfo))
        infoImageView.addGestureRecognizer(recognizer)
    }

    func setupLayout() {
        contentView.addSubview(mainStackView)
        mainStackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalToSuperview()
        }

        mainStackView.addArrangedSubview(selectionImageView)
        selectionImageView.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.selectionImageSize)
        }

        mainStackView.addArrangedSubview(walletIconView)
        walletIconView.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.walletIconSize)
        }

        mainStackView.addArrangedSubview(infoStackView)

        infoStackView.addArrangedSubview(walletLabel)

        mainStackView.addArrangedSubview(infoImageView)
        infoImageView.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.infoButtonSize)
        }
    }

    @objc
    private func actionInfo() {
        delegate?.didSelectInfo(self)
    }
}
