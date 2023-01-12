import PayWingsOAuthSDK

typealias EmailVerificationModuleCreationResult = (view: EmailVerificationViewInput, input: EmailVerificationModuleInput)

protocol EmailVerificationViewInput: ControllerBackedProtocol {
    func didReceiveVerifyEmail(_ email: String)
}

protocol EmailVerificationViewOutput: AnyObject {
    func didLoad(view: EmailVerificationViewInput)
    func didTapSendButton(with email: String)
    func didTapBackButton()
    func didTapCloseButton()
}

protocol EmailVerificationInteractorInput: AnyObject {
    func setup(with output: EmailVerificationInteractorOutput)
    func process(email: String)
}

protocol EmailVerificationInteractorOutput: AnyObject {
    func didReceiveSignInSuccessfulStep(data: SCKYCUserDataModel)
    func didReceiveSignInRequired()
    func didReceiveConfirmationRequired(data: SCKYCUserDataModel, autoEmailSent: Bool)
    func didReceiveError(error: PayWingsOAuthSDK.OAuthErrorCode)
}

protocol EmailVerificationRouterInput: PushDismissable {
    func presentPreparation(from view: EmailVerificationViewInput?, data: SCKYCUserDataModel)
    func close(from view: EmailVerificationViewInput?)
}

protocol EmailVerificationModuleInput: AnyObject {}

protocol EmailVerificationModuleOutput: AnyObject {}
