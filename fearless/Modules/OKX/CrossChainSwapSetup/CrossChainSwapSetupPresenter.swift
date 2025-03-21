import Foundation
import SoraFoundation
import SSFModels
import BigInt

protocol CrossChainSwapSetupViewInput: ControllerBackedProtocol {
    func setButtonLoadingState(isLoading: Bool)
    func didReceive(originFeeViewModel: BalanceViewModelProtocol?)
    func didReceive(assetBalanceViewModel: AssetBalanceViewModelProtocol?)
    func didReceive(destinationAssetBalanceViewModel: AssetBalanceViewModelProtocol?)
    func didReceiveSwapFrom(amountInputViewModel: IAmountInputViewModel?)
    func didReceiveSwapTo(amountInputViewModel: IAmountInputViewModel?)
    func didReceiveViewModel(viewModel: CrossChainSwapViewModel?)
    func didReceiveError(viewModel: ErrorViewModel?)
    func didReceive(viewType: CrossChainSwapViewType)
}

protocol CrossChainSwapSetupInteractorInput: AnyObject, CrossChainBaseInteractorInput {
    func setup(with output: CrossChainSwapSetupInteractorOutput)
    func fetchBalance(for chainAssets: [ChainAsset]) async throws -> [ChainAssetKey: AccountInfo?]
    func fetchDexs(chainAsset: ChainAsset) async throws -> OKXResponse<OKXLiquiditySource>
    func fetchOkxChainAsset(nativeChainAsset: ChainAsset) async throws -> ChainAsset?
    func fetchDexTokenApproveAddress(chainAsset: ChainAsset) async throws -> String?
    func fetchAllowance(swapFromChainAsset: ChainAsset, dexTokenApproveAddress: String) async throws -> BigUInt?
}

final class CrossChainSwapSetupPresenter: CrossChainSwapBasePresenter<CrossChainSwapSetupInteractor> {
    // MARK: Private properties

    private weak var moduleOutput: CrossChainSwapSetupModuleOutput?
    private weak var view: CrossChainSwapSetupViewInput?
    private let router: CrossChainSwapSetupRouterInput
    private let viewModelFactory: CrossChainSwapSetupViewModelFactory
    private var initialChainAsset: ChainAsset?
    private var swapFromChainAsset: ChainAsset?
    private var swapToChainAsset: ChainAsset?
    private var swapVariant: SwapVariant = .desiredInput
    private var prices: [PriceData]?
    private var swap: CrossChainSwap?
    private let dataValidatingFactory: SendDataValidatingFactory
    private let logger: LoggerProtocol?

    private var swapFromInputResult: AmountInputResult?
    private var swapFromBalance: Decimal?
    private var swapToInputResult: AmountInputResult?
    private var swapToBalance: Decimal?
    private var utilityBalance: Decimal?
    private var destinationUtilityBalance: Decimal?
    private var selectedDexIds: [String]?
    private var dexs: [OKXDexQuote]?
    private var selectedSort: UInt8 = 0
    private var automaticallySelectedDexId: String?
    private var slippage: Decimal = 0.03
    private var allowance: BigUInt?
    private var dexTokenApproveAddress: String?
    private var dexTask: Task<Void, Never>?
    private var quotesTask: Task<Void, Never>?
    private var swapTask: Task<Void, Never>?

    private var timer: Timer?
    private var viewType: CrossChainSwapViewType = .undefined

    private var balanceMinusFee: Decimal? {
        guard swapFromChainAsset?.isUtility == true, let swapFromBalance, let originNetworkFee else {
            return swapFromBalance
        }

        return swapFromBalance - originNetworkFee
    }

    private var amountUnwrapped: String {
        guard let swapFromChainAsset = swapFromChainAsset,
              let swapToChainAsset = swapToChainAsset
        else {
            return ""
        }

        let amount: String
        if swapVariant == .desiredInput {
            guard let fromAmountDecimal = swapFromInputResult?.absoluteValue(from: balanceMinusFee ?? .zero) else {
                return ""
            }
            let bigUIntValue = fromAmountDecimal.toSubstrateAmount(
                precision: Int16(swapFromChainAsset.asset.precision)
            ) ?? .zero
            amount = String(bigUIntValue)

        } else {
            guard let toAmountDecimal = swapToInputResult?.absoluteValue(from: swapToBalance ?? .zero) else {
                return ""
            }
            let bigUIntValue = toAmountDecimal.toSubstrateAmount(
                precision: Int16(swapToChainAsset.asset.precision)
            ) ?? .zero
            amount = String(bigUIntValue)
        }

        return amount
    }
    
    private var mode: CrossChainFundsPermissionMode {
        guard let allowance else {
            return CrossChainFundsPermissionMode.none
        }
        
        let amount = BigUInt(string: amountUnwrapped)
        if allowance > amount.or(.zero) {
            return CrossChainFundsPermissionMode.none
        }
        
        if allowance > 0, allowance < amount.or(.zero), let dexTokenApproveAddress {
            return .revoke(dexTokenApproveAddress: dexTokenApproveAddress)
        }
        
        if allowance < amount.or(.zero), let dexTokenApproveAddress {
            return .approve(dexTokenApproveAddress: dexTokenApproveAddress)
        }
        
        return CrossChainFundsPermissionMode.none
    }

    // MARK: - Constructors

    init(
        interactor: CrossChainSwapSetupInteractor,
        router: CrossChainSwapSetupRouterInput,
        localizationManager: LocalizationManagerProtocol,
        viewModelFactory: CrossChainSwapSetupViewModelFactory,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset?,
        dataValidatingFactory: SendDataValidatingFactory,
        moduleOutput: CrossChainSwapSetupModuleOutput?,
        logger: LoggerProtocol?
    ) {
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.moduleOutput = moduleOutput
        self.logger = logger
        initialChainAsset = chainAsset

        super.init(wallet: wallet, interactor: interactor)

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
    
    private func updateViewType() {
        var isCrossChainSwap: Bool?
        
        if let swapFromChainAsset, let swapToChainAsset {
            isCrossChainSwap = swapFromChainAsset.chain.chainId != swapToChainAsset.chain.chainId
        }
        
        viewType = CrossChainSwapViewType(isCrossChainSwap: isCrossChainSwap)
        view?.didReceive(viewType: viewType)
    }

    private func reloadData() {
        fetchInfo()
        setupTimer()
    }
    
    private func fetchInfo() {
        guard
            let swapFromChainAsset,
            let swapToChainAsset,
            let utilityChainAsset = swapFromChainAsset.chain.utilityChainAssets().first,
            amountUnwrapped.isNotEmpty
        else {
            return
        }
        
        guard Decimal(string: amountUnwrapped) != 0 else {
            swapToInputResult = nil
            provideDestinationAssetViewModel()

            swap = nil
            
            provideViewModel()
            checkLoadingState()
            return
        }
        
        Task {
            do {
                let quote = try await interactor.fetchSwapSetupInfo(
                    chainAsset: swapFromChainAsset,
                    destinationChainAsset: swapToChainAsset,
                    amount: amountUnwrapped,
                    slippage: slippage.stringWithPointSeparator,
                    selectedDexIds: selectedDexIds
                )
                self.swap = quote.swap
                self.originNetworkFee = quote.swap.fee.flatMap {
                    BigUInt($0)
                }.flatMap {
                    Decimal.fromSubstrateAmount($0, precision: Int16(utilityChainAsset.asset.precision))
                }

                self.totalFiatFee = try await calculateTotalFiatFee(
                    for: quote.swap,
                    swapFromChainAsset: swapFromChainAsset,
                    originNetworkFee: originNetworkFee
                )
                
                if (selectedDexIds?.isEmpty).or(true) {
                    self.dexs = quote.swap.quotes
                }

                if selectedDexIds?.isEmpty != false {
                    automaticallySelectedDexId = quote.swap.selectedDexId
                }
                
                provideViewModel()
                provideFeeViewModel()
                provideDestinationInput()
                checkLoadingState()
            } catch {
                logger?.customError(error)

                self.originNetworkFee = nil
                self.swap = nil
                self.swapToInputResult = .absolute(0)
                self.totalFiatFee = nil
                provideViewModel()
                provideDestinationAssetViewModel()
                checkLoadingState()
                
                DispatchQueue.main.async { [weak self] in
                    self?.view?.setButtonLoadingState(isLoading: false)

                    if let error = error as? OKXDexError {
                        let message = error.decode(with: swapFromChainAsset)
                        switch error {
                        case .insufficientLiquidity:
                            self?.showLiquidityError()
                        default:
                            self?.showDefaultError(
                                title: R.string.localizable.commonImportant(preferredLanguages: self?.selectedLocale.rLanguages),
                                message: message ?? ""
                            )
                        }
                    } else {
                        self?.showReloadableError(
                            title: R.string.localizable.commonImportant(preferredLanguages: self?.selectedLocale.rLanguages),
                            message: error.localizedDescription
                        )
                    }
                }
            }
        }
    }

    private func provideDestinationInput() {
        guard let swap, let swapToChainAsset else {
            return
        }

        let receiveAmount = swap.toAmount.flatMap { BigUInt(string: $0) }
        let receiveAmountDecimal = receiveAmount.flatMap { Decimal.fromSubstrateAmount($0, precision: Int16(swapToChainAsset.asset.precision)) }

        swapToInputResult = .absolute(receiveAmountDecimal.or(.zero))
        provideDestinationAssetViewModel()
    }

    private func provideEmptyDestinationInput() {
        DispatchQueue.main.async { [weak self] in
            self?.view?.didReceive(destinationAssetBalanceViewModel: nil)
        }
    }

    func toggleSwapDirection() {
        if swapVariant == .desiredInput {
            swapVariant = .desiredOutput
        } else {
            swapVariant = .desiredInput
        }
    }

    private func runLoadingState() {
        view?.setButtonLoadingState(isLoading: true)
    }

    private func checkLoadingState() {
        let isReady = swap != nil && (swapFromChainAsset?.asset.isUtility == true || allowance != nil) && originNetworkFee != nil || swapToInputResult == nil

        DispatchQueue.main.async { [weak self] in
            self?.view?.setButtonLoadingState(isLoading: !isReady)
        }
    }
    
    private func provideFeeViewModel() {
        guard let swapFromChainAsset else {
            return
        }

        let viewModel = viewModelFactory.buildFeeViewModel(
            originNetworkFee: originNetworkFee,
            sourceChainAsset: swapFromChainAsset,
            wallet: wallet,
            locale: selectedLocale
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.view?.didReceive(originFeeViewModel: viewModel)
        }
    }

    private func provideViewModel() {
        guard let swap, let swapFromChainAsset, let swapToChainAsset else {
            DispatchQueue.main.async { [weak self] in
                self?.view?.didReceiveViewModel(viewModel: nil)
            }
            return
        }

        let viewModel = viewModelFactory.buildSwapViewModel(
            swap: swap,
            sourceChainAsset: swapFromChainAsset,
            targetChainAsset: swapToChainAsset,
            wallet: wallet,
            locale: selectedLocale,
            selectedDexIds: selectedDexIds,
            totalFiatFee: totalFiatFee,
            dexs: dexs,
            slippage: slippage
        )

        DispatchQueue.main.async { [weak self] in
            self?.view?.didReceiveViewModel(viewModel: viewModel)
        }
    }

    private func provideAssetViewModel(updateAmountInput: Bool = true) {
        let inputAmount = swapFromInputResult?
            .absoluteValue(from: balanceMinusFee ?? .zero)

        let balanceViewModelFactory = buildBalanceViewModelFactory(
            wallet: wallet,
            for: swapFromChainAsset
        )

        let assetBalanceViewModel = balanceViewModelFactory?.createAssetBalanceViewModel(
            inputAmount,
            balance: swapFromBalance,
            priceData: swapFromChainAsset?.asset.getPrice(for: wallet.selectedCurrency)
        ).value(for: selectedLocale)
        let inputViewModel = balanceViewModelFactory?
            .createBalanceInputViewModel(inputAmount)
            .value(for: selectedLocale)

        DispatchQueue.main.async { [weak self] in
            if updateAmountInput {
                self?.view?.didReceiveSwapFrom(amountInputViewModel: inputViewModel)
            }
            
            self?.view?.didReceive(assetBalanceViewModel: assetBalanceViewModel)
        }
    }

    private func provideDestinationAssetViewModel() {
        let inputAmount = swapToInputResult?
            .absoluteValue(from: swapToBalance ?? .zero)

        let balanceViewModelFactory = buildBalanceViewModelFactory(
            wallet: wallet,
            for: swapToChainAsset
        )

        let assetBalanceViewModel = balanceViewModelFactory?.createAssetBalanceViewModel(
            inputAmount,
            balance: swapToBalance,
            priceData: swapToChainAsset?.asset.getPrice(for: wallet.selectedCurrency)
        ).value(for: selectedLocale)
        let inputViewModel = balanceViewModelFactory?
            .createBalanceInputViewModel(inputAmount)
            .value(for: selectedLocale)

        DispatchQueue.main.async { [weak self] in
            self?.view?.didReceive(destinationAssetBalanceViewModel: assetBalanceViewModel)
            self?.view?.didReceiveSwapTo(amountInputViewModel: inputViewModel)
        }
    }

    private func buildBalanceViewModelFactory(
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

    private func subscribeOnBalance() {
        let chainAssets = [swapFromChainAsset, swapToChainAsset, swapFromChainAsset?.chain.utilityChainAssets().first, swapToChainAsset?.chain.utilityChainAssets().first].compactMap { $0 }

        Task {
            do {
                let accountInfos = try await interactor.fetchBalance(for: chainAssets)
                accountInfos.forEach {
                    handle(accountInfo: $0.value, for: $0.key)
                }
                fetchInfo()
            } catch {
                router.present(error: error, from: view, locale: selectedLocale)
            }
        }
    }

    private func didSelectSourceChainAsset(_ chainAsset: ChainAsset?) {
        swapFromChainAsset = chainAsset
        provideAssetViewModel()

        DispatchQueue.main.async { [weak self] in
            self?.view?.didReceiveViewModel(viewModel: nil)
        }

        subscribeOnBalance()
        fetchAllowance()
        fetchInfo()
    }

    private func didSelectSoraChainAsset(_ chainAsset: ChainAsset?) {
        moduleOutput?.didSwitchToPolkaswap(with: chainAsset)
    }

    private func didSelectDestinationChainAsset(_ chainAsset: ChainAsset?) {
        swapToChainAsset = chainAsset
        swapToInputResult = nil
        provideDestinationAssetViewModel()
        view?.didReceiveViewModel(viewModel: nil)
        updateViewType()
        subscribeOnBalance()
        fetchInfo()

    }

    private func handle(accountInfo: AccountInfo?, for chainAssetKey: ChainAssetKey) {
        if let swapToChainAsset, let utilityChainAsset = swapToChainAsset.chain.utilityChainAssets().first, chainAssetKey == utilityChainAsset.uniqueKey(for: wallet) {
            destinationUtilityBalance = accountInfo.map {
                Decimal.fromSubstrateAmount(
                    $0.data.sendAvailable,
                    precision: Int16(utilityChainAsset.asset.precision)
                )
            } ?? .zero
        }
        
        if let swapFromChainAsset, let utilityChainAsset = swapFromChainAsset.chain.utilityChainAssets().first, chainAssetKey == utilityChainAsset.uniqueKey(for: wallet) {
            utilityBalance = accountInfo.map {
                Decimal.fromSubstrateAmount(
                    $0.data.sendAvailable,
                    precision: Int16(utilityChainAsset.asset.precision)
                )
            } ?? .zero
        }

        if let swapFromChainAsset, swapFromChainAsset.uniqueKey(for: wallet) == chainAssetKey {
            swapFromBalance = accountInfo.map {
                Decimal.fromSubstrateAmount(
                    $0.data.sendAvailable,
                    precision: Int16(swapFromChainAsset.asset.precision)
                )
            } ?? .zero
            provideAssetViewModel()
        }

        if let swapToChainAsset, swapToChainAsset.uniqueKey(for: wallet) == chainAssetKey {
            swapToBalance = accountInfo.map {
                Decimal.fromSubstrateAmount(
                    $0.data.sendAvailable,
                    precision: Int16(swapToChainAsset.asset.precision)
                )
            } ?? .zero
            provideDestinationAssetViewModel()
        }
    }

    @objc private func handleTimerTick() {
        fetchInfo()
    }

    private func setupTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: 15.0,
            target: self,
            selector: #selector(
                handleTimerTick
            ),
            userInfo: nil,
            repeats: true
        )
    }

    private func showDefaultError(title: String, message: String) {
        let errorViewModel = ErrorViewModel(
            title: title,
            message: message,
            actionTitle: nil,
            actionHandler: nil
        )
        view?.didReceiveError(viewModel: errorViewModel)
    }
    
    private func showReloadableError(title: String, message: String) {
        let errorViewModel = ErrorViewModel(
            title: title,
            message: message,
            actionTitle: R.string.localizable.commonRetry(preferredLanguages: selectedLocale.rLanguages),
            actionHandler: { [weak self] in
                DispatchQueue.main.async {
                    self?.view?.didReceiveError(viewModel: nil)
                }
                
                self?.fetchInfo()
            }
        )
        view?.didReceiveError(viewModel: errorViewModel)
    }

    private func showLiquidityError() {
        let errorViewModel = ErrorViewModel(
            title: R.string.localizable.commonImportant(preferredLanguages: selectedLocale.rLanguages),
            message: R.string.localizable.swapLiquidityError(preferredLanguages: selectedLocale.rLanguages),
            actionTitle: R.string.localizable.selectLiquidityTitle(preferredLanguages: selectedLocale.rLanguages)
        ) {
            self.didTapLiquiditySources()
        }
        view?.didReceiveError(viewModel: errorViewModel)
    }

    private func fetchInitialChainAsset() {
        guard let initialChainAsset else {
            return
        }

        Task {
            let chainAsset = try await interactor.fetchOkxChainAsset(nativeChainAsset: initialChainAsset)
            didSelectSourceChainAsset(chainAsset)
        }
    }
    
    private func fetchAllowance() {
        guard let chainAsset = swapFromChainAsset else {
            return
        }
        
        guard chainAsset.isUtility == false else {
            checkLoadingState()
            return
        }

        Task {
            do {
                guard let dexTokenApproveAddress = try await self.interactor.fetchDexTokenApproveAddress(chainAsset: chainAsset) else {
                    allowance = .zero
                    checkLoadingState()
                    return
                }
                
                self.allowance = try await interactor.fetchAllowance(swapFromChainAsset: chainAsset, dexTokenApproveAddress: dexTokenApproveAddress)
                self.dexTokenApproveAddress = dexTokenApproveAddress
                
                checkLoadingState()
            } catch {
                logger?.customError(error)
                try await Task.sleep(nanoseconds: 3_000_000_000)
                fetchAllowance()
            }
        }
    }
    
    private func proceedToNextScreen() {
        guard let swapFromChainAsset, let swapToChainAsset, let swap else {
            return
        }
        
        let automaticallySelectedDexIds = automaticallySelectedDexId.flatMap { [$0] }
        let selectedDexIds = selectedDexIds ?? automaticallySelectedDexIds
        let parameters = CrossChainSwapParameters(
            swapFromChainAsset: swapFromChainAsset,
            swapToChainAsset: swapToChainAsset,
            wallet: wallet,
            amount: amountUnwrapped,
            selectedDexIds: selectedDexIds,
            swap: swap,
            slippage: slippage
        )
              
        switch mode {
        case CrossChainFundsPermissionMode.none:
            self.router.presentConfirm(
                crossChainSwapParameters: parameters,
                from: self.view
            )
        case .approve, .revoke:
            self.router.presentFundsPermission(
                mode: mode,
                crossChainSwapParameters: parameters,
                from: view
            )
        }
    }
}

// MARK: - CrossChainSwapSetupViewOutput

extension CrossChainSwapSetupPresenter: CrossChainSwapSetupViewOutput {
    func handleViewWillDisappear() {
        timer?.invalidate()
        timer = nil
    }

    func handleViewWillAppear() {
        reloadData()
        allowance = nil
        fetchAllowance()
    }

    func handleDismissingSwipe() {
        timer?.invalidate()
        timer = nil
    }

    func selectFromAmountPercentage(_ percentage: Float) {
        timer?.invalidate()
        runLoadingState()

        swapVariant = .desiredInput
        swapFromInputResult = .rate(Decimal(Double(percentage)))
        provideAssetViewModel()
        reloadData()
    }

    func updateFromAmount(_ newValue: Decimal) {
        timer?.invalidate()
        runLoadingState()

        swapVariant = .desiredInput
        swapFromInputResult = .absolute(newValue)
        provideAssetViewModel(updateAmountInput: false)
        reloadData()
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
        provideAssetViewModel()
        provideDestinationAssetViewModel()

        reloadData()
    }

    func didTapSelectFromAsset() {
        router.showSelectAsset(
            from: view,
            wallet: wallet,
            output: self,
            flow: .okxSource,
            selectedChainAsset: swapFromChainAsset,
            filter: { $0.chainAssetId != self.swapToChainAsset?.chainAssetId }
        )
    }

    func didTapSelectToAsset() {
        guard let swapFromChainAsset else {
            return
        }

        router.showSelectAsset(
            from: view,
            wallet: wallet,
            output: self,
            flow: .okxDestination(sourceChainId: swapFromChainAsset.chain.chainId),
            selectedChainAsset: swapToChainAsset,
            filter: { $0.chainAssetId != swapFromChainAsset.chainAssetId && $0.chain.chainId == swapFromChainAsset.chain.chainId }
        )
    }

    func didLoad(view: CrossChainSwapSetupViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideAssetViewModel()
        subscribeOnBalance()
        fetchInitialChainAsset()
    }

    func didTapBackButton() {
        timer?.invalidate()
        router.dismiss(view: view)
    }

    func didTapContinueButton() {
        guard let swapFromChainAsset else {
            return
        }

        let balance: BalanceType = swapFromChainAsset.asset.isUtility ? .utility(balance: swapFromBalance) : .orml(balance: swapFromBalance, utilityBalance: utilityBalance)
        DataValidationRunner(validators: [
            dataValidatingFactory.has(fee: originNetworkFee, locale: selectedLocale, onError: {}),
            dataValidatingFactory.canPayFeeAndAmount(
                balanceType: balance,
                feeAndTip: originNetworkFee,
                sendAmount: swapFromInputResult?.absoluteValue(from: swapFromBalance.or(.zero)),
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            self?.proceedToNextScreen()
        }
    }

    func didTapLiquiditySources() {
        guard
            let fromAmountDecimal = swapFromInputResult?.absoluteValue(from: balanceMinusFee ?? .zero),
            let swapFromChainAsset,
            let swapToChainAsset
        else {
            return
        }
        let bigUIntValue = fromAmountDecimal.toSubstrateAmount(
            precision: Int16(swapFromChainAsset.asset.precision)
        ) ?? .zero
        let amount = String(bigUIntValue)

        router.presentLiquiditySourcesSelection(
            sourceChainAsset: swapFromChainAsset,
            destinationChainAsset: swapToChainAsset,
            amount: amount,
            wallet: wallet,
            from: view,
            moduleOutput: self,
            selectedDexIds: selectedDexIds
        )
    }

    func didTapSelectRoute() {
        guard
            let fromAmountDecimal = swapFromInputResult?.absoluteValue(from: balanceMinusFee ?? .zero),
            let swapFromChainAsset,
            let swapToChainAsset,
            swapFromChainAsset.chain.chainId != swapToChainAsset.chain.chainId
        else {
            return
        }
        let bigUIntValue = fromAmountDecimal.toSubstrateAmount(
            precision: Int16(swapFromChainAsset.asset.precision)
        ) ?? .zero
        let amount = String(bigUIntValue)

        router.presentBridgeSelection(
            sourceChainAsset: swapFromChainAsset,
            destinationChainAsset: swapToChainAsset,
            amount: amount,
            wallet: wallet,
            from: view,
            moduleOutput: self,
            selectedBridgeId: selectedDexIds?.first
        )
    }
    
    func didTapRouteInfoButton() {
        router.presentInfo(
            message: R.string.localizable.crossChainOkxRouteDescription(preferredLanguages: selectedLocale.rLanguages),
            title: R.string.localizable.crossChainOkxRouteTitle(preferredLanguages: selectedLocale.rLanguages),
            from: view
        )
    }
}

// MARK: - CrossChainSwapSetupInteractorOutput

extension CrossChainSwapSetupPresenter: CrossChainSwapSetupInteractorOutput {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset) {
        switch result {
        case let .success(accountInfo):
            if chainAsset == swapFromChainAsset?.chain.utilityChainAssets().first {
                utilityBalance = accountInfo.map {
                    Decimal.fromSubstrateAmount(
                        $0.data.sendAvailable,
                        precision: Int16(chainAsset.asset.precision)
                    )
                } ?? .zero
            }
            if swapFromChainAsset == chainAsset {
                swapFromBalance = accountInfo.map {
                    Decimal.fromSubstrateAmount(
                        $0.data.sendAvailable,
                        precision: Int16(chainAsset.asset.precision)
                    )
                } ?? .zero
                provideAssetViewModel()
            }
            if swapToChainAsset == chainAsset {
                swapToBalance = accountInfo.map {
                    Decimal.fromSubstrateAmount(
                        $0.data.sendAvailable,
                        precision: Int16(chainAsset.asset.precision)
                    )
                } ?? .zero
                provideDestinationAssetViewModel()
            }
        case let .failure(error):
            router.present(error: error, from: view, locale: selectedLocale)
        }

        reloadData()
    }
}

// MARK: - Localizable

extension CrossChainSwapSetupPresenter: Localizable {
    func applyLocalization() {}
}

extension CrossChainSwapSetupPresenter: CrossChainSwapSetupModuleInput {
    func didSelect(sourceChainAsset: ChainAsset?) {
        allowance = nil
        dexTokenApproveAddress = nil
        didSelectSourceChainAsset(sourceChainAsset)
        fetchAllowance()
    }
}

extension CrossChainSwapSetupPresenter: SelectAssetModuleOutput {
    func assetSelection(didCompleteWith chainAsset: ChainAsset?, contextTag: Int?) {
        guard let chainAsset else {
            return
        }
        
        if contextTag == 0 {
            if chainAsset.chain.isSora == true {
                didSelectSoraChainAsset(chainAsset)
            } else {
                didSelectSourceChainAsset(chainAsset)
            }
        }

        if contextTag == 1 {
            didSelectDestinationChainAsset(chainAsset)
        }

        reloadData()
    }
}

extension CrossChainSwapSetupPresenter: DexListModuleOutput {
    func didUpdateSelectedDexIds(_ selectedDexIds: [String]?) {
        self.selectedDexIds = selectedDexIds
        provideViewModel()
        fetchInfo()
    }
    
    func didSelectBridge(id: String?) {
        self.selectedDexIds = [id].compactMap { $0 }
        provideViewModel()
        fetchInfo()
    }
}

extension CrossChainSwapSetupPresenter: BridgeListModuleOutput {
    func didUpdateSelectedSort(_ sort: UInt8) {
        selectedSort = sort
        provideViewModel()
        fetchInfo()
    }
}
