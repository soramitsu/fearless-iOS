typealias SCKYCTermsAndConditionsModuleCreationResult = (view: SCKYCTermsAndConditionsViewInput, input: SCKYCTermsAndConditionsModuleInput)

protocol SCKYCTermsAndConditionsViewInput: ControllerBackedProtocol {}

protocol SCKYCTermsAndConditionsViewOutput: AnyObject {
    func didLoad(view: SCKYCTermsAndConditionsViewInput)
    func didTapTermsButton()
    func didTapPrivacyButton()
    func didTapAcceptButton()
    func didTapBackButton()
}

protocol SCKYCTermsAndConditionsInteractorInput: AnyObject {
    func setup(with output: SCKYCTermsAndConditionsInteractorOutput)
}

protocol SCKYCTermsAndConditionsInteractorOutput: AnyObject {}

protocol SCKYCTermsAndConditionsRouterInput: PresentDismissable, WebPresentable {
    func presentPhoneVerification(from view: ControllerBackedProtocol?)
}

protocol SCKYCTermsAndConditionsModuleInput: AnyObject {}

protocol SCKYCTermsAndConditionsModuleOutput: AnyObject {}
