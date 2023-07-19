import UIKit

final class BackupWalletImportedViewLayout: UIView {
    let navigationBar: BaseNavigationBar = {
        let view = BaseNavigationBar()
        view.backgroundColor = R.color.colorBlack19()
        return view
    }()

    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .p0Paragraph
        label.textColor = R.color.colorStrokeGray()!
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    let triangularedView: TriangularedView = {
        let view = TriangularedView()
        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!
        view.strokeColor = R.color.colorWhite8()!
        view.strokeWidth = 0.5
        view.shadowOpacity = 0
        return view
    }()

    let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconBirdGreen()
        return imageView
    }()

    let walletNameLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorStrokeGray()!
        return label
    }()

    let continueButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    let importMoreButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDisabledStyle()
        return button
    }()

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
        backgroundColor = R.color.colorBlack19()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        navigationBar.backButton.rounded()
    }

    func bind(walletName: String) {
        walletNameLabel.text = walletName
    }

    // MARK: - Private methods

    private func setupLayout() {
        addSubview(navigationBar)
        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        addSubview(triangularedView)
        triangularedView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom).offset(UIConstants.bigOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(72)
        }

        addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(triangularedView.snp.bottom).offset(UIConstants.bigOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        iconImageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        triangularedView.addSubview(iconImageView)
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
            make.size.equalTo(UIConstants.normalAddressIconSize)
        }

        triangularedView.addSubview(walletNameLabel)
        walletNameLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
        }

        let buttonVStack = UIFactory.default.createVerticalStackView(spacing: UIConstants.defaultOffset)
        addSubview(buttonVStack)
        buttonVStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
        }

        buttonVStack.addArrangedSubview(continueButton)
        continueButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.actionHeight)
        }

        buttonVStack.addArrangedSubview(importMoreButton)
        importMoreButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.actionHeight)
        }
    }

    private func applyLocalization() {
        let title = R.string.localizable
            .backupWalletImportedTitle(preferredLanguages: locale.rLanguages)
        navigationBar.setTitle(title)
        descriptionLabel.text = R.string.localizable
            .backupWalletImportedDescription(preferredLanguages: locale.rLanguages)
        importMoreButton.imageWithTitleView?.title = R.string.localizable
            .backupWalletImportedImportMore(preferredLanguages: locale.rLanguages)
        continueButton.imageWithTitleView?.title = R.string.localizable
            .commonContinue(preferredLanguages: locale.rLanguages)
    }
}
