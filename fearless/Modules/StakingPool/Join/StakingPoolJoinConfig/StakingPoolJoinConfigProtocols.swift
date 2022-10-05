import CommonWallet
import BigInt

typealias StakingPoolJoinConfigModuleCreationResult = (
    view: StakingPoolJoinConfigViewInput,
    input: StakingPoolJoinConfigModuleInput
)

protocol StakingPoolJoinConfigViewInput: ControllerBackedProtocol {
    func didReceiveAccountViewModel(_ accountViewModel: AccountViewModel)
    func didReceiveAssetBalanceViewModel(_ assetBalanceViewModel: AssetBalanceViewModelProtocol)
    func didReceiveAmountInputViewModel(_ amountInputViewModel: AmountInputViewModelProtocol)
    func didReceive(locale: Locale)
    func didReceiveFeeViewModel(_ feeViewModel: BalanceViewModelProtocol?)
}

protocol StakingPoolJoinConfigViewOutput: AnyObject {
    func didLoad(view: StakingPoolJoinConfigViewInput)
    func selectAmountPercentage(_ percentage: Float)
    func updateAmount(_ newValue: Decimal)
    func didTapBackButton()
    func didTapContinueButton()
}

protocol StakingPoolJoinConfigInteractorInput: AnyObject {
    func setup(with output: StakingPoolJoinConfigInteractorOutput)
    func estimateFee()
}

protocol StakingPoolJoinConfigInteractorOutput: AnyObject {
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveMinBond(_ minJoinBond: BigUInt?)
    func didReceive(existentialDepositResult: Result<BigUInt, Error>)
}

protocol StakingPoolJoinConfigRouterInput: AnyObject, PushDismissable, StakingErrorPresentable, AlertPresentable, ErrorPresentable {
    func presentPoolsList(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        inputAmount: Decimal
    )
}

protocol StakingPoolJoinConfigModuleInput: AnyObject {}

protocol StakingPoolJoinConfigModuleOutput: AnyObject {}
