typealias TermsAndConditionsModuleCreationResult = (view: TermsAndConditionsViewInput, input: TermsAndConditionsModuleInput)

protocol TermsAndConditionsViewInput: ControllerBackedProtocol {}

protocol TermsAndConditionsViewOutput: AnyObject {
    func didLoad(view: TermsAndConditionsViewInput)
    func didTapTermsButton()
    func didTapPrivacyButton()
    func didTapAcceptButton()
    func didTapBackButton()
}

protocol TermsAndConditionsInteractorInput: AnyObject {
    func setup(with output: TermsAndConditionsInteractorOutput)
}

protocol TermsAndConditionsInteractorOutput: AnyObject {}

protocol TermsAndConditionsRouterInput: PresentDismissable, WebPresentable {
    func presentPhoneVerification(from view: TermsAndConditionsViewInput?)
}

protocol TermsAndConditionsModuleInput: AnyObject {}

protocol TermsAndConditionsModuleOutput: AnyObject {}
