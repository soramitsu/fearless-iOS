import Foundation
import SoraFoundation
import SSFPools
import BigInt
import SSFModels
import SSFPolkaswap

struct RemoveLiquidityLoadingCollector {
    var totalIssuanceReady: Bool
    var reservesReady: Bool
    var feeReady: Bool

    init() {
        totalIssuanceReady = false
        reservesReady = false
        feeReady = false
    }

    var isReady: Bool {
        totalIssuanceReady && reservesReady && feeReady
    }
}

protocol LiquidityPoolRemoveLiquidityConfirmViewInput: ControllerBackedProtocol {
    func didReceiveNetworkFee(fee: BalanceViewModelProtocol?)
    func setButtonLoadingState(isLoading: Bool)
    func didReceiveConfirmViewModel(_ viewModel: LiquidityPoolSupplyConfirmViewModel?)
}

protocol LiquidityPoolRemoveLiquidityViewInput: ControllerBackedProtocol {
    func didReceiveXorBalanceViewModel(balanceViewModel: BalanceViewModelProtocol?)
    func didReceiveSwapFrom(viewModel: AssetBalanceViewModelProtocol?)
    func didReceiveSwapTo(viewModel: AssetBalanceViewModelProtocol?)
    func didReceiveSwapFrom(amountInputViewModel: IAmountInputViewModel?)
    func didReceiveSwapTo(amountInputViewModel: IAmountInputViewModel?)
    func didReceiveSwapQuoteReady()
    func didReceiveNetworkFee(fee: BalanceViewModelProtocol?)
    func setButtonLoadingState(isLoading: Bool)
}

protocol LiquidityPoolRemoveLiquidityInteractorInput: AnyObject {
    func setup(with output: LiquidityPoolRemoveLiquidityInteractorOutput)
    func estimateFee(removeLiquidityInfo: RemoveLiquidityInfo)
    func submit(removeLiquidityInfo: RemoveLiquidityInfo)
}

final class LiquidityPoolRemoveLiquidityPresenter {
    // MARK: Private properties

    private weak var confirmView: LiquidityPoolRemoveLiquidityConfirmViewInput?
    private weak var setupView: LiquidityPoolRemoveLiquidityViewInput?

    private let router: LiquidityPoolRemoveLiquidityRouterInput
    private let interactor: LiquidityPoolRemoveLiquidityInteractorInput
    private let logger: LoggerProtocol
    private let chain: ChainModel
    private let wallet: MetaAccountModel
    private let liquidityPair: LiquidityPair
    private let dataValidatingFactory: SendDataValidatingFactory
    private let confirmViewModelFactory: LiquidityPoolSupplyConfirmViewModelFactory?
    private var flowClosure: () -> Void

    private var removeInfo: RemoveLiquidityInfo?
    private var reserves: BigUInt?
    private var swapFromChainAsset: ChainAsset?
    private var swapToChainAsset: ChainAsset?
    private var prices: [PriceData]?
    private var baseAssetInputResult: AmountInputResult?
    private var baseAssetBalance: Decimal?
    private var targetAssetInputResult: AmountInputResult?
    private var targetAssetBalance: Decimal?
    private var accountPoolInfo: AccountPool?
    private var totalIssuance: BigUInt?

    private var networkFeeViewModel: BalanceViewModelProtocol?
    private var networkFee: Decimal?
    private var xorBalance: Decimal?
    private var xorBalanceMinusFee: Decimal {
        (xorBalance ?? 0) - (networkFee ?? 0)
    }

    private var baseTargetRate: Decimal?
    private var dexId: String?

    private var loadingCollector = RemoveLiquidityLoadingCollector()

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
        interactor: LiquidityPoolRemoveLiquidityInteractorInput,
        router: LiquidityPoolRemoveLiquidityRouterInput,
        localizationManager: LocalizationManagerProtocol,
        wallet: MetaAccountModel,
        logger: LoggerProtocol,
        chain: ChainModel,
        liquidityPair: LiquidityPair,
        dataValidatingFactory: SendDataValidatingFactory,
        confirmViewModelFactory: LiquidityPoolSupplyConfirmViewModelFactory?,
        removeInfo: RemoveLiquidityInfo?,
        flowClosure: @escaping () -> Void
    ) {
        self.interactor = interactor
        self.router = router
        self.wallet = wallet
        self.logger = logger
        self.chain = chain
        self.liquidityPair = liquidityPair
        self.dataValidatingFactory = dataValidatingFactory
        self.confirmViewModelFactory = confirmViewModelFactory
        self.removeInfo = removeInfo
        dexId = liquidityPair.dexId
        self.flowClosure = flowClosure

        if let removeInfo = removeInfo, let utilityAsset = chain.utilityAssets().first {
            totalIssuance = removeInfo.totalIssuances.toSubstrateAmount(precision: Int16(utilityAsset.precision))
            reserves = removeInfo.baseAssetReserves.toSubstrateAmount(precision: Int16(utilityAsset.precision))
        }

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func buildCallParameters() -> RemoveLiquidityInfo? {
        guard
            let dexId,
            let baseAsset = chain.assets.first(where: { $0.currencyId == liquidityPair.baseAssetId }),
            let targetAsset = chain.assets.first(where: { $0.currencyId == liquidityPair.targetAssetId }),
            let totalIssuance = totalIssuance,
            let reserves = reserves,
            let baseAssetReserves = Decimal.fromSubstrateAmount(reserves, precision: Int16(baseAsset.precision)),
            let totalIssuanceDecimal = Decimal.fromSubstrateAmount(totalIssuance, precision: Int16(baseAsset.precision))
        else {
            return nil
        }

        let baseAssetInfo = PooledAssetInfo(id: liquidityPair.baseAssetId, precision: Int16(baseAsset.precision))
        let targetAssetInfo = PooledAssetInfo(id: liquidityPair.targetAssetId, precision: Int16(targetAsset.precision))

        let baseAssetAmount = baseAssetInputResult?.absoluteValue(from: baseAssetBalance ?? .zero) ?? .zero
        let targetAssetAmount = targetAssetInputResult?.absoluteValue(from: targetAssetBalance ?? .zero) ?? .zero

        let info = RemoveLiquidityInfo(
            dexId: dexId,
            baseAsset: baseAssetInfo,
            targetAsset: targetAssetInfo,
            baseAssetAmount: baseAssetAmount,
            targetAssetAmount: targetAssetAmount,
            baseAssetReserves: baseAssetReserves,
            totalIssuances: totalIssuanceDecimal,
            slippage: 0.5
        )

        return info
    }

    private func refreshFee() {
        guard let info = buildCallParameters() else {
            return
        }

        interactor.estimateFee(removeLiquidityInfo: info)
    }

    private func checkLoadingState() {
        DispatchQueue.main.async { [weak self] in
            self?.setupView?.setButtonLoadingState(isLoading: self?.loadingCollector.isReady == false)
            self?.confirmView?.setButtonLoadingState(isLoading: self?.loadingCollector.isReady == false)
        }
    }

    private func runLoadingState() {
        DispatchQueue.main.async { [weak self] in
            self?.setupView?.setButtonLoadingState(isLoading: true)
            self?.confirmView?.setButtonLoadingState(isLoading: true)
        }
    }

    private func resetLoadingState() {
        DispatchQueue.main.async { [weak self] in
            self?.setupView?.setButtonLoadingState(isLoading: false)
            self?.confirmView?.setButtonLoadingState(isLoading: false)
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
            self.setupView?.didReceiveNetworkFee(fee: feeViewModel)
            self.confirmView?.didReceiveNetworkFee(fee: feeViewModel)
        }

        networkFeeViewModel = feeViewModel

        checkLoadingState()
    }

    private func createBalanceViewModelFactory(for chainAsset: ChainAsset) -> BalanceViewModelFactory {
        let assetInfo = chainAsset.asset.displayInfo(with: chainAsset.chain.icon)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            selectedMetaAccount: wallet
        )
        return balanceViewModelFactory
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
            balance: accountPoolInfo?.baseAssetPooled,
            priceData: swapFromPrice
        ).value(for: selectedLocale)

        let inputViewModel = balanceViewModelFactory?
            .createBalanceInputViewModel(baseAssetResultAmount)
            .value(for: selectedLocale)

        DispatchQueue.main.async { [weak self] in
            self?.setupView?.didReceiveSwapFrom(viewModel: viewModel)

            if updateAmountInput {
                self?.setupView?.didReceiveSwapFrom(amountInputViewModel: inputViewModel)
            }
        }

        checkLoadingState()
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
            balance: accountPoolInfo?.targetAssetPooled,
            priceData: swapToPrice
        ).value(for: selectedLocale)

        let inputViewModel = balanceViewModelFactory?
            .createBalanceInputViewModel(targetAssetResultAmount)
            .value(for: selectedLocale)

        DispatchQueue.main.async { [weak self] in
            self?.setupView?.didReceiveSwapTo(viewModel: viewModel)

            if updateAmountInput {
                self?.setupView?.didReceiveSwapTo(amountInputViewModel: inputViewModel)
            }
        }

        checkLoadingState()
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

    private func provideConfirmViewModel() {
        guard let removeInfo else {
            return
        }
        let viewModel = confirmViewModelFactory?.buildViewModel(
            baseAssetAmount: removeInfo.baseAssetAmount,
            targetAssetAmount: removeInfo.targetAssetAmount,
            liquidityPair: liquidityPair,
            chain: chain,
            locale: selectedLocale
        )

        DispatchQueue.main.async { [weak self] in
            self?.confirmView?.didReceiveConfirmViewModel(viewModel)
        }
    }

    private func provideXorBalanceViewModel() {
        guard let xorBalance else {
            DispatchQueue.main.async { [weak self] in
                self?.setupView?.didReceiveXorBalanceViewModel(balanceViewModel: nil)
            }
            return
        }

        let balanceViewModelFactory = buildBalanceSwapToViewModelFactory(
            wallet: wallet,
            for: chain.utilityChainAssets().first
        )

        let xorPrice = prices?.first(where: { priceData in
            chain.utilityAssets().first?.priceId == priceData.priceId
        })

        let viewModel = balanceViewModelFactory?.balanceFromPrice(
            xorBalance,
            priceData: xorPrice,
            usageCase: .detailsCrypto
        ).value(for: selectedLocale)

        DispatchQueue.main.async { [weak self] in
            self?.setupView?.didReceiveXorBalanceViewModel(balanceViewModel: viewModel)
        }
    }

    private func handleRemovePool() {
        baseAssetInputResult = .absolute((accountPoolInfo?.baseAssetPooled).or(0))
        targetAssetInputResult = .absolute((accountPoolInfo?.targetAssetPooled).or(0))
        provideFromAssetVewModel()
        provideToAssetVewModel()

        refreshFee()
    }
}

// MARK: - LiquidityPoolRemoveLiquidityConfirmViewOutput

extension LiquidityPoolRemoveLiquidityPresenter: LiquidityPoolRemoveLiquidityConfirmViewOutput {
    func didLoad(view: LiquidityPoolRemoveLiquidityConfirmViewInput) {
        confirmView = view
        interactor.setup(with: self)
        provideConfirmViewModel()
    }

    func didTapConfirmButton() {
        guard let removeInfo else {
            return
        }
        runLoadingState()
        interactor.submit(removeLiquidityInfo: removeInfo)
    }

    func didTapFeeInfo() {
        var infoText: String
        var infoTitle: String
        infoTitle = R.string.localizable.lpNetworkFeeAlertTitle(preferredLanguages: selectedLocale.rLanguages)
        infoText = R.string.localizable.lpNetworkFeeAlertText(preferredLanguages: selectedLocale.rLanguages)

        let view = setupView ?? confirmView
        router.presentInfo(
            message: infoText,
            title: infoTitle,
            from: view
        )
    }
}

// MARK: - LiquidityPoolRemoveLiquidityViewOutput

extension LiquidityPoolRemoveLiquidityPresenter: LiquidityPoolRemoveLiquidityViewOutput {
    func handleViewAppeared() {
        swapFromChainAsset = chain.chainAssets.first(where: { $0.asset.currencyId == liquidityPair.baseAssetId })
        swapToChainAsset = chain.chainAssets.first(where: { $0.asset.currencyId == liquidityPair.targetAssetId })

        DispatchQueue.main.async {
            self.setupView?.didReceiveNetworkFee(fee: nil)
            self.confirmView?.didReceiveNetworkFee(fee: nil)
        }

        provideToAssetVewModel()
        provideFromAssetVewModel()
        refreshFee()
        checkLoadingState()
    }

    func didLoad(view: LiquidityPoolRemoveLiquidityViewInput) {
        setupView = view
        interactor.setup(with: self)

        refreshFee()
    }

    func didTapBackButton() {
        if let setupView {
            router.dismiss(view: setupView)
        } else if let confirmView {
            router.dismiss(view: confirmView)
        }
    }

    func didTapApyInfo() {
        var infoText: String
        var infoTitle: String
        infoTitle = R.string.localizable.lpApyAlertTitle(preferredLanguages: selectedLocale.rLanguages)
        infoText = R.string.localizable.lpApyAlertText(preferredLanguages: selectedLocale.rLanguages)
        router.presentInfo(
            message: infoText,
            title: infoTitle,
            from: setupView
        )
    }

    func didTapPreviewButton() {
        guard let info = buildCallParameters() else {
            return
        }

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
                sendAmount: .zero,
                locale: selectedLocale
            ),
            dataValidatingFactory.canPayFeeAndAmount(
                balanceType: .utility(balance: targetAssetBalance),
                feeAndTip: targetAssetFee,
                sendAmount: .zero,
                locale: selectedLocale
            ),
            dataValidatingFactory.canPayFeeAndAmount(
                balanceType: .utility(balance: accountPoolInfo?.baseAssetPooled),
                feeAndTip: .zero,
                sendAmount: baseAssetResultAmount,
                locale: selectedLocale
            ),
            dataValidatingFactory.canPayFeeAndAmount(
                balanceType: .utility(balance: accountPoolInfo?.targetAssetPooled),
                feeAndTip: .zero,
                sendAmount: targetAssetResultAmount,
                locale: selectedLocale
            )
        ]

        DataValidationRunner(validators: validators).runValidation { [weak self] in
            guard let self else {
                return
            }

            self.router.showConfirmation(
                chain: self.chain,
                wallet: self.wallet,
                liquidityPair: self.liquidityPair,
                info: info,
                flowClosure: self.flowClosure,
                from: self.setupView
            )
        }
    }

    func selectFromAmountPercentage(_ percentage: Float) {
        if percentage == 1.0 {
            handleRemovePool()
            return
        }

        runLoadingState()

        baseAssetInputResult = .rate(Decimal(Double(percentage)))

        let baseAssetAbsolulteValue = baseAssetInputResult?.absoluteValue(from: (accountPoolInfo?.baseAssetPooled).or(.zero))
        let targetAssetAbsoluteValue = baseAssetAbsolulteValue.or(.zero) * baseTargetRate.or(.zero)
        targetAssetInputResult = .absolute(targetAssetAbsoluteValue)

        provideFromAssetVewModel()
        provideToAssetVewModel()

        refreshFee()
    }

    func updateFromAmount(_ newValue: Decimal) {
        runLoadingState()

        baseAssetInputResult = .absolute(newValue)

        let baseAssetAbsolulteValue = baseAssetInputResult?.absoluteValue(from: (accountPoolInfo?.baseAssetPooled).or(.zero))
        let targetAssetAbsoluteValue = baseAssetAbsolulteValue.or(.zero) * baseTargetRate.or(.zero)
        targetAssetInputResult = .absolute(targetAssetAbsoluteValue)

        provideFromAssetVewModel(updateAmountInput: false)
        provideToAssetVewModel()

        refreshFee()
    }

    func selectToAmountPercentage(_ percentage: Float) {
        if percentage == 1.0 {
            handleRemovePool()
            return
        }

        runLoadingState()

        targetAssetInputResult = .rate(Decimal(Double(percentage)))

        let targetAssetAbsoluteValue = targetAssetInputResult?.absoluteValue(from: (accountPoolInfo?.targetAssetPooled).or(.zero))
        let baseAssetAbsolulteValue = targetAssetAbsoluteValue.or(.zero) / baseTargetRate.or(1)
        baseAssetInputResult = .absolute(baseAssetAbsolulteValue)

        provideFromAssetVewModel()
        provideToAssetVewModel()

        refreshFee()
    }

    func updateToAmount(_ newValue: Decimal) {
        runLoadingState()

        targetAssetInputResult = .absolute(newValue)

        let targetAssetAbsoluteValue = targetAssetInputResult?.absoluteValue(from: (accountPoolInfo?.targetAssetPooled).or(.zero))
        let baseAssetAbsolulteValue = targetAssetAbsoluteValue.or(.zero) / baseTargetRate.or(1)
        baseAssetInputResult = .absolute(baseAssetAbsolulteValue)

        provideFromAssetVewModel()
        provideToAssetVewModel(updateAmountInput: false)

        refreshFee()
    }
}

// MARK: - LiquidityPoolRemoveLiquidityInteractorOutput

extension LiquidityPoolRemoveLiquidityPresenter: LiquidityPoolRemoveLiquidityInteractorOutput {
    func didReceiveTransactionHash(_ hash: String) {
        guard let utilityChainAsset = chain.utilityChainAssets().first else {
            return
        }

        flowClosure()
        resetLoadingState()

        router.complete(on: confirmView, title: hash, chainAsset: utilityChainAsset)
    }

    func didReceiveSubmitError(error: Error) {
        resetLoadingState()
        router.present(error: error, from: setupView, locale: selectedLocale)
    }

    func didReceiveTotalIssuance(totalIssuance: BigUInt?) {
        self.totalIssuance = totalIssuance
        refreshFee()
        loadingCollector.totalIssuanceReady = true
        checkLoadingState()
    }

    func didReceiveTotalIssuanceError(error: Error) {
        logger.customError(error)
    }

    func didReceiveUserPool(pool: AccountPool?) {
        accountPoolInfo = pool

        provideToAssetVewModel()
        provideFromAssetVewModel()
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

            provideXorBalanceViewModel()

            let baseAssetPrice = prices?.first(where: { $0.priceId == swapFromChainAsset?.asset.priceId })
            let targetAssetPrice = prices?.first(where: { $0.priceId == swapToChainAsset?.asset.priceId })

            if
                let baseAssetPrice = baseAssetPrice,
                let targetAssetPrice = targetAssetPrice,
                let baseAssetPriceValue = Decimal(string: baseAssetPrice.price),
                let targetAssetPriceValue = Decimal(string: targetAssetPrice.price) {
                baseTargetRate = baseAssetPriceValue / targetAssetPriceValue

                DispatchQueue.main.async { [weak self] in
                    self?.setupView?.didReceiveSwapQuoteReady()
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

                provideXorBalanceViewModel()
            }
        case let .failure(error):
            router.present(error: error, from: setupView, locale: selectedLocale)
        }
    }

    func didReceivePoolReserves(reserves: PolkaswapPoolReservesInfo?) {
        guard let reserves else {
            return
        }

        self.reserves = reserves.reserves.reserves
        refreshFee()
        loadingCollector.reservesReady = true
        checkLoadingState()
    }

    func didReceiveUserPoolError(error: Error) {
        logger.customError(error)
    }

    func didReceivePoolReservesError(error: Error) {
        logger.customError(error)
    }
}

// MARK: - Localizable

extension LiquidityPoolRemoveLiquidityPresenter: Localizable {
    func applyLocalization() {}
}

extension LiquidityPoolRemoveLiquidityPresenter: LiquidityPoolRemoveLiquidityModuleInput {}
