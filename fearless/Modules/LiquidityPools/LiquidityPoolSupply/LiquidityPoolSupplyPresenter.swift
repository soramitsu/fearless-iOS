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
    func didUpdating()
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
        static let slippadgeTolerance: Float = 0.5
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
    private var slippadgeTolerance: Float = Constants.slippadgeTolerance
    private var baseAssetInputResult: AmountInputResult?
    private var baseAssetBalance: Decimal?
    private var targetAssetInputResult: AmountInputResult?
    private var targetAssetBalance: Decimal?

    private var networkFeeViewModel: BalanceViewModelProtocol?
    private var networkFee: Decimal?
    private var xorBalance: Decimal?
    private var xorBalanceMinusFee: Decimal {
        (xorBalance ?? 0) - (networkFee ?? 0)
    }

    private var baseTargetRate: Decimal?

    private var dexId: String?

    private var loadingCollector = SupplyLiquidityLoadingCollector()

    private var baseAssetResultAmount: Decimal {
        guard let baseAssetInputResult else {
            return .zero
        }

        return baseAssetInputResult.absoluteValue(from: baseAssetBalance.or(.zero))
    }

    private var targetAssetResultAmount: Decimal {
        guard let targetAssetInputResult else {
            return .zero
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
            slippage: Decimal(floatLiteral: Double(slippadgeTolerance)),
            apy: apyInfo,
            liquidityPair: liquidityPair,
            chain: chain
        )

        view?.didReceiveViewModel(viewModel)
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
            slippage: Decimal(floatLiteral: Double(slippadgeTolerance)),
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
            selectedMetaAccount: wallet
        )
        return balanceViewModelFactory
    }

    private func createBalanceViewModelFactory(for chainAsset: ChainAsset) -> BalanceViewModelFactory {
        let assetInfo = chainAsset.asset.displayInfo(with: chainAsset.chain.icon)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            selectedMetaAccount: wallet
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
            self.provideViewModel()
        }

        provideToAssetVewModel()
        provideFromAssetVewModel()
        refreshFee()
    }
}

// MARK: - LiquidityPoolSupplyViewOutput

extension LiquidityPoolSupplyPresenter: LiquidityPoolSupplyViewOutput {
    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapApyInfo() {
        var infoText: String
        var infoTitle: String
        infoTitle = R.string.localizable.lpApyAlertTitle(preferredLanguages: selectedLocale.rLanguages)
        infoText = R.string.localizable.lpApyAlertText(preferredLanguages: selectedLocale.rLanguages)
        router.presentInfo(
            message: infoText,
            title: infoTitle,
            from: view
        )
    }

    func didTapFeeInfo() {
        var infoText: String
        var infoTitle: String
        infoTitle = R.string.localizable.lpNetworkFeeAlertTitle(preferredLanguages: selectedLocale.rLanguages)
        infoText = R.string.localizable.lpNetworkFeeAlertText(preferredLanguages: selectedLocale.rLanguages)
        router.presentInfo(
            message: infoText,
            title: infoTitle,
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
            guard let self else {
                return
            }

            let inputData = LiquidityPoolSupplyConfirmInputData(
                baseAssetAmount: self.baseAssetResultAmount,
                targetAssetAmount: self.targetAssetResultAmount,
                slippageTolerance: Decimal(floatLiteral: Double(self.slippadgeTolerance)),
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
        baseAssetInputResult = .rate(Decimal(Double(percentage)))

        let baseAssetAbsolulteValue = baseAssetInputResult?.absoluteValue(from: baseAssetBalance.or(.zero))
        let targetAssetAbsoluteValue = baseAssetAbsolulteValue.or(.zero) * baseTargetRate.or(.zero)
        targetAssetInputResult = .absolute(targetAssetAbsoluteValue)

        provideFromAssetVewModel()
        provideToAssetVewModel()

        refreshFee()
    }

    func updateFromAmount(_ newValue: Decimal) {
        baseAssetInputResult = .absolute(newValue)

        let baseAssetAbsolulteValue = baseAssetInputResult?.absoluteValue(from: baseAssetBalance.or(.zero))
        let targetAssetAbsoluteValue = baseAssetAbsolulteValue.or(.zero) * baseTargetRate.or(.zero)
        targetAssetInputResult = .absolute(targetAssetAbsoluteValue)

        provideFromAssetVewModel(updateAmountInput: false)
        provideToAssetVewModel()

        refreshFee()
    }

    func selectToAmountPercentage(_ percentage: Float) {
        targetAssetInputResult = .rate(Decimal(Double(percentage)))

        let targetAssetAbsoluteValue = targetAssetInputResult?.absoluteValue(from: targetAssetBalance.or(.zero))
        let baseAssetAbsolulteValue = targetAssetAbsoluteValue.or(.zero) / baseTargetRate.or(1)
        baseAssetInputResult = .absolute(baseAssetAbsolulteValue)

        provideFromAssetVewModel()
        provideToAssetVewModel()

        refreshFee()
    }

    func updateToAmount(_ newValue: Decimal) {
        targetAssetInputResult = .absolute(newValue)

        let targetAssetAbsoluteValue = targetAssetInputResult?.absoluteValue(from: targetAssetBalance.or(.zero))
        let baseAssetAbsolulteValue = targetAssetAbsoluteValue.or(.zero) / baseTargetRate.or(1)
        baseAssetInputResult = .absolute(baseAssetAbsolulteValue)

        provideFromAssetVewModel()
        provideToAssetVewModel(updateAmountInput: false)

        refreshFee()
    }

    func didTapSelectFromAsset() {
        let showChainAssets = chain.chainAssets
            .filter { $0.chainAssetId != swapToChainAsset?.chainAssetId }
        router.showSelectAsset(
            from: view,
            wallet: wallet,
            chainAssets: showChainAssets,
            selectedAssetId: swapFromChainAsset?.asset.id,
            contextTag: InputTag.swapFrom.rawValue,
            output: self
        )
    }

    func didTapSelectToAsset() {
        let showChainAssets = chain.chainAssets
            .filter { $0.chainAssetId != swapFromChainAsset?.chainAssetId }
        router.showSelectAsset(
            from: view,
            wallet: wallet,
            chainAssets: showChainAssets,
            selectedAssetId: swapToChainAsset?.asset.id,
            contextTag: InputTag.swapTo.rawValue,
            output: self
        )
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

            let baseAssetPrice = prices?.first(where: { $0.priceId == swapFromChainAsset?.asset.priceId })
            let targetAssetPrice = prices?.first(where: { $0.priceId == swapToChainAsset?.asset.priceId })

            if
                let baseAssetPrice = baseAssetPrice,
                let targetAssetPrice = targetAssetPrice,
                let baseAssetPriceValue = Decimal(string: baseAssetPrice.price),
                let targetAssetPriceValue = Decimal(string: targetAssetPrice.price) {
                baseTargetRate = baseAssetPriceValue / targetAssetPriceValue

                DispatchQueue.main.async { [weak self] in
                    self?.view?.didReceiveSwapQuoteReady()
                }
            }
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
            router.present(error: error, from: view, locale: selectedLocale)
        }
    }
}

// MARK: - Localizable

extension LiquidityPoolSupplyPresenter: Localizable {
    func applyLocalization() {}
}

extension LiquidityPoolSupplyPresenter: LiquidityPoolSupplyModuleInput {}

// MARK: - SelectAssetModuleOutput

extension LiquidityPoolSupplyPresenter: SelectAssetModuleOutput {
    func assetSelection(
        didCompleteWith chainAsset: ChainAsset?,
        contextTag: Int?
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.view?.didUpdating()
        }

        guard let rawValue = contextTag,
              let input = InputTag(rawValue: rawValue),
              let chainAsset = chainAsset
        else {
            return
        }

        switch input {
        case .swapFrom:
            swapFromChainAsset = chainAsset
            provideFromAssetVewModel()
        case .swapTo:
            swapToChainAsset = chainAsset
            provideToAssetVewModel()
        }

        runLoadingState()

        refreshFee()
    }
}
