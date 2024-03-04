typealias OnboardingModuleCreationResult = (
    view: OnboardingViewInput,
    input: OnboardingModuleInput
)

protocol OnboardingRouterInput: AnyObject {
    func showMain() async
    func showLocalAuthentication() async
    func showLogin() async
    func showPincodeSetup() async
}

protocol OnboardingModuleInput: AnyObject {}

protocol OnboardingModuleOutput: AnyObject {}
