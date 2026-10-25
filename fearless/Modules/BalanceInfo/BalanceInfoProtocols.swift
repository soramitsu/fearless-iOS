import BigInt
import SSFModels

typealias BalanceInfoModuleCreationResult = (view: BalanceInfoViewInput, input: BalanceInfoModuleInput)

protocol BalanceInfoViewInput: ControllerBackedProtocol {
    func didReceiveViewModel(_ viewModel: BalanceInfoViewModel?)
}

protocol BalanceInfoViewOutput: AnyObject {
    func didLoad(view: BalanceInfoViewInput)
}

protocol BalanceInfoInteractorInput: AnyObject {
    var balanceInfoType: BalanceInfoType { get set }

    func setup(with output: BalanceInfoInteractorOutput)
    func fetchBalanceInfo()
}

protocol BalanceInfoInteractorOutput: AnyObject {
    func didReceiveWalletBalancesResult(_ result: WalletBalancesResult)
    func didReceiveMinimumBalance(result: Result<BigUInt, Error>)
    func didReceiveBalanceLocks(result: Result<BalanceLocks?, Error>)
}

protocol BalanceInfoRouterInput: AnyObject {}

protocol BalanceInfoModuleInput: AnyObject {
    func replace(infoType: BalanceInfoType)
}

protocol BalanceInfoModuleOutput: AnyObject {}
