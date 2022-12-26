typealias EmailVerificationModuleCreationResult = (view: EmailVerificationViewInput, input: EmailVerificationModuleInput)

protocol EmailVerificationViewInput: ControllerBackedProtocol {}

protocol EmailVerificationViewOutput: AnyObject {
    func didLoad(view: EmailVerificationViewInput)
}

protocol EmailVerificationInteractorInput: AnyObject {
    func setup(with output: EmailVerificationInteractorOutput)
}

protocol EmailVerificationInteractorOutput: AnyObject {}

protocol EmailVerificationRouterInput: AnyObject {}

protocol EmailVerificationModuleInput: AnyObject {}

protocol EmailVerificationModuleOutput: AnyObject {}
