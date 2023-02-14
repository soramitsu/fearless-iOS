import UIKit

final class PolkaswapDisclaimerViewLayout: UIView {
    let navigationBar: BaseNavigationBar = {
        let view = BaseNavigationBar()
        view.backgroundColor = R.color.colorBlack19()
        return view
    }()

    private let navigationTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .h4Title
        label.textColor = R.color.colorWhite()
        return label
    }()

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: UIConstants.bigOffset, left: 0.0, bottom: 0.0, right: 0.0)
        view.stackView.alignment = .fill
        view.stackView.distribution = .fill
        return view
    }()

    private let firstParagraphLabel = LinkedLabel()
    private let secondParagraphLabel = UILabel()
    private let thirdParagraphLabel = UILabel()

    private let firstNumberLabel = NumberedLabel(with: 1)
    private let secondNumberLabel = NumberedLabel(with: 2)
    private let thirdNumberLabel = NumberedLabel(with: 3)

    private let fourthParagraphLabel = LinkedLabel()
    private let importantTextLabel = UILabel()
    let confirmSwitch: UISwitch = {
        let view = UISwitch()
        view.onTintColor = R.color.colorPink()
        return view
    }()

    private lazy var labels: [UILabel] = [
        firstParagraphLabel,
        secondParagraphLabel,
        thirdParagraphLabel
    ]

    private lazy var numberedLabels: [UILabel] = [
        firstNumberLabel.numberLabel,
        firstNumberLabel.textLabel,
        secondNumberLabel.numberLabel,
        secondNumberLabel.textLabel,
        thirdNumberLabel.numberLabel,
        thirdNumberLabel.textLabel
    ]

    let continueButton: TriangularedButton = {
        let button = UIFactory.default.createMainActionButton()
        button.contentOpacityWhenDisabled = 0.5
        button.isEnabled = false
        return button
    }()

    private let bottomContainer: UIStackView = {
        UIFactory.default.createVerticalStackView(spacing: UIConstants.bigOffset)
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

    override func layoutSubviews() {
        super.layoutSubviews()
        setupLayout()
    }

    func bind(viewModel: PolkaswapDisclaimerViewModel) {
        firstParagraphLabel.attributedText = viewModel.firstParagraph
        fourthParagraphLabel.attributedText = viewModel.fourthParagraph
        importantTextLabel.attributedText = viewModel.importantParagraph

        firstParagraphLabel.setLinks(viewModel.firstParagraphLinks, delegate: viewModel.delegate)
        fourthParagraphLabel.setLinks(viewModel.fourthParagraphLinks, delegate: viewModel.delegate)
    }

    // MARK: - Private methods

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(contentView)
        addSubview(bottomContainer)

        applyLabelStyle(for: secondParagraphLabel)
        applyLabelStyle(for: thirdParagraphLabel)

        navigationBar.setCenterViews([navigationTitleLabel])
        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(bottomContainer.snp.top).offset(-UIConstants.bigOffset)
            make.width.equalToSuperview().inset(UIConstants.bigOffset)
        }

        contentView.stackView.addArrangedSubview(firstParagraphLabel)
        contentView.stackView.setCustomSpacing(UIConstants.accessoryItemsSpacing, after: firstParagraphLabel)
        contentView.stackView.addArrangedSubview(secondParagraphLabel)
        contentView.stackView.setCustomSpacing(UIConstants.accessoryItemsSpacing, after: secondParagraphLabel)
        contentView.stackView.addArrangedSubview(thirdParagraphLabel)
        contentView.stackView.setCustomSpacing(UIConstants.accessoryItemsSpacing, after: thirdParagraphLabel)

        contentView.stackView.addArrangedSubview(firstNumberLabel)
        contentView.stackView.setCustomSpacing(UIConstants.accessoryItemsSpacing, after: firstNumberLabel)
        contentView.stackView.addArrangedSubview(secondNumberLabel)
        contentView.stackView.setCustomSpacing(UIConstants.accessoryItemsSpacing, after: secondNumberLabel)
        contentView.stackView.addArrangedSubview(thirdNumberLabel)

        contentView.stackView.setCustomSpacing(UIConstants.accessoryItemsSpacing, after: thirdNumberLabel)
        contentView.stackView.addArrangedSubview(createFourthParagraphLabelContainer())

        let switchContainer = createConfirmSwitchContainer()
        bottomContainer.setContentHuggingPriority(.defaultHigh, for: .vertical)
        bottomContainer.addArrangedSubview(switchContainer)
        switchContainer.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.width.equalToSuperview()
        }

        bottomContainer.addArrangedSubview(continueButton)
        continueButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.actionHeight)
        }

        bottomContainer.snp.makeConstraints { make in
            make.top.equalTo(contentView.snp.bottom).offset(UIConstants.bigOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(safeAreaLayoutGuide)
        }

        labels.forEach {
            $0.numberOfLines = 0
            $0.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.width.equalToSuperview()
            }
        }

        numberedLabels.forEach {
            $0.textColor = R.color.colorWhite50()
            $0.font = .p1Paragraph
        }
    }

    private func applyLabelStyle(for label: UILabel) {
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite50()
        label.numberOfLines = 0
    }

    private func createFourthParagraphLabelContainer() -> UIView {
        let container = UIView()

        let pinkSeporatorView = UIView()
        pinkSeporatorView.backgroundColor = R.color.colorPink()

        container.addSubview(pinkSeporatorView)
        pinkSeporatorView.snp.makeConstraints { make in
            make.top.leading.bottom.equalToSuperview()
            make.width.equalTo(1).priority(.high)
        }

        fourthParagraphLabel.numberOfLines = 0
        container.addSubview(fourthParagraphLabel)
        fourthParagraphLabel.snp.makeConstraints { make in
            make.top.trailing.bottom.equalToSuperview()
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
        }

        return container
    }

    private func createConfirmSwitchContainer() -> UIView {
        let container = UIView()
        container.addSubview(importantTextLabel)
        container.addSubview(confirmSwitch)
        container.setContentHuggingPriority(.defaultHigh, for: .vertical)

        importantTextLabel.numberOfLines = 0
        importantTextLabel.snp.makeConstraints { make in
            make.top.leading.bottom.equalToSuperview()
        }

        confirmSwitch.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(importantTextLabel.snp.trailing).offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview()
        }

        return container
    }

    // swiftlint:disable line_length
    private func applyLocalization() {
        navigationTitleLabel.text = R.string.localizable.polkaswapSettingsTitle(preferredLanguages: locale.rLanguages)
        secondParagraphLabel.text = R.string.localizable.polkaswapDisclaimerParagraph2(preferredLanguages: locale.rLanguages)
        thirdParagraphLabel.text = R.string.localizable.polkaswapDisclaimerParagraph3(preferredLanguages: locale.rLanguages)
        firstNumberLabel.textLabel.text = R.string.localizable.polkaswapDisclaimerNumber1(preferredLanguages: locale.rLanguages)
        secondNumberLabel.textLabel.text = R.string.localizable.polkaswapDisclaimerNumber2(preferredLanguages: locale.rLanguages)
        thirdNumberLabel.textLabel.text = R.string.localizable.polkaswapDisclaimerNumber3(preferredLanguages: locale.rLanguages)
        continueButton.imageWithTitleView?.title = R.string.localizable.commonContinue(preferredLanguages: locale.rLanguages)
    }
}
