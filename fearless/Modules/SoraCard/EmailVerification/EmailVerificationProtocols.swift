typealias EmailVerificationModuleCreationResult = (view: EmailVerificationViewInput, input: EmailVerificationModuleInput)

protocol EmailVerificationViewInput: ControllerBackedProtocol {}

protocol EmailVerificationViewOutput: AnyObject {
    func didLoad(view: EmailVerificationViewInput)
    func didTapSendButton(with email: String)
    func didTapBackButton()
    func didTapCloseButton()
}

protocol EmailVerificationInteractorInput: AnyObject {
    func setup(with output: EmailVerificationInteractorOutput)
}

protocol EmailVerificationInteractorOutput: AnyObject {}

protocol EmailVerificationRouterInput: PushDismissable {
    func presentPreparation(from view: EmailVerificationViewInput?, data: SCKYCUserDataModel)
    func close(from view: EmailVerificationViewInput?)
}

protocol EmailVerificationModuleInput: AnyObject {}

protocol EmailVerificationModuleOutput: AnyObject {}
