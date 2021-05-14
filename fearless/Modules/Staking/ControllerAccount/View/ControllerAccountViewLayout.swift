import UIKit

final class ControllerAccountViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 0
        return label
    }()

    let stashAccountView = UIFactory.default.createAccountView()

    let stashHintView = UIFactory.default.createHintView()

    let controllerAccountView = UIFactory.default.createAccountView()

    let controllerHintView = UIFactory.default.createHintView()

    let learnMoreView = UIFactory.default.createLearnMoreView()

    let currentAccountIsControllerHint: HintView = {
        let hintView = HintView()
        hintView.iconView.image = R.image.iconWarning()
        return hintView
    }()

    let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // swiftlint:disable function_body_length
    private func setupLayout() {
        let separator = UIView.createSeparator(color: R.color.colorDarkGray())
        addSubview(separator)
        separator.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.separatorHeight)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.equalTo(separator.snp.bottom)
            make.leading.bottom.trailing.equalToSuperview()
        }

        containerView.stackView.spacing = 16
        containerView.stackView.addArrangedSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        containerView.stackView.addArrangedSubview(stashAccountView)
        stashAccountView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(52.0)
        }

        containerView.stackView.setCustomSpacing(8, after: stashAccountView)
        containerView.stackView.addArrangedSubview(stashHintView)
        stashHintView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        containerView.stackView.addArrangedSubview(controllerAccountView)
        controllerAccountView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(52.0)
        }

        containerView.stackView.setCustomSpacing(8, after: controllerAccountView)
        containerView.stackView.addArrangedSubview(controllerHintView)
        controllerHintView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        containerView.stackView.addArrangedSubview(learnMoreView)
        learnMoreView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        let bottomSeparator = UIView.createSeparator(color: R.color.colorDarkGray())
        containerView.stackView.addArrangedSubview(bottomSeparator)
        containerView.stackView.setCustomSpacing(0, after: learnMoreView)
        bottomSeparator.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.separatorHeight)
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(currentAccountIsControllerHint)
        currentAccountIsControllerHint.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(actionButton.snp.top).offset(-UIConstants.horizontalInset)
        }
    }

    private func applyLocalization() {
        descriptionLabel.text = "Set a separate account as a controller to increase staking management security."
        stashHintView.titleLabel.text = "Stash can bond more and set the controller."
        controllerHintView.titleLabel.text = "Controller can unbond, redeem, rebond, change reward destination and validators."
        learnMoreView.titleLabel.text = R.string.localizable
            .commonLearnMore(preferredLanguages: locale.rLanguages)
        currentAccountIsControllerHint.titleLabel.text = "Switch your account to stash to set the controller."
        actionButton.imageWithTitleView?.title = R.string.localizable
            .commonContinue(preferredLanguages: locale.rLanguages)
    }
}
