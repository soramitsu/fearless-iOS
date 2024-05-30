typealias OnboardingModuleCreationResult = (
    view: OnboardingViewInput,
    input: OnboardingModuleInput
)

protocol OnboardingRouterInput: AnyObject {
    func showMain()
    func showLocalAuthentication()
    func showLogin()
    func showPincodeSetup()
}

protocol OnboardingModuleInput: AnyObject {}

protocol OnboardingModuleOutput: AnyObject {}
