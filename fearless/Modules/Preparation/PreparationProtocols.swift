typealias PreparationModuleCreationResult = (view: PreparationViewInput, input: PreparationModuleInput)

protocol PreparationViewInput: ControllerBackedProtocol {}

protocol PreparationViewOutput: AnyObject {
    func didLoad(view: PreparationViewInput)
}

protocol PreparationInteractorInput: AnyObject {
    func setup(with output: PreparationInteractorOutput)
}

protocol PreparationInteractorOutput: AnyObject {}

protocol PreparationRouterInput: AnyObject {}

protocol PreparationModuleInput: AnyObject {}

protocol PreparationModuleOutput: AnyObject {}
