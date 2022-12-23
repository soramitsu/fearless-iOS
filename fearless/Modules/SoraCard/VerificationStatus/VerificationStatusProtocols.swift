typealias VerificationStatusModuleCreationResult = (view: VerificationStatusViewInput, input: VerificationStatusModuleInput)

protocol VerificationStatusViewInput: ControllerBackedProtocol {}

protocol VerificationStatusViewOutput: AnyObject {
    func didLoad(view: VerificationStatusViewInput)
}

protocol VerificationStatusInteractorInput: AnyObject {
    func setup(with output: VerificationStatusInteractorOutput)
}

protocol VerificationStatusInteractorOutput: AnyObject {}

protocol VerificationStatusRouterInput: AnyObject {}

protocol VerificationStatusModuleInput: AnyObject {}

protocol VerificationStatusModuleOutput: AnyObject {}
