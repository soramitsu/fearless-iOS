import UIKit

final class ControllerAccountViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

    let stashAccountView = UIFactory.default.createAccountView()

    let controllerAccountView = UIFactory.default.createAccountView()

    let hintView = UIFactory.default.createHintView()

    let learnMoreView = UIFactory.default.createLearnMoreView()

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
        containerView.stackView.addArrangedSubview(stashAccountView)
        stashAccountView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(52.0)
        }

        containerView.stackView.addArrangedSubview(controllerAccountView)
        controllerAccountView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(52.0)
        }

        containerView.stackView.addArrangedSubview(hintView)
        hintView.snp.makeConstraints { make in
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
    }

    private func applyLocalization() {
        actionButton.imageWithTitleView?.title = R.string.localizable
            .commonContinue(preferredLanguages: locale.rLanguages)
        learnMoreView.titleLabel.text = R.string.localizable
            .commonLearnMore(preferredLanguages: locale.rLanguages)
        hintView.titleLabel.text = R.string.localizable
            .stakingCurrentAccountIsController(preferredLanguages: locale.rLanguages)
    }
}
