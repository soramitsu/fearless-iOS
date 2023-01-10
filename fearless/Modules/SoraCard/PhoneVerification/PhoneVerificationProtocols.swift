typealias PhoneVerificationModuleCreationResult = (view: PhoneVerificationViewInput, input: PhoneVerificationModuleInput)

protocol PhoneVerificationViewInput: ControllerBackedProtocol {}

protocol PhoneVerificationViewOutput: AnyObject {
    func didLoad(view: PhoneVerificationViewInput)
    func didTapSendButton(with phone: String)
    func didTapBackButton()
    func didTapCloseButton()
}

protocol PhoneVerificationInteractorInput: AnyObject {
    func setup(with output: PhoneVerificationInteractorOutput)
}

protocol PhoneVerificationInteractorOutput: AnyObject {}

protocol PhoneVerificationRouterInput: PushDismissable {
    func presentVerificationCode(from view: PhoneVerificationViewInput?, phone: String)
    func close(from view: PhoneVerificationViewInput?)
}

protocol PhoneVerificationModuleInput: AnyObject {}

protocol PhoneVerificationModuleOutput: AnyObject {}
