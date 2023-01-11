import SoraSwiftUI
import SoraUI

final class EmailVerificationViewLayout: UIView {
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

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    private let enterEmailLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        label.sora.alignment = .center
        return label
    }()

    let emailInputField: InputField = {
        let view = InputField()
        view.sora.backgroundColor = .bgPage
        view.textField.sora.textColor = .fgPrimary
        view.textField.sora.backgroundColor = .bgSurface
        view.sora.state = .default
        return view
    }()

    private let verifyEmailLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        label.sora.alignment = .center
        return label
    }()

    let sendButton: RoundedButton = {
        let button = RoundedButton()
        button.applySoraSecondaryStyle()
        return button
    }()

    let changeEmailButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .clear
        button.tintColor = R.color.accentSecondary()
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

    func set(state: EmailVerificationState) {
        switch state {
        case .enter:
            sendButton.imageWithTitleView?.title = R.string.localizable
                .commonSendLink(preferredLanguages: locale.rLanguages)
            sendButton.isEnabled = true
            enterEmailLabel.isHidden = false
            emailInputField.isHidden = false
            verifyEmailLabel.isHidden = true
            changeEmailButton.isHidden = true
        case let .verify(email):
            verifyEmailLabel.sora.text = R.string.localizable
                .verifyEmailDescription(email, preferredLanguages: locale.rLanguages)
            enterEmailLabel.isHidden = true
            emailInputField.isHidden = true
            verifyEmailLabel.isHidden = false
            changeEmailButton.isHidden = false
        }
    }

    func set(timerState: VerificationTimerState) {
        switch timerState {
        case let .inProgress(timeRemaining):
            sendButton.imageWithTitleView?.title = R.string.localizable
                .resendButtonTitle(timeRemaining)
            sendButton.isEnabled = false
        case .finished:
            sendButton.imageWithTitleView?.title = R.string.localizable
                .commonSendLink(preferredLanguages: locale.rLanguages)
            sendButton.isEnabled = true
        }
    }
}

private extension EmailVerificationViewLayout {
    func setupLayout() {
        navigationBar.setRightViews([closeButton])

        addSubview(navigationBar)
        addSubview(containerView)
        containerView.addSubview(enterEmailLabel)
        containerView.addSubview(emailInputField)
        containerView.addSubview(verifyEmailLabel)
        addSubview(sendButton)
        addSubview(changeEmailButton)

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        containerView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom).offset(UIConstants.bigOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().offset(-UIConstants.bigOffset)
        }

        enterEmailLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }

        emailInputField.snp.makeConstraints { make in
            make.top.equalTo(enterEmailLabel.snp.bottom).offset(UIConstants.hugeOffset)
            make.leading.trailing.bottom.equalToSuperview()
        }

        verifyEmailLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        sendButton.snp.makeConstraints { make in
            make.top.equalTo(containerView.snp.bottom).offset(UIConstants.hugeOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().offset(-UIConstants.bigOffset)
        }

        changeEmailButton.snp.makeConstraints { make in
            make.top.equalTo(sendButton.snp.bottom).offset(UIConstants.bigOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().offset(-UIConstants.bigOffset)
        }
    }

    func applyLocalization() {
        enterEmailLabel.sora.text = R.string.localizable
            .enterEmailDescription(preferredLanguages: locale.rLanguages)
        emailInputField.sora.titleLabelText = R.string.localizable
            .enterEmailInputFieldLabel(preferredLanguages: locale.rLanguages)
        emailInputField.sora.descriptionLabelText = R.string.localizable
            .enterEmailDescription(preferredLanguages: locale.rLanguages)
        changeEmailButton.titleLabel?.text = R.string.localizable
            .commonChangeEmail(preferredLanguages: locale.rLanguages)
    }
}
