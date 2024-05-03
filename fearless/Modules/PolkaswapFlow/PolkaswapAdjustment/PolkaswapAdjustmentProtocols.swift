import Foundation

import SSFModels

typealias PolkaswapAdjustmentModuleCreationResult = (
    view: PolkaswapAdjustmentViewInput,
    input: PolkaswapAdjustmentModuleInput
)

protocol PolkaswapAdjustmentViewInput: ControllerBackedProtocol {
    func didReceive(market: LiquiditySourceType)
    func didReceiveSwapFrom(viewModel: AssetBalanceViewModelProtocol?)
    func didReceiveSwapTo(viewModel: AssetBalanceViewModelProtocol?)
    func didReceiveSwapFrom(amountInputViewModel: IAmountInputViewModel?)
    func didReceiveSwapTo(amountInputViewModel: IAmountInputViewModel?)
    func didReceiveNetworkFee(fee: BalanceViewModelProtocol?)
    func didUpdating()
    func didReceive(variant: SwapVariant)
    func didReceiveDetails(viewModel: PolkaswapAdjustmentDetailsViewModel?)
    func setButtonLoadingState(isLoading: Bool)
}

protocol PolkaswapAdjustmentViewOutput: AnyObject {
    func didLoad(view: PolkaswapAdjustmentViewInput)
    func didTapBackButton()
    func didTapMarketButton()
    func didTapSelectFromAsset()
    func didTapSelectToAsset()
    func didTapSwitchInputsButton()
    func didTapMinReceiveInfo()
    func didTapNetworkFeeInfo()
    func didTapPreviewButton()
    func selectFromAmountPercentage(_ percentage: Float)
    func updateFromAmount(_ newValue: Decimal)
    func selectToAmountPercentage(_ percentage: Float)
    func updateToAmount(_ newValue: Decimal)
    func viewDidAppear()
}

protocol PolkaswapAdjustmentInteractorInput: AnyObject {
    func setup(with output: PolkaswapAdjustmentInteractorOutput)
    func didReceive(_ fromChainAsset: ChainAsset?, _ toChainAsset: ChainAsset?)
    func fetchQuotes(with params: PolkaswapQuoteParams)
    func subscribeOnBlocks()
    func estimateFee(
        dexId: String,
        fromAssetId: String,
        toAssetId: String,
        swapVariant: SwapVariant,
        swapAmount: SwapAmount,
        filter: PolkaswapLiquidityFilterMode,
        liquiditySourceType: LiquiditySourceType
    )
    func fetchDisclaimerVisible()
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
    func didReceiveDisclaimer(isRead: Bool)
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
        from view: ControllerBackedProtocol?,
        completeClosure: (() -> Void)?
    ) -> PolkaswapSwapConfirmationModuleInput?
    func showDisclaimer(
        moduleOutput: PolkaswapDisclaimerModuleOutput?,
        from view: ControllerBackedProtocol?
    )
}

protocol PolkaswapAdjustmentModuleInput: AnyObject {}

protocol PolkaswapAdjustmentModuleOutput: AnyObject {}
