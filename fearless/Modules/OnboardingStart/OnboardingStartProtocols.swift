typealias OnboardingStartModuleCreationResult = (
    view: OnboardingStartViewInput,
    input: OnboardingStartModuleInput
)

protocol OnboardingStartRouterInput: AnyObject {
    func startOnboarding()
}

protocol OnboardingStartModuleInput: AnyObject {}

protocol OnboardingStartModuleOutput: AnyObject {}
