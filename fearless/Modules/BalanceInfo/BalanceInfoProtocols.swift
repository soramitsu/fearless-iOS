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
    func setup(with output: BalanceInfoInteractorOutput, for type: BalanceInfoType)
    func fetchBalanceInfo(for type: BalanceInfoType)
}

protocol BalanceInfoInteractorOutput: AnyObject {
    func didReceiveWalletBalancesResult(_ result: WalletBalancesResult)
    func didReceiveMinimumBalance(result: Result<BigUInt, Error>)
    func didReceiveBalanceLocks(result: Result<BalanceLocks?, Error>)
}

protocol BalanceInfoRouterInput: AnyObject {
    func presentLockedInfo(
        from view: ControllerBackedProtocol?,
        balanceContext: BalanceContext,
        info: AssetBalanceDisplayInfo,
        currency: Currency
    )
}

protocol BalanceInfoModuleInput: AnyObject {
    func replace(infoType: BalanceInfoType)
}

protocol BalanceInfoModuleOutput: AnyObject {}
