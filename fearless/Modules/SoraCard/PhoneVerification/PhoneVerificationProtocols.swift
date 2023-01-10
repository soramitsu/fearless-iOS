import PayWingsOAuthSDK

typealias PhoneVerificationModuleCreationResult = (view: PhoneVerificationViewInput, input: PhoneVerificationModuleInput)

protocol PhoneVerificationViewInput: ControllerBackedProtocol {
    func didReceive(error: String)
}

protocol PhoneVerificationViewOutput: AnyObject {
    func didLoad(view: PhoneVerificationViewInput)
    func didTapSendButton(with phone: String)
    func didTapBackButton()
    func didTapCloseButton()
}

protocol PhoneVerificationInteractorInput: AnyObject {
    func setup(with output: PhoneVerificationInteractorOutput)
    func requestVerificationCode(phoneNumber: String)
}

protocol PhoneVerificationInteractorOutput: AnyObject {
    func didReceive(oAuthError: PayWingsOAuthSDK.OAuthErrorCode)
    func didProceed(with data: SCKYCUserDataModel, otpLength: Int)
    func didReceive(error: Error)
}

protocol PhoneVerificationRouterInput: PushDismissable {
    func presentVerificationCode(from view: PhoneVerificationViewInput?, data: SCKYCUserDataModel, otpLength: Int)
    func close(from view: PhoneVerificationViewInput?)
}

protocol PhoneVerificationModuleInput: AnyObject {}

protocol PhoneVerificationModuleOutput: AnyObject {}
