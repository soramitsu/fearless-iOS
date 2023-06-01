import UIKit
import SSFUtils
import SoraUI

protocol WalletTableViewCellDelegate: AnyObject {
    func didSelectInfo(_ cell: WalletTableViewCell)
}

final class WalletTableViewCell: UITableViewCell {
    enum LayoutConstants {
        static let selectionImageSize: CGFloat = 24
        static let walletIconSize: CGFloat = 32
        static let infoButtonSize: CGFloat = 20
        static let separatorHeight: CGFloat = 1 / UIScreen.main.scale
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

    private let totalBalanceActivityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView()
        indicator.hidesWhenStopped = true
        return indicator
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
        selectionImageView.image = viewModel.isSelected
            ? R.image.listCheckmarkIcon()
            : nil
        infoImageView.image = R.image.iconHorMore()
        walletLabel.text = viewModel.name

        viewModel.totalBalance == nil
            ? totalBalanceActivityIndicator.startAnimating()
            : totalBalanceActivityIndicator.stopAnimating()

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
        let separator = UIView.createSeparator()
        contentView.addSubview(separator)
        separator.snp.makeConstraints { make in
            make.height.equalTo(LayoutConstants.separatorHeight)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalToSuperview()
        }

        contentView.addSubview(mainStackView)
        mainStackView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(separator.snp.top)
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
        infoStackView.addArrangedSubview(totalBalanceLabel)
        infoStackView.addArrangedSubview(totalBalanceActivityIndicator)

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
