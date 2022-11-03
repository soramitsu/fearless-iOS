typealias AllDoneModuleCreationResult = (view: AllDoneViewInput, input: AllDoneModuleInput)

protocol AllDoneViewInput: ControllerBackedProtocol {
    func didReceive(hashString: String)
}

protocol AllDoneViewOutput: AnyObject {
    func didLoad(view: AllDoneViewInput)
    func dismiss()
}

protocol AllDoneInteractorInput: AnyObject {
    func setup(with output: AllDoneInteractorOutput)
}

protocol AllDoneInteractorOutput: AnyObject {}

protocol AllDoneRouterInput: PresentDismissable {}

protocol AllDoneModuleInput: AnyObject {}

protocol AllDoneModuleOutput: AnyObject {}
