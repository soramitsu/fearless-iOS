typealias PreparationModuleCreationResult = (view: PreparationViewInput, input: PreparationModuleInput)

protocol PreparationViewInput: ControllerBackedProtocol {}

protocol PreparationViewOutput: AnyObject {
    func didLoad(view: PreparationViewInput)
    func didTapConfirmButton()
    func didTapBackButton()
}

protocol PreparationInteractorInput: AnyObject {
    func setup(with output: PreparationInteractorOutput)
}

protocol PreparationInteractorOutput: AnyObject {}

protocol PreparationRouterInput: PushDismissable {}

protocol PreparationModuleInput: AnyObject {}

protocol PreparationModuleOutput: AnyObject {}
