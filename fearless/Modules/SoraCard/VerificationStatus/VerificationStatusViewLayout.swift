import UIKit

final class VerificationStatusViewLayout: UIView {
    private enum LayoutConstants {
        static let cardImageSize: CGSize = CGSizeMake(257, 155)
        static let statusIconSize: CGSize = CGSizeMake(80, 80)
    }

    let navigationBar: BaseNavigationBar = {
        let bar = BaseNavigationBar()
        bar.set(.push)
        bar.backButton.backgroundColor = R.color.colorWhite8()
        bar.backButton.rounded()
        bar.backgroundColor = R.color.colorBlack()
        return bar
    }()

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = R.color.colorWhite()
        return label
    }()

    let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 0
        return label
    }()

    let infoLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 0
        return label
    }()

    let cardImageContainerView = UIView()
    let cardImageView = UIImageView()
    let statusImageView = UIImageView()
    let actionButton = UIFactory.default.createRoundedButton()

    var locale = Locale.current {
        didSet {}
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyLocalization() {}

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(contentView)
        addSubview(actionButton)

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

        actionButton.snp.makeConstraints { make in
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.hugeOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.top.equalTo(contentView.snp.bottom).inset(UIConstants.bigOffset)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        statusLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        infoLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        cardImageView.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.cardImageSize)
        }

        statusImageView.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.statusIconSize)
            make.top.trailing.equalTo(cardImageView).offset(UIConstants.bigOffset)
        }
    }

    func bind(status: SoraCardStatus) {
        titleLabel.text = status.title(with: locale)
        statusLabel.text = status.description(with: locale)
        statusImageView.image = status.iconImage
        actionButton.setTitle(status.buttonTitle(with: locale), for: .normal)

        switch status {
        case .rejected:
            actionButton.backgroundColor = R.color.colorWhiteAccentSecondary()
            actionButton.setTitleColor(R.color.colorBlackAccentSecondary(), for: .normal)
        default:
            actionButton.backgroundColor = R.color.colorBlackAccentSecondary()
            actionButton.setTitleColor(R.color.colorWhiteAccentSecondary(), for: .normal)
        }
    }
}
