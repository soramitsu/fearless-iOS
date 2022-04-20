typealias SelectCurrencyModuleCreationResult = (view: SelectCurrencyViewInput, input: SelectCurrencyModuleInput)

protocol SelectCurrencyViewInput: ControllerBackedProtocol {
    func didRecieve(viewModel: [SelectCurrencyCellViewModel])
}

protocol SelectCurrencyViewOutput: AnyObject {
    func didLoad(view: SelectCurrencyViewInput)
    func didSelect(viewModel: SelectCurrencyCellViewModel)
}

protocol SelectCurrencyInteractorInput: AnyObject {
    func setup(with output: SelectCurrencyInteractorOutput)
    func didSelect(_ currency: Currency)
}

protocol SelectCurrencyInteractorOutput: AnyObject {
    func didRecieve(selectedCurrency: Currency)
}

protocol SelectCurrencyRouterInput: AnyObject {
    func proceed(from view: SelectCurrencyViewInput?)
}

protocol SelectCurrencyModuleInput: AnyObject {}

protocol SelectCurrencyModuleOutput: AnyObject {}
