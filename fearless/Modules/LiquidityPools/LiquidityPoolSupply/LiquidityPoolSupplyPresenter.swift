import Foundation
import SoraFoundation
import SSFModels
import SSFPools
import BigInt
import SSFPolkaswap

struct SupplyLiquidityLoadingCollector {
    var feeReady: Bool

    init() {
        feeReady = false
    }

    var isReady: Bool {
        feeReady
    }
}

protocol LiquidityPoolSupplyViewInput: ControllerBackedProtocol {
    func didReceiveSwapFrom(viewModel: AssetBalanceViewModelProtocol?)
    func didReceiveSwapTo(viewModel: AssetBalanceViewModelProtocol?)
    func didReceiveSwapFrom(amountInputViewModel: IAmountInputViewModel?)
    func didReceiveSwapTo(amountInputViewModel: IAmountInputViewModel?)
    func didReceiveNetworkFee(fee: BalanceViewModelProtocol?)
    func setButtonLoadingState(isLoading: Bool)
    func didReceiveViewModel(_ viewModel: LiquidityPoolSupplyViewModel)
    func didReceiveSwapQuoteReady()
}

protocol LiquidityPoolSupplyInteractorInput: AnyObject {
    func setup(with output: LiquidityPoolSupplyInteractorOutput)
    func estimateFee(supplyLiquidityInfo: SupplyLiquidityInfo)
    func fetchPools()
}

final class LiquidityPoolSupplyPresenter {
    private enum InputTag: Int {
        case swapFrom = 0
        case swapTo
    }

    private enum Constants {
        static let slippadgeTolerance: Decimal = 0.5
    }

    // MARK: Private properties

    private weak var view: LiquidityPoolSupplyViewInput?
    private let router: LiquidityPoolSupplyRouterInput
    private let interactor: LiquidityPoolSupplyInteractorInput
    private let dataValidatingFactory: SendDataValidatingFactory
    private let logger: LoggerProtocol
    private let liquidityPair: LiquidityPair
    private let chain: ChainModel
    private let viewModelFactory: LiquidityPoolSupplyViewModelFactory
    private var didSubmitTransactionClosure: (String) -> Void

    private let wallet: MetaAccountModel
    private var swapFromChainAsset: ChainAsset?
    private var swapToChainAsset: ChainAsset?
    private var prices: [PriceData]?
    private var pairs: [LiquidityPair]?

    private var apyInfo: PoolApyInfo?
    private var slippadgeTolerance: Decimal = Constants.slippadgeTolerance
    private var baseAssetInputResult: AmountInputResult?
    private var baseAssetBalance: Decimal?
    private var targetAssetInputResult: AmountInputResult?
    private var targetAssetBalance: Decimal?
    private var reserves: PolkaswapPoolReservesInfo?

    private var networkFeeViewModel: BalanceViewModelProtocol?
    private var networkFee: Decimal?
    private var xorBalance: Decimal?
    private var xorBalanceMinusFee: Decimal {
        (xorBalance ?? 0) - (networkFee ?? 0)
    }

    private var baseTargetRate: Decimal?

    private var dexId: String?
    private var swapVariant: SwapVariant = .desiredInput

    private var loadingCollector = SupplyLiquidityLoadingCollector()

    private var baseAssetResultAmount: Decimal? {
        guard let baseAssetInputResult else {
            return nil
        }

        return baseAssetInputResult.absoluteValue(from: baseAssetBalance.or(.zero))
    }

    private var targetAssetResultAmount: Decimal? {
        guard let targetAssetInputResult else {
            return nil
        }

        return targetAssetInputResult.absoluteValue(from: targetAssetBalance.or(.zero))
    }

    // MARK: - Constructors

    init(
        interactor: LiquidityPoolSupplyInteractorInput,
        router: LiquidityPoolSupplyRouterInput,
        liquidityPair: LiquidityPair,
        localizationManager: LocalizationManagerProtocol,
        chain: ChainModel,
        logger: LoggerProtocol,
        wallet: MetaAccountModel,
        dataValidatingFactory: SendDataValidatingFactory,
        viewModelFactory: LiquidityPoolSupplyViewModelFactory,
        availablePairs: [LiquidityPair]?,
        didSubmitTransactionClosure: @escaping (String) -> Void
    ) {
        self.interactor = interactor
        self.router = router
        self.liquidityPair = liquidityPair
        self.chain = chain
        self.logger = logger
        self.wallet = wallet
        self.dataValidatingFactory = dataValidatingFactory
        self.viewModelFactory = viewModelFactory
        pairs = availablePairs
        dexId = liquidityPair.dexId
        self.didSubmitTransactionClosure = didSubmitTransactionClosure

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let viewModel = viewModelFactory.buildViewModel(
            slippage: slippadgeTolerance,
            apy: apyInfo,
            liquidityPair: liquidityPair,
            chain: chain
        )
        DispatchQueue.main.async { [weak self] in
            self?.view?.didReceiveViewModel(viewModel)
        }
    }

    private func refreshFee() {
        guard
            let dexId,
            let baseAsset = chain.assets.first(where: { $0.currencyId == liquidityPair.baseAssetId }),
            let targetAsset = chain.assets.first(where: { $0.currencyId == liquidityPair.targetAssetId })
        else {
            return
        }

        let baseAssetInfo = PooledAssetInfo(id: liquidityPair.baseAssetId, precision: Int16(baseAsset.precision))
        let targetAssetInfo = PooledAssetInfo(id: liquidityPair.targetAssetId, precision: Int16(targetAsset.precision))

        let baseAssetAmount = baseAssetInputResult?.absoluteValue(from: baseAssetBalance ?? .zero) ?? .zero
        let targetAssetAmount = targetAssetInputResult?.absoluteValue(from: targetAssetBalance ?? .zero) ?? .zero
        let supplyLiquidityInfo = SupplyLiquidityInfo(
            dexId: dexId,
            baseAsset: baseAssetInfo,
            targetAsset: targetAssetInfo,
            baseAssetAmount: baseAssetAmount,
            targetAssetAmount: targetAssetAmount,
            slippage: slippadgeTolerance,
            availablePairs: pairs
        )

        interactor.estimateFee(supplyLiquidityInfo: supplyLiquidityInfo)
    }

    private func checkLoadingState() {
        DispatchQueue.main.async { [weak self] in
            self?.view?.setButtonLoadingState(isLoading: self?.loadingCollector.isReady == false)
        }
    }

    private func runLoadingState() {
        DispatchQueue.main.async { [weak self] in
            self?.view?.setButtonLoadingState(isLoading: true)
        }
    }

    private func resetLoadingState() {
        DispatchQueue.main.async { [weak self] in
            self?.view?.setButtonLoadingState(isLoading: false)
        }
    }

    private func provideFromAssetVewModel(updateAmountInput: Bool = true) {
        let balanceViewModelFactory = buildBalanceSwapToViewModelFactory(
            wallet: wallet,
            for: swapFromChainAsset
        )

        let swapFromPrice = prices?.first(where: { priceData in
            swapFromChainAsset?.asset.priceId == priceData.priceId
        })

        let viewModel = balanceViewModelFactory?.createAssetBalanceViewModel(
            baseAssetResultAmount,
            balance: baseAssetBalance,
            priceData: swapFromPrice
        ).value(for: selectedLocale)

        let inputViewModel = balanceViewModelFactory?
            .createBalanceInputViewModel(baseAssetResultAmount)
            .value(for: selectedLocale)

        DispatchQueue.main.async { [weak self] in
            self?.view?.didReceiveSwapFrom(viewModel: viewModel)

            if updateAmountInput {
                self?.view?.didReceiveSwapFrom(amountInputViewModel: inputViewModel)
            }
        }
    }

    private func provideToAssetVewModel(updateAmountInput: Bool = true) {
        let balanceViewModelFactory = buildBalanceSwapToViewModelFactory(
            wallet: wallet,
            for: swapToChainAsset
        )

        let swapToPrice = prices?.first(where: { priceData in
            swapToChainAsset?.asset.priceId == priceData.priceId
        })

        let viewModel = balanceViewModelFactory?.createAssetBalanceViewModel(
            targetAssetResultAmount,
            balance: targetAssetBalance,
            priceData: swapToPrice
        ).value(for: selectedLocale)

        let inputViewModel = balanceViewModelFactory?
            .createBalanceInputViewModel(targetAssetResultAmount)
            .value(for: selectedLocale)

        DispatchQueue.main.async { [weak self] in
            self?.view?.didReceiveSwapTo(viewModel: viewModel)

            if updateAmountInput {
                self?.view?.didReceiveSwapTo(amountInputViewModel: inputViewModel)
            }
        }
    }

    private func provideFeeViewModel() {
        guard let swapFromFee = networkFee, let xorChainAsset = chain.utilityChainAssets().first else {
            return
        }
        let balanceViewModelFactory = createBalanceViewModelFactory(for: xorChainAsset)
        let feeViewModel = balanceViewModelFactory.balanceFromPrice(
            swapFromFee,
            priceData: prices?.first(where: { price in
                price.priceId == xorChainAsset.asset.priceId
            }),
            isApproximately: true,
            usageCase: .detailsCrypto
        ).value(for: selectedLocale)

        DispatchQueue.main.async {
            self.view?.didReceiveNetworkFee(fee: feeViewModel)
        }

        networkFeeViewModel = feeViewModel
    }

    private func buildBalanceSwapToViewModelFactory(
        wallet: MetaAccountModel,
        for chainAsset: ChainAsset?
    ) -> BalanceViewModelFactoryProtocol? {
        guard let chainAsset = chainAsset else {
            return nil
        }
        let assetInfo = chainAsset.asset
            .displayInfo(with: chainAsset.chain.icon)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            selectedMetaAccount: wallet,
            chainAsset: chainAsset
        )
        return balanceViewModelFactory
    }

    private func createBalanceViewModelFactory(for chainAsset: ChainAsset) -> BalanceViewModelFactory {
        let assetInfo = chainAsset.asset.displayInfo(with: chainAsset.chain.icon)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            selectedMetaAccount: wallet,
            chainAsset: chainAsset
        )
        return balanceViewModelFactory
    }

    private func provideInitialData() {
        swapFromChainAsset = chain.chainAssets.first(where: { $0.asset.currencyId == liquidityPair.baseAssetId })
        swapToChainAsset = chain.chainAssets.first(where: { $0.asset.currencyId == liquidityPair.targetAssetId })

        if pairs == nil {
            interactor.fetchPools()
        }

        DispatchQueue.main.async {
            self.view?.didReceiveNetworkFee(fee: nil)
        }

        provideViewModel()
        provideToAssetVewModel()
        provideFromAssetVewModel()
        refreshFee()
    }

    private func recalculateTargetAssetAmount(baseAssetAmount: Decimal?) {
        guard
            let baseAssetAmount,
            let baseAsset = swapFromChainAsset,
            let targetAsset = swapToChainAsset,
            let baseAssetPooled = (reserves?.reserves.reserves),
            let targetAssetPooled = reserves?.reserves.fee,
            let baseAssetPooledDecimal = Decimal.fromSubstrateAmount(baseAssetPooled, precision: Int16(baseAsset.asset.precision)),
            let targetAssetPooledDecimal = Decimal.fromSubstrateAmount(targetAssetPooled, precision: Int16(targetAsset.asset.precision)),
            baseAssetPooledDecimal > 0
        else {
            return
        }

        let scale = targetAssetPooledDecimal / baseAssetPooledDecimal

        targetAssetInputResult = .absolute(baseAssetAmount * scale)
    }

    private func recalculateBaseAssetAmount(targetAssetAmount: Decimal?) {
        guard
            let targetAssetAmount,
            let baseAsset = swapFromChainAsset,
            let targetAsset = swapToChainAsset,
            let baseAssetPooled = (reserves?.reserves.reserves),
            let targetAssetPooled = reserves?.reserves.fee,
            let baseAssetPooledDecimal = Decimal.fromSubstrateAmount(baseAssetPooled, precision: Int16(baseAsset.asset.precision)),
            let targetAssetPooledDecimal = Decimal.fromSubstrateAmount(targetAssetPooled, precision: Int16(targetAsset.asset.precision)),
            targetAssetPooledDecimal > 0
        else {
            return
        }

        let scale = baseAssetPooledDecimal / targetAssetPooledDecimal

        baseAssetInputResult = .absolute(targetAssetAmount * scale)
    }

    private func handleBaseAssetAmountChanged(updateAmountInput: Bool) {
        let baseAssetAbsolulteValue = baseAssetInputResult?.absoluteValue(from: baseAssetBalance.or(.zero))
        recalculateTargetAssetAmount(baseAssetAmount: baseAssetAbsolulteValue)

        provideFromAssetVewModel(updateAmountInput: updateAmountInput)
        provideToAssetVewModel()

        refreshFee()
    }

    private func handleTargetAssetAmountChanged(updateAmountInput: Bool) {
        let targetAssetAbsoluteValue = targetAssetInputResult?.absoluteValue(from: targetAssetBalance.or(.zero))
        recalculateBaseAssetAmount(targetAssetAmount: targetAssetAbsoluteValue)

        provideFromAssetVewModel()
        provideToAssetVewModel(updateAmountInput: updateAmountInput)

        refreshFee()
    }
}

// MARK: - LiquidityPoolSupplyViewOutput

extension LiquidityPoolSupplyPresenter: LiquidityPoolSupplyViewOutput {
    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapApyInfo() {
        router.presentInfo(
            message: R.string.localizable.lpApyAlertText(preferredLanguages: selectedLocale.rLanguages),
            title: R.string.localizable.lpApyAlertTitle(preferredLanguages: selectedLocale.rLanguages),
            from: view
        )
    }

    func didTapFeeInfo() {
        router.presentInfo(
            message: R.string.localizable.lpNetworkFeeAlertText(preferredLanguages: selectedLocale.rLanguages),
            title: R.string.localizable.lpNetworkFeeAlertTitle(preferredLanguages: selectedLocale.rLanguages),
            from: view
        )
    }

    func didTapPreviewButton() {
        let baseAssetFee = swapFromChainAsset?.isUtility == true ? networkFee : .zero
        let targetAssetFee = swapToChainAsset?.isUtility == true ? networkFee : .zero

        let validators = [
            dataValidatingFactory.has(
                fee: networkFee,
                locale: selectedLocale,
                onError: { [weak self] in
                    self?.refreshFee()
                }
            ),
            dataValidatingFactory.canPayFeeAndAmount(
                balanceType: .utility(balance: baseAssetBalance),
                feeAndTip: baseAssetFee,
                sendAmount: baseAssetResultAmount,
                locale: selectedLocale
            ),
            dataValidatingFactory.canPayFeeAndAmount(
                balanceType: .utility(balance: targetAssetBalance),
                feeAndTip: targetAssetFee,
                sendAmount: targetAssetResultAmount,
                locale: selectedLocale
            )
        ]

        DataValidationRunner(validators: validators).runValidation { [weak self] in
            guard
                let self,
                let baseAssetResultAmount = self.baseAssetResultAmount,
                let targetAssetResultAmount = self.targetAssetResultAmount
            else {
                return
            }

            let inputData = LiquidityPoolSupplyConfirmInputData(
                baseAssetAmount: baseAssetResultAmount,
                targetAssetAmount: targetAssetResultAmount,
                slippageTolerance: slippadgeTolerance,
                availablePools: pairs
            )

            self.router.showConfirmation(
                chain: self.chain,
                wallet: self.wallet,
                liquidityPair: self.liquidityPair,
                inputData: inputData,
                didSubmitTransactionClosure: didSubmitTransactionClosure,
                from: self.view
            )
        }
    }

    func selectFromAmountPercentage(_ percentage: Float) {
        swapVariant = .desiredInput
        baseAssetInputResult = .rate(Decimal(Double(percentage)))
        handleBaseAssetAmountChanged(updateAmountInput: true)
    }

    func updateFromAmount(_ newValue: Decimal) {
        swapVariant = .desiredInput
        baseAssetInputResult = .absolute(newValue)
        handleBaseAssetAmountChanged(updateAmountInput: false)
    }

    func selectToAmountPercentage(_ percentage: Float) {
        swapVariant = .desiredOutput
        targetAssetInputResult = .rate(Decimal(Double(percentage)))
        handleTargetAssetAmountChanged(updateAmountInput: true)
    }

    func updateToAmount(_ newValue: Decimal) {
        swapVariant = .desiredOutput
        targetAssetInputResult = .absolute(newValue)
        handleTargetAssetAmountChanged(updateAmountInput: false)
    }

    func didLoad(view: LiquidityPoolSupplyViewInput) {
        self.view = view
        interactor.setup(with: self)
    }

    func handleViewAppeared() {
        checkLoadingState()
        provideInitialData()
    }
}

// MARK: - LiquidityPoolSupplyInteractorOutput

extension LiquidityPoolSupplyPresenter: LiquidityPoolSupplyInteractorOutput {
    func didReceivePoolReserves(reserves: PolkaswapPoolReservesInfo?) {
        self.reserves = reserves

        switch swapVariant {
        case .desiredInput:
            let baseAssetAbsolulteValue = baseAssetInputResult?.absoluteValue(from: baseAssetBalance.or(.zero))
            recalculateTargetAssetAmount(baseAssetAmount: baseAssetAbsolulteValue)
        case .desiredOutput:
            let targetAssetAbsoluteValue = targetAssetInputResult?.absoluteValue(from: targetAssetBalance.or(.zero))
            recalculateBaseAssetAmount(targetAssetAmount: targetAssetAbsoluteValue)
        }

        DispatchQueue.main.async { [weak self] in
            self?.view?.didReceiveSwapQuoteReady()
        }
    }

    func didReceivePoolReservesError(error: Error) {
        logger.customError(error)
    }

    func didReceiveLiquidityPairs(pairs: [LiquidityPair]?) {
        self.pairs = pairs
    }

    func didReceiveLiquidityPairsError(error: Error) {
        logger.customError(error)
    }

    func didReceivePoolAPY(apyInfo: SSFPolkaswap.PoolApyInfo?) {
        self.apyInfo = apyInfo
        provideViewModel()
    }

    func didReceivePoolApyError(error: Error) {
        logger.customError(error)
    }

    func didReceiveFee(_ fee: BigUInt) {
        guard let utilityAsset = chain.utilityAssets().first else {
            return
        }

        networkFee = Decimal.fromSubstrateAmount(fee, precision: Int16(utilityAsset.precision))
        provideFeeViewModel()

        loadingCollector.feeReady = true
        checkLoadingState()
    }

    func didReceiveFeeError(_ error: Error) {
        logger.customError(error)
    }

    func didReceivePricesData(result: Result<[PriceData], Error>) {
        switch result {
        case let .success(priceData):
            prices = priceData
        case let .failure(error):
            prices = []
            logger.error("\(error)")
        }

        provideFromAssetVewModel()
        provideToAssetVewModel()
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset) {
        switch result {
        case let .success(accountInfo):
            if swapFromChainAsset == chainAsset {
                baseAssetBalance = accountInfo.map {
                    Decimal.fromSubstrateAmount(
                        $0.data.sendAvailable,
                        precision: Int16(chainAsset.asset.precision)
                    )
                } ?? .zero
                provideFromAssetVewModel()
            }
            if swapToChainAsset == chainAsset {
                targetAssetBalance = accountInfo.map {
                    Decimal.fromSubstrateAmount(
                        $0.data.sendAvailable,
                        precision: Int16(chainAsset.asset.precision)
                    )
                } ?? .zero
                provideToAssetVewModel()
            }
            if chain.utilityChainAssets().first == chainAsset {
                xorBalance = accountInfo.map {
                    Decimal.fromSubstrateAmount(
                        $0.data.sendAvailable,
                        precision: Int16(chainAsset.asset.precision)
                    )
                } ?? .zero
            }
        case let .failure(error):
            logger.customError(error)
        }
    }
}

// MARK: - Localizable

extension LiquidityPoolSupplyPresenter: Localizable {
    func applyLocalization() {}
}

extension LiquidityPoolSupplyPresenter: LiquidityPoolSupplyModuleInput {}
