typealias AllDoneModuleCreationResult = (view: AllDoneViewInput, input: AllDoneModuleInput)

protocol AllDoneViewInput: ControllerBackedProtocol {
    func didReceive(hashString: String)
}

protocol AllDoneViewOutput: AnyObject {
    func didLoad(view: AllDoneViewInput)
}

protocol AllDoneInteractorInput: AnyObject {
    func setup(with output: AllDoneInteractorOutput)
}

protocol AllDoneInteractorOutput: AnyObject {}

protocol AllDoneRouterInput: AnyObject {}

protocol AllDoneModuleInput: AnyObject {}

protocol AllDoneModuleOutput: AnyObject {}
