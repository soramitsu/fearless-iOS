import Foundation
import SoraFoundation
import BigInt

final class PolkaswapAdjustmentPresenter {
    private enum InputTag: Int {
        case swapFrom = 0
        case swapTo
    }

    // MARK: Private properties

    private weak var view: PolkaswapAdjustmentViewInput?
    private weak var confirmationScreenModuleInput: PolkaswapSwapConfirmationModuleInput?
    private let router: PolkaswapAdjustmentRouterInput
    private let interactor: PolkaswapAdjustmentInteractorInput

    private let wallet: MetaAccountModel
    private let quoteFactory: SwapQuoteConverterProtocol
    private let dataValidatingFactory: SendDataValidatingFactory
    private let logger: LoggerProtocol

    private var polkaswapRemoteSettings: PolkaswapRemoteSettings?
    private let xorChainAsset: ChainAsset
    private var swapVariant: SwapVariant = .desiredInput
    private var swapFromChainAsset: ChainAsset?
    private var swapToChainAsset: ChainAsset?
    private var prices: [PriceData]?
    private var marketSourcer: SwapMarketSourcerProtocol?
    private var bestQuote: SubstrateSwapValues?
    private var polkaswapDexForRoute: PolkaswapDex?
    private var calcalatedAmounts: SwapQuoteAmounts?
    private var receiveValue: BalanceViewModelProtocol?

    private var slippadgeTolerance: Float = 0.5
    private var selectedLiquiditySourceType: LiquiditySourceType {
        didSet {
            view?.didReceive(market: selectedLiquiditySourceType)
        }
    }

    private var swapFromInputResult: AmountInputResult?
    private var swapFromBalance: Decimal?
    private var swapToInputResult: AmountInputResult?
    private var swapToBalance: Decimal?

    private var networkFee: Decimal?
    private var networkFeeViewModel: BalanceViewModelProtocol?
    private var liquidityProviderFee: Decimal?
    private var liquidityProviderFeeViewModel: BalanceViewModelProtocol?

    private var xorBalance: Decimal?
    private var xorBalanceMinusFee: Decimal {
        (xorBalance ?? 0) - (networkFee ?? 0) - (liquidityProviderFee ?? 0)
    }

    // MARK: - Constructors

    init(
        wallet: MetaAccountModel,
        soraChainAsset: ChainAsset,
        swapFromChainAsset: ChainAsset,
        quoteFactory: SwapQuoteConverterProtocol,
        dataValidatingFactory: SendDataValidatingFactory,
        logger: LoggerProtocol = Logger.shared,
        interactor: PolkaswapAdjustmentInteractorInput,
        router: PolkaswapAdjustmentRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wallet = wallet
        xorChainAsset = soraChainAsset
        self.swapFromChainAsset = swapFromChainAsset
        self.quoteFactory = quoteFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.logger = logger
        selectedLiquiditySourceType = LiquiditySourceType.smart
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideFromAssetVewModel() {
        var balance: Decimal? = swapFromBalance
        if swapFromChainAsset == xorChainAsset {
            balance = xorBalanceMinusFee
        }
        let inputAmount = swapFromInputResult?
            .absoluteValue(from: balance ?? .zero) ?? .zero
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

        view?.didReceiveSwapFrom(viewModel: viewModel)
        view?.didReceiveSwapFrom(amountInputViewModel: inputViewModel)
    }

    private func provideToAssetVewModel() {
        let inputAmount = swapToInputResult?
            .absoluteValue(from: swapToBalance ?? .zero) ?? .zero
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

        view?.didReceiveSwapTo(viewModel: viewModel)
        view?.didReceiveSwapTo(amountInputViewModel: inputViewModel)
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

    private func fetchQuotes() {
        guard let swapFromChainAsset = swapFromChainAsset,
              let swapToChainAsset = swapToChainAsset,
              let swapFromAssetId = swapFromChainAsset.asset.currencyId,
              let swapToAssetId = swapToChainAsset.asset.currencyId,
              let marketSourcer = marketSourcer
        else {
            return
        }

        let amount: String
        if swapVariant == .desiredInput {
            var balance: Decimal? = swapFromBalance
            if swapFromChainAsset == xorChainAsset {
                balance = xorBalanceMinusFee
            }
            guard let fromAmountDecimal = swapFromInputResult?.absoluteValue(from: balance ?? .zero) else {
                return
            }
            let bigUIntValue = fromAmountDecimal.toSubstrateAmount(
                precision: Int16(swapFromChainAsset.asset.precision)
            ) ?? .zero
            amount = String(bigUIntValue)
        } else {
            guard let toAmountDecimal = swapToInputResult?.absoluteValue(from: swapToBalance ?? .zero) else {
                return
            }
            let bigUIntValue = toAmountDecimal.toSubstrateAmount(
                precision: Int16(swapToChainAsset.asset.precision)
            ) ?? .zero
            amount = String(bigUIntValue)
        }

        let liquiditySources = marketSourcer.getServerMarketSources()

        let quoteParams = PolkaswapQuoteParams(
            fromAssetId: swapFromAssetId,
            toAssetId: swapToAssetId,
            amount: amount,
            swapVariant: swapVariant,
            liquiditySources: liquiditySources,
            filterMode: selectedLiquiditySourceType.filterMode
        )

        interactor.fetchQuotes(with: quoteParams)
        view?.didUpdating()
    }

    private func subscribeToPoolUpdates() {
        guard let swapFromAssetId = swapFromChainAsset?.asset.currencyId,
              let swapToAssetId = swapToChainAsset?.asset.currencyId,
              let polkaswapRemoteSettings = polkaswapRemoteSettings
        else {
            return
        }

        interactor.subscribeOnPool(
            for: swapFromAssetId,
            toAssetId: swapToAssetId,
            liquiditySourceType: selectedLiquiditySourceType,
            availablePolkaswapDex: polkaswapRemoteSettings.availableDexIds
        )
    }

    private func provideAmount(
        params: PolkaswapQuoteParams,
        quotes: [SwapValues]
    ) {
        guard let amounts = quoteFactory.createAmounts(
            xorChainAsset: xorChainAsset,
            fromAsset: swapFromChainAsset?.asset,
            toAsset: swapToChainAsset?.asset,
            params: params,
            quote: quotes,
            locale: selectedLocale
        ) else {
            return
        }

        fetchSwapFee(amounts: amounts)
        setAndDisplayAmount(amounts: amounts)
        provideReceiveValue(amounts.toAmount)
        provideLiqitityProviderFee(lpAmount: amounts.lpAmount)

        bestQuote = amounts.bestQuote
        calcalatedAmounts = amounts
        polkaswapDexForRoute = polkaswapRemoteSettings?.availableDexIds.first(where: { polkaswapDex in
            polkaswapDex.code == amounts.bestQuote.dexId
        })

        guard let params = preparePreviewParams() else {
            return
        }
        confirmationScreenModuleInput?.updateModule(with: params)
    }

    private func provideLiqitityProviderFee(lpAmount: Decimal) {
        let balanceViewModelFactory = createBalanceViewModelFactory(for: xorChainAsset)
        let lpViewModel = balanceViewModelFactory.balanceFromPrice(
            lpAmount,
            priceData: prices?.first(where: { price in
                price.priceId == xorChainAsset.asset.priceId
            })
        ).value(for: selectedLocale)

        view?.didReceiveLuquidityProvider(fee: lpViewModel)
        liquidityProviderFee = lpAmount
        liquidityProviderFeeViewModel = lpViewModel
        provideFromAssetVewModel()
    }

    private func provideReceiveValue(_ value: Decimal) {
        guard let swapToChainAsset = swapToChainAsset else {
            return
        }

        var minMaxValue: Decimal
        var price: PriceData?
        switch swapVariant {
        case .desiredInput:
            minMaxValue = value * Decimal(1 - Double(slippadgeTolerance) / 100.0)
            price = prices?.first(where: { price in
                price.priceId == swapToChainAsset.asset.priceId
            })
        case .desiredOutput:
            minMaxValue = value * Decimal(1 + Double(slippadgeTolerance) / 100.0)
            price = prices?.first(where: { price in
                price.priceId == swapFromChainAsset?.asset.priceId
            })
        }

        let balanceViewModelFactory = createBalanceViewModelFactory(for: swapToChainAsset)
        let receiveValue = balanceViewModelFactory.balanceFromPrice(
            minMaxValue,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceive(receiveValue: receiveValue)
        self.receiveValue = receiveValue
    }

    private func setAndDisplayAmount(amounts: SwapQuoteAmounts) {
        switch swapVariant {
        case .desiredInput:
            swapToInputResult = .absolute(amounts.toAmount)
            provideToAssetVewModel()
        case .desiredOutput:
            swapFromInputResult = .absolute(amounts.toAmount)
            provideFromAssetVewModel()
        }
        view?.didReceive(variant: swapVariant)
    }

    private func fetchSwapFee(amounts: SwapQuoteAmounts) {
        guard let fromAssetId = swapFromChainAsset?.asset.currencyId,
              let toAssetId = swapToChainAsset?.asset.currencyId,
              let precision = swapToChainAsset?.asset.precision
        else {
            return
        }

        let desired = amounts.toAmount
            .toSubstrateAmount(precision: Int16(precision)) ?? .zero
        let slip = BigUInt(integerLiteral: UInt64(slippadgeTolerance))
        let swapAmount = SwapAmount(
            type: swapVariant,
            desired: desired,
            slip: slip
        )

        interactor.estimateFee(
            dexId: "\(amounts.bestQuote.dexId ?? 0)",
            fromAssetId: fromAssetId,
            toAssetId: toAssetId,
            swapVariant: swapVariant,
            swapAmount: swapAmount,
            filter: selectedLiquiditySourceType.filterMode,
            liquiditySourceType: selectedLiquiditySourceType
        )
    }

    private func provideFeeViewModel() {
        guard let swapFromFee = networkFee else {
            return
        }
        let balanceViewModelFactory = createBalanceViewModelFactory(for: xorChainAsset)
        let feeViewModel = balanceViewModelFactory.balanceFromPrice(
            swapFromFee,
            priceData: prices?.first(where: { price in
                price.priceId == xorChainAsset.asset.priceId
            })
        ).value(for: selectedLocale)
        DispatchQueue.main.async {
            self.view?.didReceiveNetworkFee(fee: feeViewModel)
        }
        networkFeeViewModel = feeViewModel
    }

    private func createBalanceViewModelFactory(for chainAsset: ChainAsset) -> BalanceViewModelFactory {
        let assetInfo = chainAsset.asset.displayInfo(with: chainAsset.chain.icon)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            selectedMetaAccount: wallet
        )
        return balanceViewModelFactory
    }

    private func invalidateParams() {
        bestQuote = nil
        calcalatedAmounts = nil
        receiveValue = nil
        liquidityProviderFee = nil
        swapFromInputResult = nil
        swapToInputResult = nil
        provideFromAssetVewModel()
        provideToAssetVewModel()
    }

    private func preparePreviewParams() -> PolkaswapPreviewParams? {
        guard let amounts = calcalatedAmounts,
              let swapFromChainAsset = swapFromChainAsset,
              let swapToChainAsset = swapToChainAsset,
              let minMaxReceiveViewModel = receiveValue,
              let liquidityProviderFeeViewModel = liquidityProviderFeeViewModel,
              let networkFeeViewModel = networkFeeViewModel,
              let polkaswapDexForRoute = polkaswapDexForRoute
        else {
            return nil
        }

        let params = PolkaswapPreviewParams(
            wallet: wallet,
            soraChinAsset: xorChainAsset,
            swapFromChainAsset: swapFromChainAsset,
            swapToChainAsset: swapToChainAsset,
            fromAmount: amounts.fromAmount,
            toAmount: amounts.toAmount,
            slippadgeTolerance: slippadgeTolerance,
            swapVariant: swapVariant,
            market: selectedLiquiditySourceType,
            minMaxReceive: minMaxReceiveViewModel,
            polkaswapDexForRoute: polkaswapDexForRoute,
            lpFee: liquidityProviderFeeViewModel,
            networkFee: networkFeeViewModel
        )
        return params
    }
}

// MARK: - PolkaswapAdjustmentViewOutput

extension PolkaswapAdjustmentPresenter: PolkaswapAdjustmentViewOutput {
    func didLoad(view: PolkaswapAdjustmentViewInput) {
        self.view = view
        interactor.setup(with: self)
        interactor.didReceive(swapFromChainAsset, swapToChainAsset)
        view.didReceive(market: selectedLiquiditySourceType)
    }

    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapMarketButton() {
        guard let marketSourcer = marketSourcer else {
            return
        }
        let markets = marketSourcer.getMarketSources()
        router.showSelectMarket(
            from: view,
            markets: markets,
            selectedMarket: selectedLiquiditySourceType,
            slippadgeTolerance: slippadgeTolerance,
            moduleOutput: self
        )
    }

    func didTapSelectFromAsset() {
        router.showSelectAsset(
            from: view,
            wallet: wallet,
            chainAssets: swapFromChainAsset?.chain.chainAssets,
            selectedAssetId: swapFromChainAsset?.asset.id,
            contextTag: InputTag.swapFrom.rawValue,
            output: self
        )
    }

    func didTapSelectToAsset() {
        router.showSelectAsset(
            from: view,
            wallet: wallet,
            chainAssets: swapFromChainAsset?.chain.chainAssets,
            selectedAssetId: swapToChainAsset?.asset.id,
            contextTag: InputTag.swapTo.rawValue,
            output: self
        )
    }

    func selectFromAmountPercentage(_ percentage: Float) {
        swapVariant = .desiredInput
        swapFromInputResult = .rate(Decimal(Double(percentage)))
        provideFromAssetVewModel()
        fetchQuotes()
    }

    func updateFromAmount(_ newValue: Decimal) {
        swapVariant = .desiredInput
        swapFromInputResult = .absolute(newValue)
        provideFromAssetVewModel()
        fetchQuotes()
    }

    func selectToAmountPercentage(_ percentage: Float) {
        swapVariant = .desiredOutput
        swapToInputResult = .rate(Decimal(Double(percentage)))
        provideToAssetVewModel()
        fetchQuotes()
    }

    func updateToAmount(_ newValue: Decimal) {
        swapVariant = .desiredOutput
        swapToInputResult = .absolute(newValue)
        provideToAssetVewModel()
        fetchQuotes()
    }

    func didTapSwitchInputsButton() {
        let fromChainAsset = swapFromChainAsset
        let toChainAsset = swapToChainAsset
        swapToChainAsset = fromChainAsset
        swapFromChainAsset = toChainAsset

        let fromInput = swapFromInputResult
        let toInput = swapToInputResult
        swapToInputResult = fromInput
        swapFromInputResult = toInput

        provideFromAssetVewModel()
        provideToAssetVewModel()
        fetchQuotes()
    }

    func didTapMinReceiveInfo() {
        var infoText: String
        var infoTitle: String
        switch swapVariant {
        case .desiredInput:
            infoTitle = R.string.localizable
                .polkaswapMinReceived(preferredLanguages: selectedLocale.rLanguages)
            infoText = R.string.localizable
                .polkaswapMinimumReceivedInfo(preferredLanguages: selectedLocale.rLanguages)
        case .desiredOutput:
            infoTitle = R.string.localizable
                .polkaswapMaxReceived(preferredLanguages: selectedLocale.rLanguages)
            infoText = R.string.localizable
                .polkaswapMaximumSoldInfo(preferredLanguages: selectedLocale.rLanguages)
        }
        router.present(
            message: infoText,
            title: infoTitle,
            closeAction: nil,
            from: view
        )
    }

    func didTapLiquidityProviderFeeInfo() {
        let infoTitle = R.string.localizable
            .polkaswapLiquidityProviderFee(preferredLanguages: selectedLocale.rLanguages)
        let infoText = R.string.localizable
            .polkaswapLiqudityFeeInfo(preferredLanguages: selectedLocale.rLanguages)
        router.present(
            message: infoText,
            title: infoTitle,
            closeAction: nil,
            from: view
        )
    }

    func didTapNetworkFeeInfo() {
        let infoTitle = R.string.localizable
            .commonNetworkFee(preferredLanguages: selectedLocale.rLanguages)
        let infoText = R.string.localizable
            .polkaswapNetworkFeeInfo(preferredLanguages: selectedLocale.rLanguages)
        router.present(
            message: infoText,
            title: infoTitle,
            closeAction: nil,
            from: view
        )
    }

    func didTapPreviewButton() {
        guard let networkFee = networkFee,
              let liquidityProviderFee = liquidityProviderFee,
              let params = preparePreviewParams(),
              let amounts = calcalatedAmounts
        else {
            return
        }

        DataValidationRunner(validators: [
            dataValidatingFactory.has(fee: networkFee, locale: selectedLocale, onError: { [weak self] in
                self?.fetchSwapFee(amounts: amounts)
            }),
            dataValidatingFactory.canPayFeeAndAmount(
                balanceType: .utility(balance: xorBalance),
                feeAndTip: networkFee + liquidityProviderFee,
                sendAmount: .zero,
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            self?.confirmationScreenModuleInput = self?.router.showConfirmation(with: params, from: self?.view)
        }
    }

    func didTapInput(variant: SwapVariant) {
        swapVariant = variant
        guard let amounts = calcalatedAmounts else {
            return
        }
        provideReceiveValue(amounts.toAmount)
    }
}

// MARK: - PolkaswapAdjustmentInteractorOutput

extension PolkaswapAdjustmentPresenter: PolkaswapAdjustmentInteractorOutput {
    func didReceive(error: Error) {
        print("PolkaswapAdjustmentPresenter", error)
    }

    func didReceivePricesData(result: Result<[PriceData], Error>) {
        switch result {
        case let .success(priceData):
            prices = priceData
        case let .failure(error):
            prices = []
            router.present(error: error, from: view, locale: selectedLocale)
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
                        $0.data.available,
                        precision: Int16(chainAsset.asset.precision)
                    )
                } ?? .zero
                provideFromAssetVewModel()
            }
            if swapToChainAsset == chainAsset {
                swapToBalance = accountInfo.map {
                    Decimal.fromSubstrateAmount(
                        $0.data.available,
                        precision: Int16(chainAsset.asset.precision)
                    )
                } ?? .zero
                provideToAssetVewModel()
            }
            if xorChainAsset == chainAsset {
                xorBalance = accountInfo.map {
                    Decimal.fromSubstrateAmount(
                        $0.data.available,
                        precision: Int16(chainAsset.asset.precision)
                    )
                } ?? .zero
            }
        case let .failure(error):
            router.present(error: error, from: view, locale: selectedLocale)
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(info):
            guard let feeValue = BigUInt(info.fee),
                  let fee = Decimal.fromSubstrateAmount(
                      feeValue,
                      precision: Int16(xorChainAsset.asset.precision)
                  )
            else {
                DispatchQueue.main.async {
                    self.view?.didReceiveNetworkFee(fee: nil)
                }
                return
            }

            networkFee = fee

            provideFeeViewModel()
        case let .failure(error):
            didReceive(error: error)
        }
    }

    // TODO: - need think about this
    func didReceiveDex(infos: [PolkaswapDexInfo], fromAssetId: String, toAssetId: String) {
        let availableDexsInfos = infos
            .filter { $0.pathIsAvailable }
            .sorted(by: { $0.markets.count > $1.markets.count })

        guard fromAssetId == swapFromChainAsset?.asset.currencyId,
              toAssetId == swapToChainAsset?.asset.currencyId,
              let marketSourcer = marketSourcer,
              let dexInfo = availableDexsInfos.first
        else {
            return
        }

        if availableDexsInfos.isEmpty {
            DispatchQueue.main.async {
                self.router.present(
                    message: nil,
                    title: "Path not availalbe",
                    closeAction: nil,
                    from: self.view
                )
            }
        }

        let sourcesLiquidity = dexInfo.markets.map { LiquiditySourceType(rawValue: $0) }
        let addedSources = polkaswapRemoteSettings?.availableSources.filter {
            sourcesLiquidity.contains($0)
        }

        marketSourcer.didLoad(addedSources ?? [])
    }

    func didReceiveSwapValues(_ valuesMap: [SwapValues], params: PolkaswapQuoteParams, errors: [Error]) {
        errors.forEach { logger.error("\($0)") }
        provideAmount(params: params, quotes: valuesMap)
        if valuesMap.isEmpty, errors.isNotEmpty {
            invalidateParams()
            router.present(message: nil, title: "Quotes not available", closeAction: nil, from: view)
        }
    }

    func didReceiveSettings(settings: PolkaswapRemoteSettings?) {
        polkaswapRemoteSettings = settings
    }

    func updateQuotes() {
        bestQuote = nil
        calcalatedAmounts = nil
        fetchQuotes()
    }
}

// MARK: - Localizable

extension PolkaswapAdjustmentPresenter: Localizable {
    func applyLocalization() {}
}

extension PolkaswapAdjustmentPresenter: PolkaswapAdjustmentModuleInput {}

// MARK: - SelectAssetModuleOutput

extension PolkaswapAdjustmentPresenter: SelectAssetModuleOutput {
    func assetSelection(
        didCompleteWith chainAsset: ChainAsset?,
        contextTag: Int?
    ) {
        guard let rawValue = contextTag,
              let input = InputTag(rawValue: rawValue)
        else {
            return
        }

        switch input {
        case .swapFrom:
            guard let chainAsset = chainAsset else {
                return
            }
            swapFromChainAsset = chainAsset
            provideFromAssetVewModel()
        case .swapTo:
            swapToChainAsset = chainAsset
            provideToAssetVewModel()
        }

        marketSourcer = SwapMarketSourcer(
            fromAssetId: swapFromChainAsset?.asset.currencyId,
            toAssetId: swapToChainAsset?.asset.currencyId,
            forceSmartIds: polkaswapRemoteSettings?.forceSmartIds ?? []
        )
        interactor.didReceive(swapFromChainAsset, swapToChainAsset)
        subscribeToPoolUpdates()
        fetchQuotes()

        let slip = BigUInt(integerLiteral: UInt64(slippadgeTolerance))
        interactor.estimateFee(
            dexId: "0",
            fromAssetId: swapFromChainAsset?.asset.currencyId ?? "",
            toAssetId: swapToChainAsset?.asset.currencyId ?? "",
            swapVariant: swapVariant,
            swapAmount: SwapAmount(type: swapVariant, desired: .zero, slip: slip),
            filter: selectedLiquiditySourceType.filterMode,
            liquiditySourceType: selectedLiquiditySourceType
        )
    }
}

// MARK: - PolkaswapTransaktionSettingsModuleOutput

extension PolkaswapAdjustmentPresenter: PolkaswapTransaktionSettingsModuleOutput {
    func didReceive(market: LiquiditySourceType, slippadgeTolerance: Float) {
        if selectedLiquiditySourceType != market {
            selectedLiquiditySourceType = market
            subscribeToPoolUpdates()
            fetchQuotes()
        }
        if slippadgeTolerance != self.slippadgeTolerance {
            self.slippadgeTolerance = slippadgeTolerance
            guard let calcalatedAmounts = calcalatedAmounts else {
                return
            }
            provideReceiveValue(calcalatedAmounts.toAmount)
        }
    }
}
