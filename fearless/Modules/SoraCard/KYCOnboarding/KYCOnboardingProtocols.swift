import PayWingsOAuthSDK
import PayWingsOnboardingKYC

typealias KYCOnboardingModuleCreationResult = (view: KYCOnboardingViewInput, input: KYCOnboardingModuleInput)

protocol KYCOnboardingViewInput: ControllerBackedProtocol {
    func didReceiveStartKycTrigger(with config: KycConfig, result: PayWingsOnboardingKYC.VerificationResult)
}

protocol KYCOnboardingViewOutput: AnyObject {
    func didLoad(view: KYCOnboardingViewInput)
}

protocol KYCOnboardingInteractorInput: AnyObject {
    func setup(with output: KYCOnboardingInteractorOutput)
    func startKYC()
}

protocol KYCOnboardingInteractorOutput: AnyObject {
    func didReceive(oAuthError: PayWingsOAuthSDK.OAuthErrorCode, message: String?)
    func didReceive(config: KycConfig, result: PayWingsOnboardingKYC.VerificationResult)
    func didReceive(error: Error)
    func didReceive(kycError: PayWingsOnboardingKYC.ErrorEvent)
    func didReceive(result: PayWingsOnboardingKYC.SuccessEvent)
}

protocol KYCOnboardingRouterInput: AnyObject, SheetAlertPresentable, PresentDismissable {
    func showStatus(from view: ControllerBackedProtocol?)
}

protocol KYCOnboardingModuleInput: AnyObject {}

protocol KYCOnboardingModuleOutput: AnyObject {}
