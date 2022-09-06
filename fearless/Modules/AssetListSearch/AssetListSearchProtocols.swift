typealias AssetListSearchModuleCreationResult = (view: AssetListSearchViewInput, input: AssetListSearchModuleInput)

protocol AssetListSearchViewInput: ControllerBackedProtocol, HiddableBarWhenPushed {}

protocol AssetListSearchViewOutput: AnyObject {
    func didLoad(view: AssetListSearchViewInput)
    func didTapOnCalcel()
    func searchTextDidChange(_ text: String?)
}

protocol AssetListSearchInteractorInput: AnyObject {
    func setup(with output: AssetListSearchInteractorOutput)
}

protocol AssetListSearchInteractorOutput: AnyObject {}

protocol AssetListSearchRouterInput: PresentDismissable {}

protocol AssetListSearchModuleInput: AnyObject {}

protocol AssetListSearchModuleOutput: AnyObject {}
