import Foundation
import CommonWallet
import BigInt
import SoraFoundation

typealias StakingPoolCreateModuleCreationResult = (
    view: StakingPoolCreateViewInput,
    input: StakingPoolCreateModuleInput
)

protocol StakingPoolCreateViewInput: ControllerBackedProtocol {
    func didReceiveAssetBalanceViewModel(_ assetBalanceViewModel: AssetBalanceViewModelProtocol)
    func didReceiveAmountInputViewModel(_ amountInputViewModel: AmountInputViewModelProtocol)
    func didReceiveFeeViewModel(_ feeViewModel: BalanceViewModelProtocol?)
    func didReceiveViewModel(_ viewModel: StakingPoolCreateViewModel)
    func didReceive(nameViewModel: InputViewModelProtocol)
}

protocol StakingPoolCreateViewOutput: AnyObject {
    func didLoad(view: StakingPoolCreateViewInput)
    func selectAmountPercentage(_ percentage: Float)
    func updateAmount(_ newValue: Decimal)
    func nominatorDidTapped()
    func stateTogglerDidTapped()
    func createDidTapped()
    func backDidTapped()
}

protocol StakingPoolCreateInteractorInput: AnyObject {
    func setup(with output: StakingPoolCreateInteractorOutput)
    func estimateFee()
}

protocol StakingPoolCreateInteractorOutput: AnyObject {
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveMinBond(_ minCreateBond: BigUInt?)
    func didReceivePoolMember(_ poolMember: StakingPoolMember?)
    func didReceiveLastPoolId(_ lastPoolId: UInt32?)
}

protocol StakingPoolCreateRouterInput: StakingErrorPresentable, AlertPresentable, ErrorPresentable {
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
