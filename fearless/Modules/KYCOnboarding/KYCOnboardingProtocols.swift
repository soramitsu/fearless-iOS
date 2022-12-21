typealias KYCOnboardingModuleCreationResult = (view: KYCOnboardingViewInput, input: KYCOnboardingModuleInput)

protocol KYCOnboardingViewInput: ControllerBackedProtocol {}

protocol KYCOnboardingViewOutput: AnyObject {
    func didLoad(view: KYCOnboardingViewInput)
}

protocol KYCOnboardingInteractorInput: AnyObject {
    func setup(with output: KYCOnboardingInteractorOutput)
}

protocol KYCOnboardingInteractorOutput: AnyObject {}

protocol KYCOnboardingRouterInput: AnyObject {}

protocol KYCOnboardingModuleInput: AnyObject {}

protocol KYCOnboardingModuleOutput: AnyObject {}
