import CommonWallet
import BigInt

typealias SendModuleCreationResult = (view: SendViewInput, input: SendModuleInput)

protocol SendViewInput: ControllerBackedProtocol {
    func didReceive(assetBalanceViewModel: AssetBalanceViewModelProtocol?)
    func didReceive(amountInputViewModel: AmountInputViewModelProtocol?)
    func didReceive(selectNetworkViewModel: SelectNetworkViewModel)
    func didReceive(feeViewModel: BalanceViewModelProtocol?)
    func didReceive(tipViewModel: TipViewModel?)
    func didReceive(scamInfo: ScamInfo?)
    func didStartFeeCalculation()
    func didStopFeeCalculation()
    func didStopTipCalculation()
    func didReceive(viewModel: RecipientViewModel)
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
    func selectAmountPercentage(_ percentage: Float)
    func updateAmount(_ newValue: Decimal)
}

protocol SendInteractorInput: AnyObject {
    var dependencyContainer: SendDepencyContainer { get }

    func setup(with output: SendInteractorOutput)
    func updateSubscriptions(for chainAsset: ChainAsset)
    func defineAvailableChains(
        for asset: AssetModel,
        completionBlock: @escaping ([ChainModel]?) -> Void
    )
    func estimateFee(for amount: BigUInt, tip: BigUInt?, for address: String?, chainAsset: ChainAsset)
    func validate(address: String?, for chain: ChainModel) -> AddressValidationResult
    func fetchScamInfo(for address: String)
    func getUtilityAsset(for chainAsset: ChainAsset?) -> ChainAsset?
    func getPossibleChains(for address: String, completion: ([ChainModel]?) -> Void)
}

protocol SendInteractorOutput: AnyObject {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset)
    func didReceiveMinimumBalance(result: Result<BigUInt, Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>, for priceId: AssetModel.PriceId?)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveTip(result: Result<BigUInt, Error>)
    func didReceive(scamInfo: ScamInfo?)
    func didReceive(possibleChains: [ChainModel]?)
    func didReceive(eqTotalBalance: BigUInt)
}

protocol SendRouterInput: SheetAlertPresentable, ErrorPresentable, BaseErrorPresentable, PresentDismissable {
    func presentConfirm(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        receiverAddress: String,
        amount: Decimal,
        tip: Decimal?,
        scamInfo: ScamInfo?
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
        from view: SendViewInput?,
        wallet: MetaAccountModel,
        selectedChainId: ChainModel.Id?,
        chainModels: [ChainModel]?,
        delegate: SelectNetworkDelegate?
    )

    func showSelectAsset(
        from view: SendViewInput?,
        wallet: MetaAccountModel,
        selectedAssetId: AssetModel.Id?,
        chainAssets: [ChainAsset]?,
        output: SelectAssetModuleOutput
    )
}

protocol SendModuleInput: AnyObject {}

protocol SendModuleOutput: AnyObject {}
