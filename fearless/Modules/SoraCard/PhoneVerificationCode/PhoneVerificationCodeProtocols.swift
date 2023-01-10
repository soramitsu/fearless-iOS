typealias PhoneVerificationCodeModuleCreationResult = (view: PhoneVerificationCodeViewInput, input: PhoneVerificationCodeModuleInput)

protocol PhoneVerificationCodeViewInput: ControllerBackedProtocol {
    func set(phone: String)
}

protocol PhoneVerificationCodeViewOutput: AnyObject {
    func didLoad(view: PhoneVerificationCodeViewInput)
    func send(code: String)
    func didTapSendButton()
    func didTapBackButton()
    func didTapCloseButton()
}

protocol PhoneVerificationCodeInteractorInput: AnyObject {
    func setup(with output: PhoneVerificationCodeInteractorOutput)
}

protocol PhoneVerificationCodeInteractorOutput: AnyObject {}

protocol PhoneVerificationCodeRouterInput: PushDismissable {
    func presentIntroduce(from view: PhoneVerificationCodeViewInput?, phone: String)
    func close(from view: PhoneVerificationCodeViewInput?)
}

protocol PhoneVerificationCodeModuleInput: AnyObject {}

protocol PhoneVerificationCodeModuleOutput: AnyObject {}
