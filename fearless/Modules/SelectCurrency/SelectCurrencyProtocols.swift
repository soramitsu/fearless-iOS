typealias SelectCurrencyModuleCreationResult = (view: SelectCurrencyViewInput, input: SelectCurrencyModuleInput)

protocol SelectCurrencyViewInput: ControllerBackedProtocol {
    func didRecieve(viewModel: [SelectCurrencyCellViewModel])
}

protocol SelectCurrencyViewOutput: AnyObject {
    func didLoad(view: SelectCurrencyViewInput)
    func didSelect(viewModel: SelectCurrencyCellViewModel)
    func back()
}

protocol SelectCurrencyInteractorInput: AnyObject {
    func setup(with output: SelectCurrencyInteractorOutput)
    func didSelect(_ currency: Currency)
}

protocol SelectCurrencyInteractorOutput: AnyObject {
    func didRecieve(supportedCurrencys: Result<[Currency], Error>)
    func didRecieve(selectedCurrency: Currency)
}

protocol SelectCurrencyRouterInput: ErrorPresentable, AlertPresentable {
    func proceed(from view: SelectCurrencyViewInput?)
    func back(from view: SelectCurrencyViewInput?)
}

protocol SelectCurrencyModuleInput: AnyObject {}

protocol SelectCurrencyModuleOutput: AnyObject {}
