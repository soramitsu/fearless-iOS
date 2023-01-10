import SoraSwiftUI
import SoraUI

final class IntroduceViewLayout: UIView {
    let navigationBar: BaseNavigationBar = {
        let bar = BaseNavigationBar()
        bar.set(.push)
        bar.backgroundColor = R.color.colorBlack()
        return bar
    }()

    let closeButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconClose(), for: .normal)
        return button
    }()

    let nameInputField: InputField = {
        let view = InputField()
        view.sora.backgroundColor = .bgPage
        view.textField.sora.textColor = .fgPrimary
        view.sora.keyboardType = .alphabet
        view.sora.textContentType = .name
        view.sora.state = .default
        return view
    }()

    let lastNameInputField: InputField = {
        let view = InputField()
        view.sora.backgroundColor = .bgPage
        view.textField.sora.textColor = .fgPrimary
        view.sora.keyboardType = .alphabet
        view.sora.textContentType = .familyName
        view.sora.state = .default
        return view
    }()

    let continueButton: RoundedButton = {
        let button = RoundedButton()
        button.applySoraSecondaryStyle()
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
        backgroundColor = R.color.bgPage()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension IntroduceViewLayout {
    func setupLayout() {
        navigationBar.setRightViews([closeButton])

        addSubview(navigationBar)
        addSubview(nameInputField)
        addSubview(lastNameInputField)
        addSubview(continueButton)

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        nameInputField.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom).offset(UIConstants.hugeOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().offset(-UIConstants.bigOffset)
        }

        lastNameInputField.snp.makeConstraints { make in
            make.top.equalTo(nameInputField.snp.bottom).offset(UIConstants.bigOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().offset(-UIConstants.bigOffset)
        }

        continueButton.snp.makeConstraints { make in
            make.top.equalTo(lastNameInputField.snp.bottom).offset(UIConstants.hugeOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().offset(-UIConstants.bigOffset)
            make.height.equalTo(UIConstants.soraCardButtonHeight)
        }
    }

    func applyLocalization() {
        navigationBar.setTitle(R.string.localizable
            .userRegistrationTitle(preferredLanguages: locale.rLanguages))
        nameInputField.sora.titleLabelText = R.string.localizable
            .userRegistrationLastNameInputFiledLabel(preferredLanguages: locale.rLanguages)
        lastNameInputField.sora.titleLabelText = R.string.localizable
            .userRegistrationLastNameInputFiledLabel(preferredLanguages: locale.rLanguages)
        continueButton.imageWithTitleView?.title = R.string.localizable
            .commonContinue(preferredLanguages: locale.rLanguages)
    }
}
