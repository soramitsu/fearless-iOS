import UIKit

final class WalletNameViewLayout: UIView {
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

    let nameTextField: CommonInputView = {
        let inputView = CommonInputView()
        inputView.backgroundView.fillColor = R.color.colorSemiBlack()!
        inputView.backgroundView.highlightedFillColor = R.color.colorSemiBlack()!
        inputView.backgroundView.strokeColor = R.color.colorWhite8()!
        inputView.backgroundView.highlightedStrokeColor = R.color.colorPink()!
        inputView.backgroundView.strokeWidth = 0.5
        inputView.backgroundView.shadowOpacity = 0
        inputView.animatedInputField.placeholderColor = R.color.colorLightGray()!
        inputView.defaultSetup()
        return inputView
    }()

    let bottomDescriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorStrokeGray()!
        label.textAlignment = .left
        label.numberOfLines = 0
        return label
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

    let mode: WalletNameScreenMode

    init(mode: WalletNameScreenMode) {
        self.mode = mode
        super.init(frame: .zero)
        backgroundColor = R.color.colorBlack19()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

        addSubview(nameTextField)
        nameTextField.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(UIConstants.bigOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(64)
        }

        addSubview(bottomDescriptionLabel)
        bottomDescriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(nameTextField.snp.bottom).offset(UIConstants.bigOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        addSubview(continueButton)
        continueButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }

    private func applyLocalization() {
        switch mode {
        case .editing:
            let title = R.string.localizable
                .backupWalletNameEditingTitle(preferredLanguages: locale.rLanguages)
            navigationBar.setTitle(title)
            descriptionLabel.text = R.string.localizable
                .backupWalletNameEditingDescription(preferredLanguages: locale.rLanguages)
            bottomDescriptionLabel.text = nil
            continueButton.imageWithTitleView?.title = R.string.localizable
                .commonSave(preferredLanguages: locale.rLanguages)
        case .create:
            let title = R.string.localizable
                .backupWalletNameCreateTitle(preferredLanguages: locale.rLanguages)
            navigationBar.setTitle(title)
            descriptionLabel.text = R.string.localizable
                .backupWalletNameCreateDescription(preferredLanguages: locale.rLanguages)
            bottomDescriptionLabel.text = R.string.localizable
                .backupWalletNameCreateBottomDecription(preferredLanguages: locale.rLanguages)
            continueButton.imageWithTitleView?.title = R.string.localizable
                .commonContinue(preferredLanguages: locale.rLanguages)
        }
        nameTextField.title = R.string.localizable
            .backupWalletNameFieldNameTitle(preferredLanguages: locale.rLanguages)
    }
}
