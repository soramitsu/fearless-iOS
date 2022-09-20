typealias SelectNetworkModuleCreationResult = (view: SelectNetworkViewInput, input: SelectNetworkModuleInput)

protocol SelectNetworkViewInput: SelectionListViewProtocol {}

protocol SelectNetworkViewOutput: SelectionListPresenterProtocol {
    func didLoad(view: SelectNetworkViewInput)
}

protocol SelectNetworkInteractorInput: AnyObject {
    func setup(with output: SelectNetworkInteractorOutput)
}

protocol SelectNetworkInteractorOutput: AnyObject {
    func didReceiveChains(result: Result<[ChainModel], Error>)
}

protocol SelectNetworkRouterInput: AlertPresentable, ErrorPresentable {
    func complete(on view: SelectNetworkViewInput, selecting chain: ChainModel?)
}

protocol SelectNetworkModuleInput: AnyObject {}

protocol SelectNetworkModuleOutput: AnyObject {}
