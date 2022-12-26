import Foundation
import CommonWallet

typealias PolkaswapAdjustmentModuleCreationResult = (
    view: PolkaswapAdjustmentViewInput,
    input: PolkaswapAdjustmentModuleInput
)

protocol PolkaswapAdjustmentViewInput: ControllerBackedProtocol {
    func didReceive(market: LiquiditySourceType)
    func didReceiveSwapFrom(viewModel: AssetBalanceViewModelProtocol?)
    func didReceiveSwapTo(viewModel: AssetBalanceViewModelProtocol?)
    func didReceiveSwapFrom(amountInputViewModel: AmountInputViewModelProtocol?)
    func didReceiveSwapTo(amountInputViewModel: AmountInputViewModelProtocol?)
    func didReceiveNetworkFee(fee: BalanceViewModelProtocol?)
    func didUpdating()
    func didReceive(variant: SwapVariant)
    func didReceiveDetails(viewModel: PolkaswapAdjustmentDetailsViewModel?)
}

protocol PolkaswapAdjustmentViewOutput: AnyObject {
    func didLoad(view: PolkaswapAdjustmentViewInput)
    func didTapBackButton()
    func didTapMarketButton()
    func didTapSelectFromAsset()
    func didTapSelectToAsset()
    func didTapSwitchInputsButton()
    func didTapMinReceiveInfo()
    func didTapLiquidityProviderFeeInfo()
    func didTapNetworkFeeInfo()
    func didTapPreviewButton()
    func selectFromAmountPercentage(_ percentage: Float)
    func updateFromAmount(_ newValue: Decimal)
    func selectToAmountPercentage(_ percentage: Float)
    func updateToAmount(_ newValue: Decimal)
}

protocol PolkaswapAdjustmentInteractorInput: AnyObject {
    func setup(with output: PolkaswapAdjustmentInteractorOutput)
    func didReceive(_ fromChainAsset: ChainAsset?, _ toChainAsset: ChainAsset?)
    func fetchQuotes(with params: PolkaswapQuoteParams)
    func subscribeOnPool(
        for fromAssetId: AssetModel.Id,
        toAssetId: AssetModel.Id,
        liquiditySourceType: LiquiditySourceType,
        availablePolkaswapDex: [PolkaswapDex]
    )
    func estimateFee(
        dexId: String,
        fromAssetId: String,
        toAssetId: String,
        swapVariant: SwapVariant,
        swapAmount: SwapAmount,
        filter: FilterMode,
        liquiditySourceType: LiquiditySourceType
    )
}

protocol PolkaswapAdjustmentInteractorOutput: AnyObject {
    func didReceive(error: Error)
    func didReceivePricesData(result: Result<[PriceData], Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveDex(infos: [PolkaswapDexInfo], fromAssetId: String, toAssetId: String)
    func didReceiveSwapValues(_ valuesMap: [SwapValues], params: PolkaswapQuoteParams, errors: [Error])
    func didReceiveSettings(settings: PolkaswapRemoteSettings?)
    func updateQuotes()
}

protocol PolkaswapAdjustmentRouterInput: PresentDismissable, ErrorPresentable, SheetAlertPresentable, BaseErrorPresentable {
    func showSelectMarket(
        from view: ControllerBackedProtocol?,
        markets: [LiquiditySourceType],
        selectedMarket: LiquiditySourceType,
        slippadgeTolerance: Float,
        moduleOutput: PolkaswapTransaktionSettingsModuleOutput
    )
    func showSelectAsset(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainAssets: [ChainAsset]?,
        selectedAssetId: AssetModel.Id?,
        contextTag: Int?,
        output: SelectAssetModuleOutput
    )
    func showConfirmation(
        with params: PolkaswapPreviewParams,
        from view: ControllerBackedProtocol?
    ) -> PolkaswapSwapConfirmationModuleInput?
}

protocol PolkaswapAdjustmentModuleInput: AnyObject {}

protocol PolkaswapAdjustmentModuleOutput: AnyObject {}
