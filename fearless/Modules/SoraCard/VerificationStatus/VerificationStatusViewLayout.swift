import UIKit

final class VerificationStatusViewLayout: UIView {
    private enum LayoutConstants {
        static let cardImageSize: CGSize = CGSizeMake(257, 155)
        static let statusIconSize: CGSize = CGSizeMake(80, 80)
        static let closeButtonSize: CGSize = CGSizeMake(40, 40)
    }

    let navigationBar: BaseNavigationBar = {
        let bar = BaseNavigationBar()
        bar.backgroundColor = R.color.colorBlack()
        bar.backButton.setImage(R.image.iconBackPinkBold(), for: .normal)
        return bar
    }()

    let closeButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconClosePinkBold(), for: .normal)
        return button
    }()

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 24.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.stackView.spacing = UIConstants.hugeOffset
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h1Title
        label.textColor = R.color.colorWhite()
        return label
    }()

    let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 0
        return label
    }()

    let infoLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 0
        return label
    }()

    let cardImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.soraCardFront()
        imageView.isHidden = true
        return imageView
    }()

    let cardImageContainerView = UIView()
    let statusImageView = UIImageView()
    let actionButton = UIFactory.default.createRoundedButton()

    var locale = Locale.current {
        didSet {
            applyLocalization()
        }
    }

    private var status: SoraCardStatus?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(status: SoraCardStatus) {
        self.status = status

        cardImageView.isHidden = false

        titleLabel.text = status.title(with: locale)
        statusLabel.text = status.description(with: locale)
        statusImageView.image = status.iconImage
        actionButton.setTitle(status.buttonTitle(with: locale).uppercased(), for: .normal)

        switch status {
        case .rejected:
            actionButton.backgroundColor = R.color.colorWhiteAccentSecondary()
            actionButton.setTitleColor(R.color.colorBlackAccentSecondary(), for: .normal)
        default:
            actionButton.backgroundColor = R.color.colorBlackAccentSecondary()
            actionButton.setTitleColor(R.color.colorWhiteAccentSecondary(), for: .normal)
        }
    }

    private func applyLocalization() {
        if let status = status {
            bind(status: status)
        }
    }

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(contentView)
        addSubview(actionButton)

        navigationBar.setRightViews([closeButton])

        contentView.stackView.addArrangedSubview(titleLabel)
        contentView.stackView.addArrangedSubview(statusLabel)
        contentView.stackView.addArrangedSubview(infoLabel)
        contentView.stackView.addArrangedSubview(cardImageContainerView)

        cardImageContainerView.addSubview(cardImageView)
        cardImageContainerView.addSubview(statusImageView)

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }

        closeButton.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.closeButtonSize)
        }

        actionButton.snp.makeConstraints { make in
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.hugeOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.hugeOffset)
            make.top.equalTo(contentView.snp.bottom).inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.roundedButtonHeight)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.hugeOffset)
        }

        statusLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.hugeOffset)
        }

        infoLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.hugeOffset)
        }

        cardImageContainerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.hugeOffset)
            make.top.equalTo(infoLabel.snp.bottom).offset(UIConstants.bigOffset)
            make.bottom.equalTo(actionButton.snp.top).inset(UIConstants.bigOffset)
        }

        cardImageView.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.cardImageSize)
            make.center.equalToSuperview()
        }

        statusImageView.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.statusIconSize)
            make.trailing.equalTo(cardImageView).offset(UIConstants.bigOffset)
            make.top.equalTo(cardImageView).inset(-UIConstants.bigOffset)
        }
    }
}
