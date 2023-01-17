import UIKit
import SoraSwiftUI
import SoraUI

final class PhoneVerificationCodeViewLayout: UIView {
    let navigationBar: BaseNavigationBar = {
        let bar = BaseNavigationBar()
        bar.backButton.setImage(R.image.iconBackPinkBold(), for: .normal)
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

    let codeInputField: InputField = {
        let view = InputField()
        view.sora.backgroundColor = .bgPage
        view.textField.sora.textColor = .fgPrimary
        view.sora.keyboardType = .numberPad
        view.sora.state = .default
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

    func set(phone: String) {
        textLabel.sora.text = R.string.localizable
            .verifyPhoneNumberDescription(phone, preferredLanguages: locale.rLanguages)
    }

    func set(timerState: VerificationTimerState) {
        switch timerState {
        case let .inProgress(timeRemaining):
            sendButton.imageWithTitleView?.title = R.string.localizable
                .resendButtonTitle(timeRemaining)
            sendButton.isEnabled = false
        case .finished:
            sendButton.imageWithTitleView?.title = R.string.localizable
                .commonSendCode(preferredLanguages: locale.rLanguages)
            sendButton.isEnabled = true
        }
    }

    func bind(state: SCKYCPhoneCodeState) {
        switch state {
        case .succeed:
            codeInputField.sora.state = .success
            codeInputField.sora.descriptionLabelText = "Succeed"
        case .editing:
            codeInputField.sora.state = .default
            codeInputField.sora.descriptionLabelText = ""
            codeInputField.sora.isUserInteractionEnabled = true
        case .sent:
            sendButton.isEnabled = false
            codeInputField.sora.state = .default
            codeInputField.sora.descriptionLabelText = "Cheking..."
            codeInputField.sora.isUserInteractionEnabled = false
        case let .wrong(error):
            codeInputField.sora.state = .fail
            codeInputField.sora.descriptionLabelText = error
            codeInputField.sora.isUserInteractionEnabled = true
        }
    }

    func resetTextFieldState() {
        switch codeInputField.sora.state {
        case .fail, .success, .default:
            sendButton.isEnabled = true
            codeInputField.sora.state = .disabled
            codeInputField.sora.descriptionLabelText = nil
        default:
            break
        }
    }
}

private extension PhoneVerificationCodeViewLayout {
    func setupLayout() {
        navigationBar.setRightViews([closeButton])

        addSubview(navigationBar)
        addSubview(textLabel)
        addSubview(codeInputField)
        addSubview(sendButton)

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        textLabel.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom).offset(UIConstants.bigOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().offset(-UIConstants.bigOffset)
        }

        codeInputField.snp.makeConstraints { make in
            make.top.equalTo(textLabel.snp.bottom).offset(UIConstants.hugeOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().offset(-UIConstants.bigOffset)
        }

        sendButton.snp.makeConstraints { make in
            make.top.equalTo(codeInputField.snp.bottom).offset(UIConstants.hugeOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().offset(-UIConstants.bigOffset)
            make.height.equalTo(UIConstants.soraCardButtonHeight)
        }
    }

    func applyLocalization() {
        navigationBar.setTitle(
            R.string.localizable.verifyPhoneNumberTitle(preferredLanguages: locale.rLanguages)
        )
        codeInputField.sora.titleLabelText = R.string.localizable
            .verifyPhoneNumberCodeInputFieldLabel(preferredLanguages: locale.rLanguages)
    }
}
