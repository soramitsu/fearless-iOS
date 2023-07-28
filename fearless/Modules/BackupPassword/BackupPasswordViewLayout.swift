import UIKit
import SnapKit

final class BackupPasswordViewLayout: UIView {
    var keyboardAdoptableConstraint: Constraint?

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

    let passwordTextField: CommonInputView = {
        let inputView = CommonInputView()
        inputView.backgroundView.fillColor = R.color.colorSemiBlack()!
        inputView.backgroundView.highlightedFillColor = R.color.colorSemiBlack()!
        inputView.backgroundView.strokeColor = R.color.colorWhite8()!
        inputView.backgroundView.highlightedStrokeColor = R.color.colorPink()!
        inputView.backgroundView.strokeWidth = 0.5
        inputView.backgroundView.shadowOpacity = 0
        inputView.animatedInputField.placeholderColor = R.color.colorLightGray()!
        inputView.defaultSetup()
        inputView.animatedInputField.textField.isSecureTextEntry = true
        return inputView
    }()

    let continueButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        button.isEnabled = false
        return button
    }()

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBlack19()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

        addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom).offset(UIConstants.bigOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        addSubview(triangularedView)
        triangularedView.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(UIConstants.bigOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(72)
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

        addSubview(passwordTextField)
        passwordTextField.snp.makeConstraints { make in
            make.top.equalTo(triangularedView.snp.bottom).offset(UIConstants.bigOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(64)
        }

        addSubview(continueButton)
        continueButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            keyboardAdoptableConstraint = make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset).constraint
            make.height.equalTo(UIConstants.actionHeight)
        }
    }

    private func applyLocalization() {
        let title = R.string.localizable
            .backupPasswordTitle(preferredLanguages: locale.rLanguages)
        navigationBar.setTitle(title)
        descriptionLabel.text = R.string.localizable
            .backupPasswordDescription(preferredLanguages: locale.rLanguages)
        passwordTextField.title = R.string.localizable
            .backupPasswordPasswordFieldTitle(preferredLanguages: locale.rLanguages)
        continueButton.imageWithTitleView?.title = R.string.localizable
            .commonContinue(preferredLanguages: locale.rLanguages)
    }
}
