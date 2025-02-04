import Foundation
import SoraFoundation
import SSFModels
import BigInt

protocol CrossChainSwapSetupViewInput: ControllerBackedProtocol {
    func setButtonLoadingState(isLoading: Bool)
    func didReceive(originFeeViewModel: LocalizableResource<BalanceViewModelProtocol>?)
    func didReceive(assetBalanceViewModel: AssetBalanceViewModelProtocol?)
    func didReceive(destinationAssetBalanceViewModel: AssetBalanceViewModelProtocol?)
    func didReceiveSwapFrom(amountInputViewModel: IAmountInputViewModel?)
    func didReceiveSwapTo(amountInputViewModel: IAmountInputViewModel?)
    func didReceiveViewModel(viewModel: CrossChainSwapViewModel?)
    func didReceiveError(viewModel: ErrorViewModel?)
}

protocol CrossChainSwapSetupInteractorInput: AnyObject, CrossChainBaseInteractorInput {
    func setup(with output: CrossChainSwapSetupInteractorOutput)
    func fetchBalance(for chainAssets: [ChainAsset]) async throws -> [ChainAssetKey: AccountInfo?]
    func fetchDexs(chainAsset: ChainAsset) async throws -> OKXResponse<OKXLiquiditySource>
    func fetchOkxChainAsset(nativeChainAsset: ChainAsset) async throws -> ChainAsset?
}

final class CrossChainSwapSetupPresenter {
    // MARK: Private properties

    private weak var moduleOutput: CrossChainSwapSetupModuleOutput?
    private weak var view: CrossChainSwapSetupViewInput?
    private let router: CrossChainSwapSetupRouterInput
    private let interactor: CrossChainSwapSetupInteractorInput
    private let viewModelFactory: CrossChainSwapSetupViewModelFactory
    private let wallet: MetaAccountModel
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
    private var selectedDexIds: [String]?
    private var dexs: [OKXDexQuote]?
    private var selectedSort: UInt8 = 0
    private var fromNetworkFee: Decimal?
    private var automaticallySelectedDexId: String?
    private var slippage: Decimal = 0.01

    private var dexTask: Task<Void, Never>?
    private var quotesTask: Task<Void, Never>?
    private var swapTask: Task<Void, Never>?

    private var totalFiatFee: Decimal?

    private var timer: Timer?

    private var balanceMinusFee: Decimal? {
        guard swapFromChainAsset?.isUtility == true, let swapFromBalance, let fromNetworkFee else {
            return swapFromBalance
        }

        return swapFromBalance - fromNetworkFee
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

    // MARK: - Constructors

    init(
        interactor: CrossChainSwapSetupInteractorInput,
        router: CrossChainSwapSetupRouterInput,
        localizationManager: LocalizationManagerProtocol,
        viewModelFactory: CrossChainSwapSetupViewModelFactory,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset?,
        dataValidatingFactory: SendDataValidatingFactory,
        moduleOutput: CrossChainSwapSetupModuleOutput?,
        logger: LoggerProtocol?
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.wallet = wallet
        initialChainAsset = chainAsset
        self.dataValidatingFactory = dataValidatingFactory
        self.moduleOutput = moduleOutput
        self.logger = logger

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func reloadData() {
        fetchInfo()

        setupTimer()
    }

    private func fetchInfo() {
        guard let swapFromChainAsset, let swapToChainAsset, let utilityChainAsset = swapFromChainAsset.chain.utilityChainAssets().first, amountUnwrapped.isNotEmpty else {
            return
        }
        Task {
            do {
                let swapSetupInfo = try await interactor.fetchSwapSetupInfo(
                    chainAsset: swapFromChainAsset,
                    destinationChainAsset: swapToChainAsset,
                    amount: amountUnwrapped,
                    slippage: slippage.stringWithPointSeparator,
                    selectedDexIds: selectedDexIds
                )

                self.swap = swapSetupInfo?.swap
                if (selectedDexIds?.isEmpty).or(true) {
                    self.dexs = swapSetupInfo?.swap?.quotes
                }
                
                self.fromNetworkFee = swapSetupInfo?.fee.flatMap { Decimal.fromSubstrateAmount($0, precision: Int16(utilityChainAsset.asset.precision)) }

                if selectedDexIds?.isEmpty != false {
                    automaticallySelectedDexId = swapSetupInfo?.swap?.selectedDexId
                }
                calculateTotalFiatFee()
                provideViewModel()
                provideDestinationInput()
                checkLoadingState()
            } catch {
                logger?.customError(error)

                self.fromNetworkFee = nil
                self.swap = nil
                self.swapToInputResult = .absolute(0)

                calculateTotalFiatFee()
                provideViewModel()
                provideDestinationAssetViewModel()
                checkLoadingState()
                DispatchQueue.main.async { [weak self] in
                    self?.view?.setButtonLoadingState(isLoading: false)

                    if let error = error as? OKXDexError, let view = self?.view {
                        let message = error.decode(with: swapFromChainAsset)
//                        self?.router.presentError(for: "", message: message ?? "", view: view, locale: self?.selectedLocale)
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
                        self?.router.present(error: error, from: self?.view, locale: self?.selectedLocale)
                    }
                }
            }
        }
    }

    private func fetchDexs() {
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
        let isReady = swap != nil

        DispatchQueue.main.async { [weak self] in
            self?.view?.setButtonLoadingState(isLoading: !isReady)
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

    private func provideAssetViewModel() {
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
            self?.view?.didReceiveSwapFrom(amountInputViewModel: inputViewModel)
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
        let chainAssets = [swapFromChainAsset, swapToChainAsset, swapFromChainAsset?.chain.utilityChainAssets().first].compactMap { $0 }

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
        fetchInfo()
        fetchDexs()
    }

    private func didSelectSoraChainAsset(_ chainAsset: ChainAsset?) {
        moduleOutput?.didSwitchToPolkaswap(with: chainAsset)
    }

    private func didSelectDestinationChainAsset(_ chainAsset: ChainAsset?) {
        swapToChainAsset = chainAsset
        swapToInputResult = nil
        provideDestinationAssetViewModel()
        view?.didReceiveViewModel(viewModel: nil)

        subscribeOnBalance()
        fetchInfo()
        fetchDexs()

    }

    private func handle(accountInfo: AccountInfo?, for chainAssetKey: ChainAssetKey) {
        if let swapFromChainAsset, chainAssetKey == swapFromChainAsset.chain.utilityChainAssets().first?.uniqueKey(for: wallet) {
            utilityBalance = accountInfo.map {
                Decimal.fromSubstrateAmount(
                    $0.data.sendAvailable,
                    precision: Int16(swapFromChainAsset.asset.precision)
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

    private func calculateTotalFiatFee() {
        guard let swap, let sourceChainAsset = swapFromChainAsset else {
            self.totalFiatFee = nil
            return
        }

        let sourceChainFeeNativeToken = sourceChainAsset.chain.utilityChainAssets().first
        let fee: Decimal? = swap.fee
            .flatMap { BigUInt(string: $0) }
            .flatMap {
                guard let sourceChainFeeNativeToken else {
                    return nil
                }
                return Decimal.fromSubstrateAmount($0, precision: Int16(sourceChainFeeNativeToken.asset.precision))
            }

        let sourceChainFiatFee: Decimal? = fee.flatMap { fee in
            guard
                let sourceChainFeeNativeToken,
                let price = sourceChainFeeNativeToken.asset.getPrice(for: wallet.selectedCurrency),
                let priceDecimal = Decimal(string: price.price)
            else {
                return nil
            }
            return fee * priceDecimal
        }

        let sourceChainAssets = sourceChainAsset.chain.chainAssets
        let crossChainFeeToken = sourceChainAssets.first(where: { $0.asset.currencyId == swap.contractAddress })
        let crossChainFeeNativeToken = sourceChainAsset.chain.chainAssets.first(where: { $0.asset.id == crossChainFeeToken?.asset.id })
        let crossChainFee: Decimal? = swap.crossChainFee.flatMap { BigUInt(string: $0) }.flatMap {
            guard let crossChainFeeNativeToken else {
                return nil
            }

            return Decimal.fromSubstrateAmount($0, precision: Int16(crossChainFeeNativeToken.asset.precision))
        }

        let crossChainFiatFee: Decimal? = crossChainFee.flatMap { fee in
            guard let crossChainFeeNativeToken,
                  let price = crossChainFeeNativeToken.asset.getPrice(for: wallet.selectedCurrency),
                  let priceDecimal = Decimal(string: price.price)
            else {
                return nil
            }

            return fee * priceDecimal
        }

        let fiatFee = swap.fiatFee.flatMap { Decimal(string: $0) }

        let totalFiatFee = [crossChainFiatFee, sourceChainFiatFee, fiatFee].compactMap { $0 }.reduce(0, +)

        self.totalFiatFee = totalFiatFee
    }

    @objc private func handleTimerTick() {
        fetchInfo()
    }

    private func setupTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 15.0, target: self, selector: #selector(handleTimerTick), userInfo: nil, repeats: true)
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
}

// MARK: - CrossChainSwapSetupViewOutput

extension CrossChainSwapSetupPresenter: CrossChainSwapSetupViewOutput {
    func handleViewWillDisappear() {
        timer?.invalidate()
        timer = nil
    }

    func handleViewWillAppear() {
        reloadData()
    }

    func handleDismissingSwipe() {
        timer?.invalidate()
        timer = nil
    }

    func selectFromAmountPercentage(_ percentage: Float) {
        runLoadingState()

        swapVariant = .desiredInput
        swapFromInputResult = .rate(Decimal(Double(percentage)))
        provideAssetViewModel()
        reloadData()
    }

    func updateFromAmount(_ newValue: Decimal) {
        runLoadingState()

        swapVariant = .desiredInput
        swapFromInputResult = .absolute(newValue)
        provideAssetViewModel()
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
            filter: { $0.chainAssetId != swapFromChainAsset.chainAssetId }
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
        guard let swapFromChainAsset, let swapToChainAsset, let swap else {
            return
        }

        let automaticallySelectedDexIds = automaticallySelectedDexId.flatMap { [$0] }

        let balance: BalanceType = swapFromChainAsset.asset.isUtility ? .utility(balance: swapFromBalance) : .orml(balance: swapFromBalance, utilityBalance: utilityBalance)
        DataValidationRunner(validators: [
            dataValidatingFactory.has(fee: fromNetworkFee, locale: selectedLocale, onError: {}),
            dataValidatingFactory.canPayFeeAndAmount(
                balanceType: balance,
                feeAndTip: fromNetworkFee,
                sendAmount: swapFromInputResult?.absoluteValue(from: swapFromBalance.or(.zero)),
                locale: selectedLocale
            )
        ]).runValidation { [weak self, swap] in
            guard let self else {
                return
            }

            self.router.presentConfirm(
                swapFromChainAsset: swapFromChainAsset,
                swapToChainAsset: swapToChainAsset,
                wallet: self.wallet,
                amount: amountUnwrapped,
                selectedDexIds: selectedDexIds ?? automaticallySelectedDexIds,
                swap: swap,
                slippage: slippage,
                from: self.view
            )
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
            selectedSort: selectedSort
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
        didSelectSourceChainAsset(sourceChainAsset)
        fetchDexs()
    }
}

extension CrossChainSwapSetupPresenter: SelectAssetModuleOutput {
    func assetSelection(didCompleteWith chainAsset: ChainAsset?, contextTag: Int?) {
        if contextTag == 0 {
            if chainAsset?.chain.isSora == true {
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
        fetchDexs()
    }
}

extension CrossChainSwapSetupPresenter: BridgeListModuleOutput {
    func didUpdateSelectedSort(_ sort: UInt8) {
        selectedSort = sort
        provideViewModel()
        fetchInfo()
        fetchDexs()
    }
}
