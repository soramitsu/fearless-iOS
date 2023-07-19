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

    let warning1Label: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()!
        label.numberOfLines = 0
        return label
    }()

    let warning2Label: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()!
        label.numberOfLines = 0
        return label
    }()

    let warning3Label: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()!
        label.numberOfLines = 0
        return label
    }()

    let continueButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
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
        addSubview(warningsStack)
        warningsStack.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(UIConstants.hugeOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        warningsStack.addArrangedSubview(createWarningView(with: warning1Label))
        warningsStack.addArrangedSubview(createWarningView(with: warning2Label))
        warningsStack.addArrangedSubview(createWarningView(with: warning3Label))

        addSubview(continueButton)
        continueButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset)
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

    private func applyLocalization() {
        let title = R.string.localizable
            .backupRisksWarningsTitle(preferredLanguages: locale.rLanguages)
        navigationBar.setTitle(title)
        descriptionLabel.text = R.string.localizable
            .backupRisksWarningsDescription(preferredLanguages: locale.rLanguages)
        warning1Label.text = R.string.localizable
            .backupRisksWarnings1(preferredLanguages: locale.rLanguages)
        warning2Label.text = R.string.localizable
            .backupRisksWarnings2(preferredLanguages: locale.rLanguages)
        warning3Label.text = R.string.localizable
            .backupRisksWarnings3(preferredLanguages: locale.rLanguages)
        continueButton.imageWithTitleView?.title = R.string.localizable
            .backupRisksWarningsContinueButton(preferredLanguages: locale.rLanguages)
    }
}
