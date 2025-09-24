import Foundation
import BigInt
import SSFModels

typealias SendModuleCreationResult = (view: SendViewInput, input: SendModuleInput)

protocol SendViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(assetBalanceViewModel: AssetBalanceViewModelProtocol?)
    func didReceive(amountInputViewModel: IAmountInputViewModel?)
    func didReceive(selectNetworkViewModel: SelectNetworkViewModel)
    func didReceive(feeViewModel: BalanceViewModelProtocol?)
    func didReceive(tipViewModel: TipViewModel?)
    func didReceive(scamInfo: ScamInfo?)
    func didStartFeeCalculation()
    func didStopFeeCalculation()
    func didStopTipCalculation()
    func didReceive(viewModel: RecipientViewModel)
    func didReceive(accountScoreViewModel: AccountScoreViewModel?)
    func didBlockUserInteractive(isUserInteractiveAmount: Bool)
    func setInputAccessoryView(visible: Bool)
    func setHistoryButton(isVisible: Bool)
    func switchEnableSendAllState(enabled: Bool)
    func switchEnableSendAllVisibility(isVisible: Bool)
}

protocol SendViewOutput: AnyObject {
    func didLoad(view: SendViewInput)
    func didTapBackButton()
    func didTapContinueButton()
    func didTapScanButton()
    func didTapHistoryButton()
    func didTapPasteButton()
    func didTapSelectAsset()
    func didTapSelectNetwork()
    func searchTextDidChanged(_ text: String)
    func selectAmountPercentage(_ percentage: Float, validate: Bool)
    func updateAmount(_ newValue: Decimal)
    func didSwitchSendAll(_ enabled: Bool)
}

protocol SendInteractorInput: AnyObject {
    var dependencyContainer: SendDepencyContainer { get }

    func setup(with output: SendInteractorOutput)
    func updateSubscriptions(for chainAsset: ChainAsset)
    func defineAvailableChains(
        for asset: AssetModel,
        wallet: MetaAccountModel,
        completionBlock: @escaping ([ChainModel]?) -> Void
    )
    func estimateFee(for amount: BigUInt, tip: BigUInt?, for address: String?, chainAsset: ChainAsset)
    func validate(address: String?, for chain: ChainModel) -> AddressValidationResult
    func fetchScamInfo(for address: String, chain: ChainModel)
    func getFeePaymentChainAsset(for chainAsset: ChainAsset?) -> ChainAsset?
    func getPossibleChains(for address: String) async -> [ChainModel]?
    func calculateEquilibriumBalance(chainAsset: ChainAsset, amount: Decimal)
    func didReceive(xorlessTransfer: XorlessTransfer)
    func convert(chainAsset: ChainAsset, toChainAsset: ChainAsset, amount: BigUInt) async throws -> SwapValues?
    func provideConstants(for chainAsset: ChainAsset)
}

protocol SendInteractorOutput: AnyObject {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset)
    func didReceiveMinimumBalance(result: Result<BigUInt, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveTip(result: Result<BigUInt, Error>)
    func didReceive(scamInfo: ScamInfo?)
    func didReceive(possibleChains: [ChainModel]?)
    func didReceive(eqTotalBalance: Decimal)
    func didReceiveDependencies(for chainAsset: ChainAsset)
    func didReceiveAssetAccountInfo(assetAccountInfo: AssetAccountInfo?)
    func didReceiveAssetAccountInfoError(error: Error)
}

protocol SendRouterInput: SheetAlertPresentable, ErrorPresentable, BaseErrorPresentable, PresentDismissable {
    func presentConfirm(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        call: SendConfirmTransferCall,
        scamInfo: ScamInfo?,
        feeViewModel: BalanceViewModelProtocol?
    )
    func presentScan(
        from view: ControllerBackedProtocol?,
        moduleOutput: ScanQRModuleOutput
    )

    func presentHistory(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        moduleOutput: ContactsModuleOutput
    )

    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        selectedChainId: ChainModel.Id?,
        chainModels: [ChainModel]?,
        delegate: SelectNetworkDelegate?
    )

    func showSelectAsset(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        selectedAssetId: AssetModel.Id?,
        chainAssets: [ChainAsset]?,
        output: SelectAssetModuleOutput
    )
    func showManageAsset(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel
    )
}

protocol SendModuleInput: AnyObject {}

protocol SendModuleOutput: AnyObject {}
