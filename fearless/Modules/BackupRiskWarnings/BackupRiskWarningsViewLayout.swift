import UIKit

final class BackupRiskWarningsViewLayout: UIView {
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

    lazy var confirm1Button: CheckboxButton = {
        createConfirmButton()
    }()

    lazy var confirm2Button: CheckboxButton = {
        createConfirmButton()
    }()

    lazy var confirm3Button: CheckboxButton = {
        createConfirmButton()
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

        let warningsStack = UIFactory.default.createVerticalStackView(spacing: UIConstants.hugeOffset)
        warningsStack.alignment = .leading
        addSubview(warningsStack)
        warningsStack.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(UIConstants.hugeOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        warningsStack.addArrangedSubview(confirm1Button)
        warningsStack.addArrangedSubview(confirm2Button)
        warningsStack.addArrangedSubview(confirm3Button)

        [confirm1Button, confirm2Button, confirm3Button].forEach {
            $0.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
            }
        }

        addSubview(continueButton)
        continueButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }

    private func createConfirmButton() -> CheckboxButton {
        let button = CheckboxButton()
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.font = .p1Paragraph
        button.titleLabel?.textColor = R.color.colorWhite()!
        button.contentHorizontalAlignment = .leading
        button.isChecked = false
        return button
    }

    private func applyLocalization() {
        let title = R.string.localizable
            .backupRisksWarningsTitle(preferredLanguages: locale.rLanguages)
        navigationBar.setTitle(title)
        descriptionLabel.text = R.string.localizable
            .backupRisksWarningsDescription(preferredLanguages: locale.rLanguages)
        let confirm1Title = R.string.localizable
            .backupRisksWarnings1(preferredLanguages: locale.rLanguages)
        confirm1Button.setTitle(confirm1Title, for: .normal)
        let confirm2title = R.string.localizable
            .backupRisksWarnings2(preferredLanguages: locale.rLanguages)
        confirm2Button.setTitle(confirm2title, for: .normal)
        let confirm3Title = R.string.localizable
            .backupRisksWarnings3(preferredLanguages: locale.rLanguages)
        confirm3Button.setTitle(confirm3Title, for: .normal)
        continueButton.imageWithTitleView?.title = R.string.localizable
            .backupRisksWarningsContinueButton(preferredLanguages: locale.rLanguages)
    }
}
