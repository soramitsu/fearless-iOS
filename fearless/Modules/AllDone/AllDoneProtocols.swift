typealias AllDoneModuleCreationResult = (view: AllDoneViewInput, input: AllDoneModuleInput)

protocol AllDoneViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: AllDoneViewModel)
}

protocol AllDoneViewOutput: AnyObject {
    func didLoad(view: AllDoneViewInput)
    func dismiss()
    func didCopyTapped()
}

protocol AllDoneInteractorInput: AnyObject {
    func setup(with output: AllDoneInteractorOutput)
}

protocol AllDoneInteractorOutput: AnyObject {}

protocol AllDoneRouterInput: PresentDismissable, ApplicationStatusPresentable {}

protocol AllDoneModuleInput: AnyObject {}

protocol AllDoneModuleOutput: AnyObject {}
