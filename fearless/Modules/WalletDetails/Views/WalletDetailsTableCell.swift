import UIKit

protocol WalletDetailsTableCellDelegate: AnyObject {
    func didTapActions(_ cell: WalletDetailsTableCell)
}

class WalletDetailsTableCell: UITableViewCell {
    enum LayoutConstants {
        static let chainImageSize: CGFloat = 27
        static let actionImageSize: CGFloat = 18
    }

    private let backgroundTriangularedView: TriangularedView = {
        let view = TriangularedView()
        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!
        view.strokeColor = R.color.colorWhite8()!
        view.strokeWidth = 1
        view.shadowOpacity = 0
        return view
    }()

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
        label.font = .h5Title
        label.textColor = R.color.colorStrokeGray()
        return label
    }()

    private var addressLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
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

    private var accountMissingHintView: HintView = {
        let view = UIFactory.default.createHintView()
        view.iconView.image = R.image.iconWarning()
        return view
    }()

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
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        chainImageView.kf.cancelDownloadTask()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

        let chainSupported: Bool = viewModel.chain.isSupported
        addressLabel.isHidden = !chainSupported || viewModel.accountMissing
        chainUnsupportedView.isHidden = chainSupported
        actionImageView.isHidden = !chainSupported || !viewModel.actionsAvailable

        accountMissingHintView.isHidden = !viewModel.accountMissing
        accountMissingHintView.setIconHidden(viewModel.chainUnused)

        setDeactivated(viewModel.cellInactive)

        chainUnsupportedView.titleLabel.text = R.string.localizable.commonUnsupported(
            preferredLanguages: viewModel.locale?.rLanguages
        )
        accountMissingHintView.titleLabel.text = R.string.localizable.noAccountFound(
            preferredLanguages: viewModel.locale?.rLanguages
        )
    }
}

private extension WalletDetailsTableCell {
    func configure() {
        backgroundColor = .clear

        separatorInset = UIEdgeInsets.zero
        selectionStyle = .none

        let recognizer = UITapGestureRecognizer()
        recognizer.addTarget(self, action: #selector(showActions))
        actionImageView.addGestureRecognizer(recognizer)
    }

    func setupLayout() {
        contentView.addSubview(backgroundTriangularedView)
        backgroundTriangularedView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.top.bottom.equalToSuperview().inset(UIConstants.minimalOffset)
            make.height.equalTo(64)
        }

        backgroundTriangularedView.addSubview(mainStackView)
        mainStackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.top.bottom.equalToSuperview()
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
        infoStackView.addArrangedSubview(addressLabel)
        infoStackView.addArrangedSubview(chainUnsupportedView)
        infoStackView.addArrangedSubview(accountMissingHintView)
    }

    @objc
    private func showActions() {
        delegate?.didTapActions(self)
    }
}

extension WalletDetailsTableCell: DeactivatableView {
    var deactivatableViews: [UIView] {
        [chainImageView, chainLabel, addressLabel, chainUnsupportedView, accountMissingHintView.titleLabel]
    }

    var deactivatedAlpha: CGFloat {
        0.5
    }
}
