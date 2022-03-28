import UIKit

protocol WalletDetailsTableCellDelegate: AnyObject {
    func didTapActions(_ cell: WalletDetailsTableCell)
}

class WalletDetailsTableCell: UITableViewCell {
    enum LayoutConstants {
        static let chainImageSize: CGFloat = 27
        static let addressImageSize: CGFloat = 16
        static let actionImageSize: CGFloat = 18
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

    private var chainImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
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

    private var chainLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    private var addressStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.spacing = 0
        stackView.axis = .horizontal
        stackView.distribution = .fillProportionally
        stackView.alignment = .fill
        stackView.spacing = UIConstants.defaultOffset
        return stackView
    }()

    private var addressImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private var addressLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorStrokeGray()
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    private var actionImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = R.image.iconHorMore()
        imageView.isUserInteractionEnabled = true
        return imageView
    }()

    var locale = Locale.current {
        didSet {
            applyLocalization()
        }
    }

    private var chainUnsupportedView: HintView = {
        let view = UIFactory.default.createHintView()
        view.iconView.image = R.image.iconWarning()
        return view
    }()

    weak var delegate: WalletDetailsTableCellDelegate?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        configure()
        setupLayout()

        applyLocalization()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        chainImageView.kf.cancelDownloadTask()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyLocalization() {
        chainUnsupportedView.titleLabel.text = R.string.localizable.commonUnsupported()
    }

    func bind(to viewModel: WalletDetailsCellViewModel) {
        viewModel.chainImageViewModel?.cancel(on: chainImageView)
        viewModel.chainImageViewModel?.loadImage(
            on: chainImageView,
            targetSize: CGSize(width: LayoutConstants.chainImageSize, height: LayoutConstants.chainImageSize),
            animated: false
        )

        chainLabel.text = viewModel.chain.name
        addressLabel.text = viewModel.address
        if let addressImage = viewModel.addressImage {
            addressImageView.isHidden = false
            addressImageView.image = addressImage
        } else {
            addressImageView.isHidden = true
        }

        let chainSupported: Bool = viewModel.chain.isSupported
        addressStackView.isHidden = !chainSupported
        chainUnsupportedView.isHidden = chainSupported
        actionImageView.isHidden = !chainSupported

        setDeactivated(!chainSupported)
    }
}

private extension WalletDetailsTableCell {
    func configure() {
        backgroundColor = .clear

        separatorInset = UIEdgeInsets(
            top: 0.0,
            left: UIConstants.horizontalInset,
            bottom: 0.0,
            right: UIConstants.horizontalInset
        )

        selectionStyle = .none

        let recognizer = UITapGestureRecognizer()
        recognizer.addTarget(self, action: #selector(showActions))
        actionImageView.addGestureRecognizer(recognizer)
    }

    func setupLayout() {
        contentView.addSubview(mainStackView)
        mainStackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalToSuperview()
        }

        mainStackView.addArrangedSubview(chainImageView)
        chainImageView.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.chainImageSize)
        }

        mainStackView.addArrangedSubview(infoStackView)

        mainStackView.addArrangedSubview(actionImageView)
        actionImageView.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.actionImageSize)
        }

        infoStackView.addArrangedSubview(chainLabel)
        infoStackView.addArrangedSubview(addressStackView)
        addressStackView.snp.makeConstraints { make in
            make.width.equalTo(infoStackView)
        }

        addressStackView.addArrangedSubview(addressImageView)
        addressImageView.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.addressImageSize)
        }
        addressStackView.addArrangedSubview(addressLabel)
        infoStackView.addArrangedSubview(chainUnsupportedView)
    }

    @objc
    private func showActions() {
        delegate?.didTapActions(self)
    }
}

extension WalletDetailsTableCell: DeactivatableView {
    var deactivatableViews: [UIView] {
        [chainImageView, chainLabel, addressLabel, addressImageView, chainUnsupportedView]
    }

    var deactivatedAlpha: CGFloat {
        0.5
    }
}
