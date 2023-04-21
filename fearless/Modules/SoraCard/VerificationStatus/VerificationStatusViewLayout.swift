import UIKit

final class VerificationStatusViewLayout: UIView {
    private enum LayoutConstants {
        static let cardImageSize: CGSize = CGSizeMake(257, 155)
        static let statusIconSize: CGSize = CGSizeMake(80, 80)
        static let cardImageTopSpacing: CGFloat = 56
        static let cardImageBottomSpacing: CGFloat = 80
        static let supportButtonHeight: CGFloat = 30
    }

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 24.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.stackView.spacing = UIConstants.bigOffset
        return view
    }()

    let titleContainerView = UIView()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = R.color.colorWhite()
        return label
    }()

    let supportButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(R.color.colorPink1(), for: .normal)
        button.titleLabel?.font = .h5Title
        button.isHidden = true
        return button
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
        backgroundColor = R.color.colorBlack()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(status: SoraCardStatus) {
        self.status = status

        titleLabel.text = status.title(with: locale)
        statusLabel.text = status.description(with: locale)
        statusImageView.image = status.iconImage
        actionButton.setTitle(status.buttonTitle(with: locale).uppercased(), for: .normal)
        supportButton.isHidden = true

        if case let .rejected(hasFreeAttempts) = status, hasFreeAttempts == false {
            supportButton.isHidden = false
        }

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
        supportButton.setTitle("Support", for: .normal)
    }

    private func setupLayout() {
        addSubview(contentView)

        titleContainerView.addSubview(titleLabel)
        titleContainerView.addSubview(supportButton)

        contentView.stackView.addArrangedSubview(titleContainerView)
        contentView.stackView.addArrangedSubview(statusLabel)
        contentView.stackView.addArrangedSubview(infoLabel)
        contentView.stackView.addArrangedSubview(cardImageContainerView)
        contentView.stackView.addArrangedSubview(actionButton)

        contentView.stackView.setCustomSpacing(
            LayoutConstants.cardImageTopSpacing,
            after: infoLabel
        )
        contentView.stackView.setCustomSpacing(
            LayoutConstants.cardImageBottomSpacing,
            after: cardImageContainerView
        )

        cardImageContainerView.addSubview(cardImageView)
        cardImageContainerView.addSubview(statusImageView)

        contentView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }

        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.roundedButtonHeight)
        }

        titleContainerView.snp.makeConstraints { make in
            make.width.equalTo(contentView)
        }

        supportButton.snp.makeConstraints { make in
            make.trailing.top.bottom.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(LayoutConstants.supportButtonHeight)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().inset(UIConstants.bigOffset)
            make.trailing.lessThanOrEqualTo(supportButton.snp.leading)
        }

        statusLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        infoLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        cardImageContainerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        cardImageView.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.cardImageSize)
            make.centerX.equalToSuperview()
            make.top.bottom.equalToSuperview()
        }

        statusImageView.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.statusIconSize)
            make.trailing.equalTo(cardImageView).offset(UIConstants.bigOffset)
            make.top.equalTo(cardImageView).inset(-UIConstants.bigOffset)
        }
    }
}
