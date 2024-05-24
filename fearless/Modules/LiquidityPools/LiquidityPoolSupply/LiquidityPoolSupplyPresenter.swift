import Foundation
import SoraFoundation
import SSFModels
import SSFPools
import BigInt

protocol LiquidityPoolSupplyViewInput: ControllerBackedProtocol {
    func didReceiveSwapFrom(viewModel: AssetBalanceViewModelProtocol?)
    func didReceiveSwapTo(viewModel: AssetBalanceViewModelProtocol?)
    func didReceiveSwapFrom(amountInputViewModel: IAmountInputViewModel?)
    func didReceiveSwapTo(amountInputViewModel: IAmountInputViewModel?)
    func didReceiveNetworkFee(fee: BalanceViewModelProtocol?)
    func setButtonLoadingState(isLoading: Bool)
    func didUpdating()
}

protocol LiquidityPoolSupplyInteractorInput: AnyObject {
    func setup(with output: LiquidityPoolSupplyInteractorOutput)
    func estimateFee(supplyLiquidityInfo: SupplyLiquidityInfo)
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

    private let wallet: MetaAccountModel
    private var swapFromChainAsset: ChainAsset?
    private var swapToChainAsset: ChainAsset?
    private var prices: [PriceData]?
    private var swapVariant: SwapVariant = .desiredInput

    private var slippadgeTolerance: Float = Constants.slippadgeTolerance
    private var swapFromInputResult: AmountInputResult?
    private var swapFromBalance: Decimal?
    private var swapToInputResult: AmountInputResult?
    private var swapToBalance: Decimal?

    private var networkFeeViewModel: BalanceViewModelProtocol?
    private var networkFee: Decimal?
    private var xorBalance: Decimal?
    private var xorBalanceMinusFee: Decimal {
        (xorBalance ?? 0) - (networkFee ?? 0)
    }

    private var baseTargetRate: Decimal?

    private var dexId: String?

    // MARK: - Constructors

    init(
        interactor: LiquidityPoolSupplyInteractorInput,
        router: LiquidityPoolSupplyRouterInput,
        liquidityPair: LiquidityPair,
        localizationManager: LocalizationManagerProtocol,
        chain: ChainModel,
        logger: LoggerProtocol,
        wallet: MetaAccountModel,
        dataValidatingFactory: SendDataValidatingFactory
    ) {
        self.interactor = interactor
        self.router = router
        self.liquidityPair = liquidityPair
        self.chain = chain
        self.logger = logger
        self.wallet = wallet
        self.dataValidatingFactory = dataValidatingFactory

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

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

        let baseAssetAmount = swapFromInputResult?.absoluteValue(from: swapFromBalance ?? .zero) ?? .zero
        let targetAssetAmount = swapToInputResult?.absoluteValue(from: swapToBalance ?? .zero) ?? .zero
        let supplyLiquidityInfo = SupplyLiquidityInfo(
            dexId: dexId,
            baseAsset: baseAssetInfo,
            targetAsset: targetAssetInfo,
            baseAssetAmount: baseAssetAmount,
            targetAssetAmount: targetAssetAmount,
            slippage: Decimal(floatLiteral: Double(slippadgeTolerance))
        )

        interactor.estimateFee(supplyLiquidityInfo: supplyLiquidityInfo)
    }

    private func runLoadingState() {
        DispatchQueue.main.async { [weak self] in
            self?.view?.setButtonLoadingState(isLoading: true)
        }
    }

    private func checkLoadingState() {
        DispatchQueue.main.async { [weak self] in
            self?.view?.setButtonLoadingState(isLoading: false)
        }
    }

    private func provideFromAssetVewModel(updateAmountInput: Bool = true) {
        var balance: Decimal? = swapFromBalance
        if swapFromChainAsset == chain.utilityChainAssets().first, let xorBalance = xorBalance, let networkFee = networkFee {
            balance = xorBalance - networkFee
        }
        let inputAmount = swapFromInputResult?
            .absoluteValue(from: balance ?? .zero)
        let balanceViewModelFactory = buildBalanceSwapToViewModelFactory(
            wallet: wallet,
            for: swapFromChainAsset
        )

        let swapFromPrice = prices?.first(where: { priceData in
            swapFromChainAsset?.asset.priceId == priceData.priceId
        })

        let viewModel = balanceViewModelFactory?.createAssetBalanceViewModel(
            inputAmount,
            balance: swapFromBalance,
            priceData: swapFromPrice
        ).value(for: selectedLocale)

        let inputViewModel = balanceViewModelFactory?
            .createBalanceInputViewModel(inputAmount)
            .value(for: selectedLocale)

        DispatchQueue.main.async { [weak self] in
            self?.view?.didReceiveSwapFrom(viewModel: viewModel)

            if updateAmountInput {
                self?.view?.didReceiveSwapFrom(amountInputViewModel: inputViewModel)
            }
        }

        checkLoadingState()
    }

    private func provideToAssetVewModel(updateAmountInput: Bool = true) {
        let inputAmount = swapToInputResult?
            .absoluteValue(from: swapToBalance ?? .zero)
        let balanceViewModelFactory = buildBalanceSwapToViewModelFactory(
            wallet: wallet,
            for: swapToChainAsset
        )

        let swapToPrice = prices?.first(where: { priceData in
            swapToChainAsset?.asset.priceId == priceData.priceId
        })

        let viewModel = balanceViewModelFactory?.createAssetBalanceViewModel(
            inputAmount,
            balance: swapToBalance,
            priceData: swapToPrice
        ).value(for: selectedLocale)

        let inputViewModel = balanceViewModelFactory?
            .createBalanceInputViewModel(inputAmount)
            .value(for: selectedLocale)

        DispatchQueue.main.async { [weak self] in
            self?.view?.didReceiveSwapTo(viewModel: viewModel)

            if updateAmountInput {
                self?.view?.didReceiveSwapTo(amountInputViewModel: inputViewModel)
            }
        }

        checkLoadingState()
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

    private func createBalanceViewModelFactory(for chainAsset: ChainAsset) -> BalanceViewModelFactory {
        let assetInfo = chainAsset.asset.displayInfo(with: chainAsset.chain.icon)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            selectedMetaAccount: wallet
        )
        return balanceViewModelFactory
    }

    private func runCanXorPayValidation(sendAmount: Decimal) {
        DataValidationRunner(validators: [
            dataValidatingFactory.canPayFeeAndAmount(
                balanceType: .utility(balance: xorBalance),
                feeAndTip: networkFee ?? .zero,
                sendAmount: sendAmount,
                locale: selectedLocale
            )
        ]).runValidation {}
    }

    private func provideInitialData() {
        swapFromChainAsset = chain.chainAssets.first(where: { $0.asset.currencyId == liquidityPair.baseAssetId })
        swapToChainAsset = chain.chainAssets.first(where: { $0.asset.currencyId == liquidityPair.targetAssetId })

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
        infoTitle = R.string.localizable
            .polkaswapMinReceived(preferredLanguages: selectedLocale.rLanguages)
        infoText = R.string.localizable
            .polkaswapMinimumReceivedInfo(preferredLanguages: selectedLocale.rLanguages)
        router.presentInfo(
            message: infoText,
            title: infoTitle,
            from: view
        )
    }

    func didTapPreviewButton() {}

    func selectFromAmountPercentage(_ percentage: Float) {
        runLoadingState()

        swapVariant = .desiredInput
        swapFromInputResult = .rate(Decimal(Double(percentage)))

        let baseAssetAbsolulteValue = swapFromInputResult?.absoluteValue(from: swapFromBalance.or(.zero))
        let targetAssetAbsoluteValue = baseAssetAbsolulteValue.or(.zero) * baseTargetRate.or(.zero)
        swapToInputResult = .absolute(targetAssetAbsoluteValue)

        provideFromAssetVewModel()
        provideToAssetVewModel()

        if swapFromChainAsset == chain.utilityChainAssets().first {
            let inputAmount = swapFromInputResult?
                .absoluteValue(from: xorBalanceMinusFee)
            runCanXorPayValidation(sendAmount: inputAmount ?? .zero)
        }

        refreshFee()
    }

    func updateFromAmount(_ newValue: Decimal) {
        runLoadingState()

        swapVariant = .desiredInput
        swapFromInputResult = .absolute(newValue)

        let baseAssetAbsolulteValue = swapFromInputResult?.absoluteValue(from: swapFromBalance.or(.zero))
        let targetAssetAbsoluteValue = baseAssetAbsolulteValue.or(.zero) * baseTargetRate.or(.zero)
        swapToInputResult = .absolute(targetAssetAbsoluteValue)

        provideFromAssetVewModel(updateAmountInput: false)
        provideToAssetVewModel()

        refreshFee()
    }

    func selectToAmountPercentage(_ percentage: Float) {
        runLoadingState()

        swapVariant = .desiredOutput
        swapToInputResult = .rate(Decimal(Double(percentage)))

        let targetAssetAbsoluteValue = swapToInputResult?.absoluteValue(from: swapToBalance.or(.zero))
        let baseAssetAbsolulteValue = targetAssetAbsoluteValue.or(.zero) * baseTargetRate.or(.zero)
        swapFromInputResult = .absolute(baseAssetAbsolulteValue)

        provideFromAssetVewModel()
        provideToAssetVewModel()

        refreshFee()
    }

    func updateToAmount(_ newValue: Decimal) {
        runLoadingState()

        swapVariant = .desiredOutput
        swapToInputResult = .absolute(newValue)

        let targetAssetAbsoluteValue = swapToInputResult?.absoluteValue(from: swapToBalance.or(.zero))
        let baseAssetAbsolulteValue = targetAssetAbsoluteValue.or(.zero) * baseTargetRate.or(.zero)
        swapFromInputResult = .absolute(baseAssetAbsolulteValue)

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
        provideInitialData()
    }
}

// MARK: - LiquidityPoolSupplyInteractorOutput

extension LiquidityPoolSupplyPresenter: LiquidityPoolSupplyInteractorOutput {
    func didReceiveDexId(_ dexId: String) {
        self.dexId = dexId
        refreshFee()
    }

    func didReceiveDexIdError(_ error: Error) {
        logger.customError(error)
    }

    func didReceiveFee(_ fee: BigUInt) {
        guard let utilityAsset = chain.utilityAssets().first else {
            return
        }

        networkFee = Decimal.fromSubstrateAmount(fee, precision: Int16(utilityAsset.precision))
        provideFeeViewModel()
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
                swapFromBalance = accountInfo.map {
                    Decimal.fromSubstrateAmount(
                        $0.data.sendAvailable,
                        precision: Int16(chainAsset.asset.precision)
                    )
                } ?? .zero
                provideFromAssetVewModel()
            }
            if swapToChainAsset == chainAsset {
                swapToBalance = accountInfo.map {
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
