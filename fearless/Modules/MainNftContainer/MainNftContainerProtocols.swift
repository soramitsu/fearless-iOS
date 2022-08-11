typealias MainNftContainerModuleCreationResult = (view: MainNftContainerViewInput, input: MainNftContainerModuleInput)

protocol MainNftContainerViewInput: ControllerBackedProtocol {}

protocol MainNftContainerViewOutput: AnyObject {
    func didLoad(view: MainNftContainerViewInput)
}

protocol MainNftContainerInteractorInput: AnyObject {
    func setup(with output: MainNftContainerInteractorOutput)
}

protocol MainNftContainerInteractorOutput: AnyObject {}

protocol MainNftContainerRouterInput: AnyObject {}

protocol MainNftContainerModuleInput: AnyObject {}

protocol MainNftContainerModuleOutput: AnyObject {}
