typealias PolkaswapDisclaimerModuleCreationResult = (
    view: PolkaswapDisclaimerViewInput,
    input: PolkaswapDisclaimerModuleInput
)

protocol PolkaswapDisclaimerRouterInput: PresentDismissable, WebPresentable {}

protocol PolkaswapDisclaimerModuleInput: AnyObject {}

protocol PolkaswapDisclaimerModuleOutput: AnyObject {
    func disclaimerDidRead()
}
