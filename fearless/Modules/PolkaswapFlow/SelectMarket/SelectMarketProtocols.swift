typealias SelectMarketModuleCreationResult = (view: SelectMarketViewInput, input: SelectMarketModuleInput)

protocol SelectMarketViewInput: SelectionListViewProtocol {}

protocol SelectMarketViewOutput: SelectionListPresenterProtocol {
    func didLoad(view: SelectMarketViewInput)
}

protocol SelectMarketInteractorInput: AnyObject {
    func setup(with output: SelectMarketInteractorOutput)
}

protocol SelectMarketInteractorOutput: AnyObject {}

protocol SelectMarketRouterInput: PresentDismissable, SheetAlertPresentable {}

protocol SelectMarketModuleInput: AnyObject {}

protocol SelectMarketModuleOutput: AnyObject {
    func didSelect(market: LiquiditySourceType)
}
