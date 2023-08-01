import Foundation
import SoraFoundation
import BigInt
import SSFModels

// swiftlint:disable file_length type_body_length
final class PolkaswapAdjustmentPresenter {
    private enum InputTag: Int {
        case swapFrom = 0
        case swapTo
    }

    private enum Constants {
        static let slippadgeTolerance: Float = 0.5
        static let quotesRequestDelay: CGFloat = 0.8
    }

    // MARK: Private properties

    private weak var view: PolkaswapAdjustmentViewInput?
    private weak var confirmationScreenModuleInput: PolkaswapSwapConfirmationModuleInput?
    private let router: PolkaswapAdjustmentRouterInput
    private let interactor: PolkaswapAdjustmentInteractorInput

    private let wallet: MetaAccountModel
    private let viewModelFactory: PolkaswapAdjustmentViewModelFactoryProtocol
    private let dataValidatingFactory: SendDataValidatingFactory
    private let logger: LoggerProtocol

    private var polkaswapRemoteSettings: PolkaswapRemoteSettings?
    private let xorChainAsset: ChainAsset
    private var swapVariant: SwapVariant = .desiredInput
    private var swapFromChainAsset: ChainAsset?
    private var swapToChainAsset: ChainAsset?
    private var prices: [PriceData]?
    private var marketSource: SwapMarketSourceProtocol?
    private var polkaswapDexForRoute: PolkaswapDex?
    private var calcalatedAmounts: SwapQuoteAmounts?
    private var detailsViewModel: PolkaswapAdjustmentDetailsViewModel?
    private var quotesWorkItem: DispatchWorkItem?

    private var slippadgeTolerance: Float = Constants.slippadgeTolerance
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

    private var xorBalance: Decimal?
    private var xorBalanceMinusFee: Decimal {
        (xorBalance ?? 0) - (networkFee ?? 0)
    }

    private var loadingCollector = PolkaswapAdjustmentViewLoadingCollector()

    // MARK: - Constructors

    init(
        wallet: MetaAccountModel,
        soraChainAsset: ChainAsset,
        swapChainAsset: ChainAsset,
        viewModelFactory: PolkaswapAdjustmentViewModelFactoryProtocol,
        dataValidatingFactory: SendDataValidatingFactory,
        logger: LoggerProtocol = Logger.shared,
        interactor: PolkaswapAdjustmentInteractorInput,
        router: PolkaswapAdjustmentRouterInput,
        swapVariant: SwapVariant,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wallet = wallet
        xorChainAsset = soraChainAsset
        self.viewModelFactory = viewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.logger = logger
        selectedLiquiditySourceType = LiquiditySourceType.smart
        self.interactor = interactor
        self.router = router
        self.swapVariant = swapVariant
        self.localizationManager = localizationManager

        switch swapVariant {
        case .desiredInput:
            swapFromChainAsset = swapChainAsset
        case .desiredOutput:
            swapToChainAsset = swapChainAsset
        }
    }

    // MARK: - Private methods

    private func runLoadingState() {
        guard swapFromInputResult != nil || swapToInputResult != nil else {
            return
        }

        view?.setButtonLoadingState(isLoading: true)
        loadingCollector.reset()
    }

    private func checkLoadingState() {
        if loadingCollector.isReady {
            view?.setButtonLoadingState(isLoading: false)
        }
    }

    private func provideFromAssetVewModel() {
        var balance: Decimal? = swapFromBalance
        if swapFromChainAsset == xorChainAsset {
            balance = xorBalance
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

        view?.didReceiveSwapFrom(viewModel: viewModel)
        view?.didReceiveSwapFrom(amountInputViewModel: inputViewModel)

        loadingCollector.fromReady = true
        checkLoadingState()
    }

    private func provideToAssetVewModel() {
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

        view?.didReceiveSwapTo(viewModel: viewModel)
        view?.didReceiveSwapTo(amountInputViewModel: inputViewModel)

        loadingCollector.toReady = true
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

    private func fetchQuotes() {
        quotesWorkItem?.cancel()
        guard let swapFromChainAsset = swapFromChainAsset,
              let swapToChainAsset = swapToChainAsset,
              let swapFromAssetId = swapFromChainAsset.asset.currencyId,
              let swapToAssetId = swapToChainAsset.asset.currencyId,
              let marketSourcer = marketSource
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

        let liquiditySources = marketSourcer.getRemoteMarketSources()

        let quoteParams = PolkaswapQuoteParams(
            fromAssetId: swapFromAssetId,
            toAssetId: swapToAssetId,
            amount: amount,
            swapVariant: swapVariant,
            liquiditySources: liquiditySources,
            filterMode: selectedLiquiditySourceType.filterMode
        )

        let task = DispatchWorkItem { [weak self] in
            self?.interactor.fetchQuotes(with: quoteParams)
            self?.view?.didUpdating()
        }
        quotesWorkItem = task
        DispatchQueue.global().asyncAfter(deadline: .now() + Constants.quotesRequestDelay, execute: task)
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
        guard let amounts = viewModelFactory.createAmounts(
            xorChainAsset: xorChainAsset,
            fromAsset: swapFromChainAsset?.asset,
            toAsset: swapToChainAsset?.asset,
            params: params,
            quote: quotes
        ) else {
            return
        }

        fetchSwapFee(amounts: amounts)
        setAndDisplayAmount(amounts: amounts)
        calcalatedAmounts = amounts
        liquidityProviderFee = amounts.lpAmount
        polkaswapDexForRoute = polkaswapRemoteSettings?.availableDexIds.first(where: { polkaswapDex in
            polkaswapDex.code == amounts.bestQuote.dexId
        })

        detailsViewModel = provideDetailsViewModel(with: amounts)

        guard let params = preparePreviewParams() else {
            return
        }
        confirmationScreenModuleInput?.updateModule(with: params)
    }

    private func provideDetailsViewModel(
        with amounts: SwapQuoteAmounts
    ) -> PolkaswapAdjustmentDetailsViewModel? {
        guard let swapToChainAsset = swapToChainAsset,
              let swapFromChainAsset = swapFromChainAsset,
              let polkaswapRemoteSettings = polkaswapRemoteSettings
        else {
            return nil
        }
        let detailsViewModel = viewModelFactory.createDetailsViewModel(
            with: amounts,
            swapToChainAsset: swapToChainAsset,
            swapFromChainAsset: swapFromChainAsset,
            swapVariant: swapVariant,
            availableDexIds: polkaswapRemoteSettings.availableDexIds,
            slippadgeTolerance: slippadgeTolerance,
            prices: prices,
            locale: selectedLocale
        )
        view?.didReceiveDetails(viewModel: detailsViewModel)

        loadingCollector.detailsReady = true
        checkLoadingState()

        return detailsViewModel
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
        guard let polkaswapRemoteSettings = polkaswapRemoteSettings else {
            return
        }
        let fromAssetId = swapFromChainAsset?.asset.currencyId ?? polkaswapRemoteSettings.xstusdId
        let toAssetId = swapToChainAsset?.asset.currencyId ?? polkaswapRemoteSettings.xstusdId
        let precision = swapToChainAsset?.asset.precision ?? 18

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
        let balanceViewModelFactory = viewModelFactory
            .createBalanceViewModelFactory(for: xorChainAsset)
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

        loadingCollector.feeReady = true
        checkLoadingState()
    }

    private func invalidateParams() {
        calcalatedAmounts = nil
        liquidityProviderFee = nil
        swapFromInputResult = nil
        swapToInputResult = nil
        provideFromAssetVewModel()
        provideToAssetVewModel()
        view?.didReceiveDetails(viewModel: nil)
    }

    private func preparePreviewParams() -> PolkaswapPreviewParams? {
        var swapFromBalance = swapFromBalance
        if swapFromChainAsset == xorChainAsset {
            swapFromBalance = xorBalanceMinusFee
        }
        guard let swapFromChainAsset = swapFromChainAsset,
              let swapToChainAsset = swapToChainAsset,
              let polkaswapDexForRoute = polkaswapDexForRoute,
              let networkFeeViewModel = networkFeeViewModel,
              let detailsViewModel = detailsViewModel,
              let fromAmount = swapFromInputResult?.absoluteValue(from: swapFromBalance ?? .zero),
              let toAmount = swapToInputResult?.absoluteValue(from: swapToBalance ?? .zero)
        else {
            return nil
        }

        let params = PolkaswapPreviewParams(
            wallet: wallet,
            soraChinAsset: xorChainAsset,
            swapFromChainAsset: swapFromChainAsset,
            swapToChainAsset: swapToChainAsset,
            fromAmount: fromAmount,
            toAmount: toAmount,
            slippadgeTolerance: slippadgeTolerance,
            swapVariant: swapVariant,
            market: selectedLiquiditySourceType,
            polkaswapDexForRoute: polkaswapDexForRoute,
            networkFee: networkFeeViewModel,
            detailsViewModel: detailsViewModel,
            minMaxValue: detailsViewModel.minMaxReceiveValue
        )
        return params
    }

    private func showMarketSelectionAlert() {
        let chooseAssetTitle = R.string.localizable
            .polkaswapMarketAlertChooseAction(preferredLanguages: selectedLocale.rLanguages)
        let chooseAssetAction = SheetAlertPresentableAction(
            title: chooseAssetTitle,
            button: UIFactory.default.createMainActionButton()
        ) { [weak self] in
            guard let strongSelf = self else { return }
            var contextTag: Int?
            var filterChainAsset: ChainAsset?
            if let swapFromChainAsset = strongSelf.swapFromChainAsset {
                filterChainAsset = swapFromChainAsset
                contextTag = InputTag.swapTo.rawValue
            } else if let swapToChainAsset = strongSelf.swapToChainAsset {
                contextTag = InputTag.swapFrom.rawValue
                filterChainAsset = swapToChainAsset
            }
            let showChainAssets = strongSelf.xorChainAsset.chain.chainAssets
                .filter { $0.chainAssetId != filterChainAsset?.chainAssetId }
            strongSelf.router.showSelectAsset(
                from: strongSelf.view,
                wallet: strongSelf.wallet,
                chainAssets: showChainAssets,
                selectedAssetId: strongSelf.swapFromChainAsset?.asset.id,
                contextTag: contextTag,
                output: strongSelf
            )
        }
        let closeTitle = R.string.localizable
            .commonCancel(preferredLanguages: selectedLocale.rLanguages)

        let alertTitle = R.string.localizable
            .polkaswapMarketAlertTitle(preferredLanguages: selectedLocale.rLanguages)
        let alertMessage = R.string.localizable
            .polkaswapMarketAlertMessage(preferredLanguages: selectedLocale.rLanguages)
        let viewModel = SheetAlertPresentableViewModel(
            title: alertTitle,
            message: alertMessage,
            actions: [chooseAssetAction],
            closeAction: closeTitle,
            dismissCompletion: nil,
            icon: R.image.iconWarningBig()
        )
        router.present(
            viewModel: viewModel,
            from: view
        )
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

    private func presentAddMoreAmountAlert() {
        let message = R.string.localizable
            .polkaswapAddMoreAmountMessage(preferredLanguages: selectedLocale.rLanguages)
        router.present(
            message: message,
            title: "",
            closeAction: nil,
            from: view
        )
    }

    func toggleSwapDirection() {
        if swapVariant == .desiredInput {
            swapVariant = .desiredOutput
        } else {
            swapVariant = .desiredInput
        }
    }
}

// MARK: - PolkaswapAdjustmentViewOutput

extension PolkaswapAdjustmentPresenter: PolkaswapAdjustmentViewOutput {
    func didLoad(view: PolkaswapAdjustmentViewInput) {
        self.view = view
        interactor.setup(with: self)
        interactor.didReceive(swapFromChainAsset, swapToChainAsset)
        fetchSwapFee(amounts: .mockQuoteAmount)
        view.didReceive(market: selectedLiquiditySourceType)
    }

    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapMarketButton() {
        guard let marketSourcer = marketSource else {
            showMarketSelectionAlert()
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
        let showChainAssets = xorChainAsset.chain.chainAssets
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
        let showChainAssets = xorChainAsset.chain.chainAssets
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

    func selectFromAmountPercentage(_ percentage: Float) {
        runLoadingState()

        swapVariant = .desiredInput
        swapFromInputResult = .rate(Decimal(Double(percentage)))
        provideFromAssetVewModel()
        fetchQuotes()

        if swapFromChainAsset == xorChainAsset {
            let inputAmount = swapFromInputResult?
                .absoluteValue(from: xorBalanceMinusFee)
            runCanXorPayValidation(sendAmount: inputAmount ?? .zero)
        }
    }

    func updateFromAmount(_ newValue: Decimal) {
        runLoadingState()

        swapVariant = .desiredInput
        swapFromInputResult = .absolute(newValue)
        provideFromAssetVewModel()
        fetchQuotes()
    }

    func selectToAmountPercentage(_ percentage: Float) {
        runLoadingState()

        swapVariant = .desiredOutput
        swapToInputResult = .rate(Decimal(Double(percentage)))
        provideToAssetVewModel()
        fetchQuotes()
    }

    func updateToAmount(_ newValue: Decimal) {
        runLoadingState()

        swapVariant = .desiredOutput
        swapToInputResult = .absolute(newValue)
        provideToAssetVewModel()
        fetchQuotes()
    }

    func didTapSwitchInputsButton() {
        runLoadingState()

        let fromChainAsset = swapFromChainAsset
        let toChainAsset = swapToChainAsset
        swapToChainAsset = fromChainAsset
        swapFromChainAsset = toChainAsset

        let fromInput = swapFromInputResult
        let toInput = swapToInputResult
        swapToInputResult = fromInput
        swapFromInputResult = toInput

        let fromBalance = swapFromBalance
        let toBalance = swapToBalance
        swapToBalance = fromBalance
        swapFromBalance = toBalance

        toggleSwapDirection()
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
        router.presentInfo(
            message: infoText,
            title: infoTitle,
            from: view
        )
    }

    func didTapLiquidityProviderFeeInfo() {
        let infoTitle = R.string.localizable
            .polkaswapLiquidityProviderFee(preferredLanguages: selectedLocale.rLanguages)
        let infoText = R.string.localizable
            .polkaswapLiqudityFeeInfo(preferredLanguages: selectedLocale.rLanguages)
        router.presentInfo(
            message: infoText,
            title: infoTitle,
            from: view
        )
    }

    func didTapNetworkFeeInfo() {
        let infoTitle = R.string.localizable
            .commonNetworkFee(preferredLanguages: selectedLocale.rLanguages)
        let infoText = R.string.localizable
            .polkaswapNetworkFeeInfo(preferredLanguages: selectedLocale.rLanguages)
        router.presentInfo(
            message: infoText,
            title: infoTitle,
            from: view
        )
    }

    func didTapPreviewButton() {
        guard let networkFee = networkFee,
              let params = preparePreviewParams(),
              let amounts = calcalatedAmounts
        else {
            return
        }

        // if don't have XOR balance for fee payment, fee will be payment from receive amount
        if xorBalance.or(.zero) < networkFee, swapToChainAsset?.identifier == xorChainAsset.identifier {
            if params.toAmount <= networkFee {
                presentAddMoreAmountAlert()
                return
            }
            xorBalance = networkFee
        }

        let sendAmount: Decimal
        switch swapVariant {
        case .desiredInput:
            sendAmount = amounts.fromAmount
        case .desiredOutput:
            sendAmount = amounts.toAmount
        }

        DataValidationRunner(validators: [
            dataValidatingFactory.has(fee: networkFee, locale: selectedLocale, onError: { [weak self] in
                self?.fetchSwapFee(amounts: amounts)
            }),
            dataValidatingFactory.canPayFeeAndAmount(
                balanceType: .utility(balance: xorBalance),
                feeAndTip: networkFee,
                sendAmount: .zero,
                locale: selectedLocale
            ),
            dataValidatingFactory.canPayFeeAndAmount(
                balanceType: .utility(balance: swapFromBalance),
                feeAndTip: .zero,
                sendAmount: sendAmount,
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
        detailsViewModel = provideDetailsViewModel(with: amounts)
    }

    func didTapReadDisclaimer() {
        router.showDisclaimer(moduleOutput: self, from: view)
    }
}

// MARK: - PolkaswapAdjustmentInteractorOutput

extension PolkaswapAdjustmentPresenter: PolkaswapAdjustmentInteractorOutput {
    func didReceive(error: Error) {
        logger.error("\(error)")
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
            if xorChainAsset == chainAsset {
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

        fetchQuotes()
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
              let marketSourcer = marketSource,
              let dexInfo = availableDexsInfos.first
        else {
            return
        }

        let alertTitle = R.string.localizable
            .polkaswapDexAlertTitle(preferredLanguages: selectedLocale.rLanguages)
        let alertMessage = R.string.localizable
            .polkaswapDexAlertMessage(preferredLanguages: selectedLocale.rLanguages)

        if availableDexsInfos.isEmpty {
            DispatchQueue.main.async {
                self.router.present(
                    message: alertMessage,
                    title: alertTitle,
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
        guard params.fromAssetId == swapFromChainAsset?.asset.currencyId,
              params.toAssetId == swapToChainAsset?.asset.currencyId
        else {
            return
        }

        errors.forEach { logger.error("\($0)") }
        provideAmount(params: params, quotes: valuesMap)
        if valuesMap.isEmpty, errors.isNotEmpty {
            invalidateParams()
            let title = R.string.localizable
                .polkaswapQuotesNotAvailable(preferredLanguages: selectedLocale.rLanguages)
            router.present(message: nil, title: title, closeAction: nil, from: view)
        }
    }

    func didReceiveSettings(settings: PolkaswapRemoteSettings?) {
        polkaswapRemoteSettings = settings
    }

    func updateQuotes() {
        calcalatedAmounts = nil
        fetchQuotes()
    }

    func didReceiveDisclaimer(visible: Bool) {
        view?.setDisclaimer(visible: visible)
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
        view?.didUpdating()
        guard let rawValue = contextTag,
              let input = InputTag(rawValue: rawValue),
              let chainAsset = chainAsset,
              let polkaswapRemoteSettings = polkaswapRemoteSettings
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

        marketSource = SwapMarketSource(
            fromAssetId: swapFromChainAsset?.asset.currencyId,
            toAssetId: swapToChainAsset?.asset.currencyId,
            remoteSettings: polkaswapRemoteSettings
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
        loadingCollector.detailsReady = false
        view?.setButtonLoadingState(isLoading: true)

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
            detailsViewModel = provideDetailsViewModel(with: calcalatedAmounts)
        }
    }
}

// MARK: - PolkaswapDisclaimerModuleOutput

extension PolkaswapAdjustmentPresenter: PolkaswapDisclaimerModuleOutput {
    func disclaimerDidRead() {
        view?.setDisclaimer(visible: false)
    }
}
