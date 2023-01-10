import SoraSwiftUI
import SoraUI

final class PhoneVerificationViewLayout: UIView {
    let navigationBar: BaseNavigationBar = {
        let bar = BaseNavigationBar()
        bar.set(.push)
        bar.tintColor = R.color.colorPink1()
        bar.backgroundColor = R.color.colorBlack()
        return bar
    }()

    let closeButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconClose(), for: .normal)
        return button
    }()

    private let textLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        label.sora.alignment = .center
        return label
    }()

    let phoneInputField: InputField = {
        let view = InputField()
        view.sora.backgroundColor = .fgPrimary
//        view.stackView.sora.backgroundColor = .bgSurface
        view.textField.sora.textColor = .fgPrimary
        view.sora.keyboardType = .phonePad
        view.sora.textContentType = .telephoneNumber
        return view
    }()

    let sendButton: RoundedButton = {
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

    func set(state: VerificationState) {
        switch state {
        case .enabled:
            sendButton.isEnabled = true
            phoneInputField.sora.state = .success
        case let .disabled(errorMessage):
            sendButton.isEnabled = false
            phoneInputField.sora.state = .fail
            phoneInputField.sora.descriptionLabelText = errorMessage
        }
    }
}

private extension PhoneVerificationViewLayout {
    func setupLayout() {
        navigationBar.setRightViews([closeButton])

        addSubview(navigationBar)
        addSubview(textLabel)
        addSubview(phoneInputField)
        addSubview(sendButton)

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        textLabel.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom).offset(UIConstants.bigOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().offset(-UIConstants.bigOffset)
        }

        phoneInputField.snp.makeConstraints { make in
            make.top.equalTo(textLabel.snp.bottom).offset(UIConstants.hugeOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().offset(-UIConstants.bigOffset)
        }

        sendButton.snp.makeConstraints { make in
            make.top.equalTo(phoneInputField.snp.bottom).offset(UIConstants.hugeOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().offset(-UIConstants.bigOffset)
            make.height.equalTo(UIConstants.soraCardButtonHeight)
        }
    }

    func applyLocalization() {
        navigationBar.setTitle(
            R.string.localizable.verifyPhoneNumberTitle(preferredLanguages: locale.rLanguages)
        )
        textLabel.sora.text = R.string.localizable.enterPhoneNumberDescription(preferredLanguages: locale.rLanguages)
        phoneInputField.sora.titleLabelText = R.string.localizable
            .enterPhoneNumberPhoneInputFieldLabel(preferredLanguages: locale.rLanguages)
        phoneInputField.sora.descriptionLabelText = R.string.localizable.commonNoSpam(preferredLanguages: locale.rLanguages)
        sendButton.imageWithTitleView?.title = R.string.localizable
            .commonSendCode(preferredLanguages: locale.rLanguages).uppercased()
    }
}
