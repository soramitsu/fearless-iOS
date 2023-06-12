import Foundation
import CommonWallet
import Web3
import SoraFoundation
import SSFModels

typealias StakingPoolCreateModuleCreationResult = (
    view: StakingPoolCreateViewInput,
    input: StakingPoolCreateModuleInput
)

protocol StakingPoolCreateViewInput: ControllerBackedProtocol {
    func didReceiveAssetBalanceViewModel(_ assetBalanceViewModel: AssetBalanceViewModelProtocol)
    func didReceiveAmountInputViewModel(_ amountInputViewModel: IAmountInputViewModel)
    func didReceiveFeeViewModel(_ feeViewModel: BalanceViewModelProtocol?)
    func didReceiveViewModel(_ viewModel: StakingPoolCreateViewModel)
    func didReceive(nameViewModel: InputViewModelProtocol)
}

protocol StakingPoolCreateViewOutput: AnyObject {
    func didLoad(view: StakingPoolCreateViewInput)
    func selectAmountPercentage(_ percentage: Float)
    func updateAmount(_ newValue: Decimal)
    func nominatorDidTapped()
    func bouncerDidTapped()
    func createDidTapped()
    func backDidTapped()
    func nameTextFieldInputValueChanged()
    func rootDidTapped()
}

protocol StakingPoolCreateInteractorInput: AnyObject {
    func setup(with output: StakingPoolCreateInteractorOutput)
    func estimateFee(amount: BigUInt?, poolName: String, poolId: UInt32?)
}

protocol StakingPoolCreateInteractorOutput: AnyObject {
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveMinBond(_ minCreateBond: BigUInt?)
    func didReceivePoolMember(_ poolMember: StakingPoolMember?)
    func didReceiveLastPoolId(_ lastPoolId: UInt32?)
    func didReceive(existentialDepositResult: Result<BigUInt, Error>)
}

protocol StakingPoolCreateRouterInput: StakingErrorPresentable, SheetAlertPresentable, ErrorPresentable {
    func showWalletManagment(
        contextTag: Int,
        from view: ControllerBackedProtocol?,
        moduleOutput: WalletsManagmentModuleOutput?
    )
    func showConfirm(
        from view: ControllerBackedProtocol?,
        with createData: StakingPoolCreateData
    )
}

protocol StakingPoolCreateModuleInput: AnyObject {}

protocol StakingPoolCreateModuleOutput: AnyObject {}
