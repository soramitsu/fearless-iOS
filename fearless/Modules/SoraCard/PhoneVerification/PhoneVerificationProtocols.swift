typealias PhoneVerificationModuleCreationResult = (view: PhoneVerificationViewInput, input: PhoneVerificationModuleInput)

protocol PhoneVerificationViewInput: ControllerBackedProtocol {}

protocol PhoneVerificationViewOutput: AnyObject {
    func didLoad(view: PhoneVerificationViewInput)
}

protocol PhoneVerificationInteractorInput: AnyObject {
    func setup(with output: PhoneVerificationInteractorOutput)
}

protocol PhoneVerificationInteractorOutput: AnyObject {}

protocol PhoneVerificationRouterInput: AnyObject {}

protocol PhoneVerificationModuleInput: AnyObject {}

protocol PhoneVerificationModuleOutput: AnyObject {}
