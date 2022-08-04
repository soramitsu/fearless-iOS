typealias BalanceInfoModuleCreationResult = (view: BalanceInfoViewInput, input: BalanceInfoModuleInput)

protocol BalanceInfoViewInput: ControllerBackedProtocol {
    func didReceiveViewModel(_ viewModel: BalanceInfoViewModel)
}

protocol BalanceInfoViewOutput: AnyObject {
    func didLoad(view: BalanceInfoViewInput)
}

protocol BalanceInfoInteractorInput: AnyObject {
    func setup(with output: BalanceInfoInteractorOutput)
    func fetchBalance(for type: BalanceInfoType)
}

protocol BalanceInfoInteractorOutput: AnyObject {
    func didReceiveWalletBalancesResult(_ result: WalletBalancesResult)
}

protocol BalanceInfoRouterInput: AnyObject {}

protocol BalanceInfoModuleInput: AnyObject {}

protocol BalanceInfoModuleOutput: AnyObject {}
