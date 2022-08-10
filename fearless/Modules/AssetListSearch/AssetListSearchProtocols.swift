typealias AssetListSearchModuleCreationResult = (view: AssetListSearchViewInput, input: AssetListSearchModuleInput)

protocol AssetListSearchViewInput: ControllerBackedProtocol {}

protocol AssetListSearchViewOutput: AnyObject {
    func didLoad(view: AssetListSearchViewInput)
}

protocol AssetListSearchInteractorInput: AnyObject {
    func setup(with output: AssetListSearchInteractorOutput)
}

protocol AssetListSearchInteractorOutput: AnyObject {}

protocol AssetListSearchRouterInput: AnyObject {}

protocol AssetListSearchModuleInput: AnyObject {}

protocol AssetListSearchModuleOutput: AnyObject {}
