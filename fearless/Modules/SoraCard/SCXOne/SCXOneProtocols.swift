typealias SCXOneModuleCreationResult = (view: SCXOneViewInput, input: SCXOneModuleInput)

protocol SCXOneViewInput: ControllerBackedProtocol {
    func startLoading(with htmlString: String)
}

protocol SCXOneViewOutput: AnyObject {
    func didLoad(view: SCXOneViewInput)
}

protocol SCXOneInteractorInput: AnyObject {
    func setup(with output: SCXOneInteractorOutput)
    func checkStatus(paymentId: String)
}

protocol SCXOneInteractorOutput: AnyObject {}

protocol SCXOneRouterInput: AnyObject {}

protocol SCXOneModuleInput: AnyObject {}

protocol SCXOneModuleOutput: AnyObject {}
