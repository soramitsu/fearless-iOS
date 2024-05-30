typealias OnboardingStartModuleCreationResult = (
    view: OnboardingStartViewInput,
    input: OnboardingStartModuleInput
)

protocol OnboardingStartRouterInput: AnyObject {
    func startOnboarding(config: OnboardingConfigWrapper)
}

protocol OnboardingStartModuleInput: AnyObject {}

protocol OnboardingStartModuleOutput: AnyObject {}
