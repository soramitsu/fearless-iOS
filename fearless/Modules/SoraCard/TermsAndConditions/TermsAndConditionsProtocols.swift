typealias TermsAndConditionsModuleCreationResult = (view: TermsAndConditionsViewInput, input: TermsAndConditionsModuleInput)

protocol TermsAndConditionsViewInput: ControllerBackedProtocol {}

protocol TermsAndConditionsViewOutput: AnyObject {
    func didLoad(view: TermsAndConditionsViewInput)
}

protocol TermsAndConditionsInteractorInput: AnyObject {
    func setup(with output: TermsAndConditionsInteractorOutput)
}

protocol TermsAndConditionsInteractorOutput: AnyObject {}

protocol TermsAndConditionsRouterInput: AnyObject {}

protocol TermsAndConditionsModuleInput: AnyObject {}

protocol TermsAndConditionsModuleOutput: AnyObject {}
