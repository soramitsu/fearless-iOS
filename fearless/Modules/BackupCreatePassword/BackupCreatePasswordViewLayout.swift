import UIKit
import SnapKit

final class BackupCreatePasswordViewLayout: UIView {
    var keyboardAdoptableConstraint: Constraint?

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    let navigationBar: BaseNavigationBar = {
        let view = BaseNavigationBar()
        view.backgroundColor = R.color.colorBlack19()
        return view
    }()

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.spacing = UIConstants.bigOffset
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .p0Paragraph
        label.textColor = R.color.colorStrokeGray()!
        label.numberOfLines = 0
        return label
    }()

    lazy var passwordTextField: CommonInputView = {
        createPasswordTextField()
    }()

    lazy var confirmPasswordTextField: CommonInputView = {
        createPasswordTextField()
    }()

    let passwordMatchLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        return label
    }()

    let warningLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()

    let continueButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        button.isEnabled = false
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBlack19()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        navigationBar.backButton.rounded()
    }

    func setPassword(isMatched: Bool) {
        if isMatched {
            passwordMatchLabel.text = R.string.localizable
                .backupCreatePasswordMatched(preferredLanguages: locale.rLanguages)
            passwordMatchLabel.textColor = R.color.colorStrokeGray()!
        } else {
            passwordMatchLabel.text = R.string.localizable
                .backupCreatePasswordNotMatched(preferredLanguages: locale.rLanguages)
            passwordMatchLabel.textColor = R.color.colorRed()!
        }
    }

    // MARK: - Private methods

    private func setupLayout() {
        func makeCommonConstraint(for view: UIView) {
            view.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
            }
        }

        addSubview(navigationBar)
        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom).offset(UIConstants.bigOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        contentView.stackView.addArrangedSubview(descriptionLabel)
        contentView.stackView.addArrangedSubview(passwordTextField)
        contentView.stackView.addArrangedSubview(confirmPasswordTextField)
        contentView.stackView.setCustomSpacing(UIConstants.defaultOffset, after: confirmPasswordTextField)
        contentView.stackView.addArrangedSubview(passwordMatchLabel)
        let warningView = createWarningView(with: warningLabel)
        contentView.stackView.addArrangedSubview(warningView)

        [
            descriptionLabel,
            passwordTextField,
            confirmPasswordTextField,
            passwordMatchLabel,
            warningView
        ].forEach { makeCommonConstraint(for: $0) }

        addSubview(continueButton)
        continueButton.snp.makeConstraints { make in
            make.top.equalTo(contentView.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            keyboardAdoptableConstraint = make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset).constraint
            make.height.equalTo(UIConstants.actionHeight)
        }
    }

    private func createWarningView(with label: UILabel) -> UIView {
        let stack = UIFactory.default.createHorizontalStackView(spacing: UIConstants.bigOffset)
        stack.alignment = .center
        let imageView = UIImageView(image: R.image.iconCheckMark())
        imageView.snp.makeConstraints { make in
            make.size.equalTo(20)
        }
        stack.addArrangedSubview(imageView)
        stack.addArrangedSubview(label)
        label.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
        }
        return stack
    }

    private func createPasswordTextField() -> CommonInputView {
        let inputView = CommonInputView()
        inputView.defaultSetup()
        inputView.backgroundView.fillColor = R.color.colorSemiBlack()!
        inputView.backgroundView.highlightedFillColor = R.color.colorSemiBlack()!
        inputView.backgroundView.strokeColor = R.color.colorWhite8()!
        inputView.backgroundView.highlightedStrokeColor = R.color.colorPink()!
        inputView.backgroundView.strokeWidth = 0.5
        inputView.backgroundView.shadowOpacity = 0
        inputView.animatedInputField.placeholderColor = R.color.colorLightGray()!
        inputView.animatedInputField.textField.isSecureTextEntry = true
        inputView.animatedInputField.textField.returnKeyType = .done
        return inputView
    }

    private func applyLocalization() {
        let title = R.string.localizable
            .backupCreatePasswordConfirmFieldTitle(preferredLanguages: locale.rLanguages)
        navigationBar.setTitle(title)
        descriptionLabel.text = R.string.localizable
            .backupCreatePasswordDescription(preferredLanguages: locale.rLanguages)
        passwordTextField.title = R.string.localizable
            .backupCreatePasswordPasswordFieldTitle(preferredLanguages: locale.rLanguages)
        confirmPasswordTextField.title = R.string.localizable
            .backupCreatePasswordConfirmFieldTitle(preferredLanguages: locale.rLanguages)
        warningLabel.text = R.string.localizable
            .backupCreatePasswordWarning(preferredLanguages: locale.rLanguages)
        continueButton.imageWithTitleView?.title = R.string.localizable
            .backupCreatePasswordContinueButton(preferredLanguages: locale.rLanguages)
    }
}
