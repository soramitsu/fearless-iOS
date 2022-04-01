typealias SelectExportAccountModuleCreationResult = (view: SelectExportAccountViewInput, input: SelectExportAccountModuleInput)

protocol SelectExportAccountViewInput: ControllerBackedProtocol {}

protocol SelectExportAccountViewOutput: AnyObject {
    func didLoad(view: SelectExportAccountViewInput)
}

protocol SelectExportAccountInteractorInput: AnyObject {
    func setup(with output: SelectExportAccountInteractorOutput)
}

protocol SelectExportAccountInteractorOutput: AnyObject {}

protocol SelectExportAccountRouterInput: AnyObject {}

protocol SelectExportAccountModuleInput: AnyObject {}

protocol SelectExportAccountModuleOutput: AnyObject {}
