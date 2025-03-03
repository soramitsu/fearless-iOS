import Foundation
import SoraFoundation
import SSFModels
import BigInt
import Web3

protocol CrossChainSwapConfirmViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(swapAmountInfoViewModel: SwapAmountInfoViewModel)
    func didReceive(viewModel: CrossChainSwapViewModel)
    func didReceive(doubleImageViewModel: PolkaswapDoubleSymbolViewModel)
    func didReceive(feeViewModel: TitleMultiValueViewModel?)
    func setButtonLoadingState(isLoading: Bool)
    func didReceiveError(viewModel: ErrorViewModel?)
}

protocol CrossChainSwapConfirmInteractorInput: AnyObject, CrossChainBaseInteractor {
    func setup(with output: CrossChainSwapConfirmInteractorOutput)
    func subscribeOnBalance(for chainAssets: [ChainAsset])
    func estimateFee(tx: CrossChainTx) async throws -> BigUInt
    func confirmSwap(tx: CrossChainTx) async throws -> String
    func checkTransactionSucceed(approveTxHash: String) async throws -> Bool
}

final class CrossChainSwapConfirmPresenter {
    // MARK: Private properties

    private weak var view: CrossChainSwapConfirmViewInput?
    private let router: CrossChainSwapConfirmRouterInput
    private let interactor: CrossChainSwapConfirmInteractorInput
    private let viewModelFactory: CrossChainSwapConfirmViewModelFactory
    private let dataValidatingFactory: SendDataValidatingFactory
    private let logger: LoggerProtocol?

    private let swapFromChainAsset: ChainAsset
    private let swapToChainAsset: ChainAsset
    private var swap: CrossChainSwap
    private let wallet: MetaAccountModel

    private var swapFromBalance: Decimal?
    private var swapToBalance: Decimal?
    private var utilityBalance: Decimal?
    private var totalFiatFee: Decimal?
    private var timer: Timer?
    private let amount: String
    private let selectedDexIds: [String]?
    private var fromNetworkFee: Decimal?
    private var crossChainTx: CrossChainTx?
    private var slippage: Decimal
    private var approveTxHash: String?
    private var feeErrorCounter: Int = 0

    // MARK: - Constructors

    init(
        interactor: CrossChainSwapConfirmInteractorInput,
        router: CrossChainSwapConfirmRouterInput,
        localizationManager: LocalizationManagerProtocol,
        swapFromChainAsset: ChainAsset,
        swapToChainAsset: ChainAsset,
        swap: CrossChainSwap,
        viewModelFactory: CrossChainSwapConfirmViewModelFactory,
        wallet: MetaAccountModel,
        dataValidatingFactory: SendDataValidatingFactory,
        amount: String,
        selectedDexIds: [String]?,
        logger: LoggerProtocol?,
        slippage: Decimal,
        approveTxHash: String?
    ) {
        self.interactor = interactor
        self.router = router
        self.swapFromChainAsset = swapFromChainAsset
        self.swapToChainAsset = swapToChainAsset
        self.swap = swap
        self.viewModelFactory = viewModelFactory
        self.wallet = wallet
        self.dataValidatingFactory = dataValidatingFactory
        self.amount = amount
        self.selectedDexIds = selectedDexIds
        self.logger = logger
        self.slippage = slippage
        self.approveTxHash = approveTxHash

        self.localizationManager = localizationManager
    }

    // MARK: - Data Fetching

    private func fetchCrossChainTx() {
        Task {
            do {
                let crossChainTx = try await interactor.fetchTransactionData(
                    chainAsset: swapFromChainAsset,
                    destinationChainAsset: swapToChainAsset,
                    amount: amount,
                    slippage: slippage.stringWithPointSeparator,
                    selectedDexIds: selectedDexIds
                )

                self.crossChainTx = crossChainTx
                refreshFee()
            } catch {
                logger?.customError(error)
            }
        }
    }
    
    private func checkApproveTransactionSucceed(approveTxHash: String) {
        Task {
            do {
                let isSucceed = try await interactor.checkTransactionSucceed(approveTxHash: approveTxHash)
                await MainActor.run {
                    view?.didReceiveError(viewModel: nil)
                }
                
                if isSucceed {
                    self.approveTxHash = nil
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + DispatchTimeInterval.seconds(CrossChain.Constants.approveTxSecondsDelay)) { [weak self] in
                        self?.refreshFee()
                    }
                } else {
                    showDefaultError(title: "Approve transaction failed", message: "Please return back and try again")
                }
            } catch {
                print(error)
                DispatchQueue.main.asyncAfter(deadline: .now() + DispatchTimeInterval.seconds(CrossChain.Constants.approveTxSecondsDelay)) { [weak self] in
                    self?.checkApproveTransactionSucceed(approveTxHash: approveTxHash)
                }
            }
        }
    }

    private func refreshFee() {
        if let approveTxHash {
            showDefaultError(
                title: R.string.localizable.approveTransactionPendingTitle(preferredLanguages: selectedLocale.rLanguages),
                message: R.string.localizable.blockchainTransactionPendingDescription(preferredLanguages: selectedLocale.rLanguages)
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + DispatchTimeInterval.seconds(CrossChain.Constants.approveTxSecondsDelay)) { [weak self] in
                self?.checkApproveTransactionSucceed(approveTxHash: approveTxHash)
            }
            return
        }
        
        guard let utilityChainAsset = swapFromChainAsset.chain.utilityChainAssets().first, let crossChainTx else {
            return
        }

        Task {
            do {
                await MainActor.run {
                    view?.setButtonLoadingState(isLoading: true)
                }

                let fee = try await interactor.estimateFee(tx: crossChainTx)
                self.fromNetworkFee = Decimal.fromSubstrateAmount(fee, precision: Int16(utilityChainAsset.asset.precision))

                await MainActor.run {
                    view?.setButtonLoadingState(isLoading: false)
                }
            } catch {
                feeErrorCounter += 1
                if feeErrorCounter < 3 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + DispatchTimeInterval.seconds(CrossChain.Constants.refreshSecondsDelay)) { [weak self] in
                        self?.refreshFee()
                    }
                    return
                }
                
                await MainActor.run {
                    self.view?.setButtonLoadingState(isLoading: false)
                }
                logger?.customError(error)
                
                if let rpcError = error as? RPCResponse<EthereumQuantity>.Error {
                    showReloadableError(
                        title: R.string.localizable.commonImportant(preferredLanguages: selectedLocale.rLanguages),
                        message: rpcError.message
                    )
                } else {
                    showReloadableError(
                        title: R.string.localizable.commonImportant(preferredLanguages: selectedLocale.rLanguages),
                        message: error.localizedDescription
                    )
                }
            }
        }
    }

    private func fetchInfo() {
        Task {
            do {
                let swapSetupInfo = try await interactor.fetchSwapSetupInfo(
                    chainAsset: swapFromChainAsset,
                    destinationChainAsset: swapToChainAsset,
                    amount: amount,
                    slippage: slippage.stringWithPointSeparator,
                    selectedDexIds: selectedDexIds
                )

                if let swap = swapSetupInfo?.swap {
                    self.swap = swap
                }

                calculateTotalFiatFee()
                provideViewModel()
            } catch {
                logger?.customError(error)

                calculateTotalFiatFee()
                provideViewModel()
                
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }
                    
                    self.view?.setButtonLoadingState(isLoading: false)

                    if let error = error as? OKXDexError{
                        let message = error.decode(with: self.swapFromChainAsset)
                        switch error {
                        default:
                            self.showDefaultError(
                                title: R.string.localizable.commonImportant(preferredLanguages: self.selectedLocale.rLanguages),
                                message: message ?? ""
                            )
                        }
                    } else {
                        self.router.present(error: error, from: self.view, locale: self.selectedLocale)
                    }
                }

            }
        }
    }

    private func subscribeOnBalance() {
        let chainAssets: [ChainAsset] = [swapFromChainAsset, swapToChainAsset, swapFromChainAsset.chain.utilityChainAssets().first].compactMap { $0 }
        interactor.subscribeOnBalance(for: chainAssets)
    }

    // MARK: View Models

    private func provideViewModel() {
        let viewModel = viewModelFactory.buildSwapViewModel(
            swap: swap,
            sourceChainAsset: swapFromChainAsset,
            targetChainAsset: swapToChainAsset,
            wallet: wallet,
            locale: selectedLocale,
            selectedDexIds: nil,
            totalFiatFee: totalFiatFee,
            dexs: nil,
            slippage: slippage
        )

        DispatchQueue.main.async { [weak self] in
            self?.view?.didReceive(viewModel: viewModel)
        }
    }

    private func provideAmountInfoViewModel() {
        let viewModel = viewModelFactory.buildSwapAmountInfoViewModel(
            swapFromChainAsset: swapFromChainAsset,
            swapToChainAsset: swapToChainAsset,
            swap: swap,
            locale: selectedLocale
        )

        view?.didReceive(swapAmountInfoViewModel: viewModel)
    }

    private func provideImageViewModel() {
        let viewModel = viewModelFactory.buildDoubleImageViewModel(
            swapFromChainAsset: swapFromChainAsset,
            swapToChainAsset: swapToChainAsset
        )

        view?.didReceive(doubleImageViewModel: viewModel)
    }

    // MARK: Private methods

    private func calculateTotalFiatFee() {
        let utilityChainAsset = swapFromChainAsset.chain.utilityChainAssets().first ?? swapFromChainAsset
        let fee = swap.fee.flatMap { BigUInt(string: $0) }.flatMap { Decimal.fromSubstrateAmount($0, precision: Int16(utilityChainAsset.asset.precision)) }

        let sourceChainFiatFee: Decimal? = fee.flatMap { fee in
            guard
                let price = utilityChainAsset.asset.getPrice(for: wallet.selectedCurrency),
                let priceDecimal = Decimal(string: price.price)
            else {
                return nil
            }
            return fee * priceDecimal
        }

        let sourceChainAssets = swapFromChainAsset.chain.chainAssets
        let crossChainFeeToken = sourceChainAssets.first(where: { $0.asset.currencyId == swap.contractAddress })
        let crossChainFeeNativeToken = swapFromChainAsset.chain.chainAssets.first(where: { $0.asset.id == crossChainFeeToken?.asset.id })
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
        let totalFiatString = "\(wallet.selectedCurrency.symbol) \(totalFiatFee.string(maximumFractionDigits: 8))"
        let feeViewModel = TitleMultiValueViewModel(title: totalFiatString, subtitle: nil)

        DispatchQueue.main.async { [weak self] in
            self?.view?.didReceive(feeViewModel: feeViewModel)
        }
    }
    
    private func showDefaultError(title: String, message: String) {
        let errorViewModel = ErrorViewModel(
            title: title,
            message: message,
            actionTitle: nil,
            actionHandler: nil
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.view?.didReceiveError(viewModel: errorViewModel)
        }
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
                
                self?.refreshFee()
            }
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.view?.didReceiveError(viewModel: errorViewModel)
        }
    }
}

// MARK: - CrossChainSwapConfirmViewOutput

extension CrossChainSwapConfirmPresenter: CrossChainSwapConfirmViewOutput {

    func didLoad(view: CrossChainSwapConfirmViewInput) {
        self.view = view
        interactor.setup(with: self)

        provideViewModel()
        provideAmountInfoViewModel()
        provideImageViewModel()
        subscribeOnBalance()
        calculateTotalFiatFee()
        fetchInfo()
        fetchCrossChainTx()

        self.view?.setButtonLoadingState(isLoading: true)
    }

    func didTapConfirmButton() {
        guard let crossChainTx, let view else {
            fetchCrossChainTx()
            router.present(error: ConvenienceError(error: "Cannot build a transaction. Please try again later."), from: view, locale: selectedLocale)
            return
        }

        let sendAmount = swap.fromAmount.flatMap { BigUInt(string: $0) }
        let sendAmountDecimal = sendAmount.flatMap { Decimal.fromSubstrateAmount($0, precision: Int16(swapFromChainAsset.asset.precision)) }
        let balance: BalanceType = swapFromChainAsset.asset.isUtility ? .utility(balance: swapFromBalance) : .orml(balance: swapFromBalance, utilityBalance: utilityBalance)

        DataValidationRunner(validators: [
            dataValidatingFactory.has(fee: fromNetworkFee, locale: selectedLocale, onError: {}),
            dataValidatingFactory.canPayFeeAndAmount(
                balanceType: balance,
                feeAndTip: fromNetworkFee,
                sendAmount: sendAmountDecimal,
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            guard let self else {
                return
            }

            self.view?.setButtonLoadingState(isLoading: true)

            Task {
                do {
                    let isCrossChain = self.swapFromChainAsset.chain.chainId != self.swapToChainAsset.chain.chainId
                    let reason = isCrossChain ? CrossChain.Constants.txReasonCrossChain : CrossChain.Constants.txReasonSwap
                    
                    let txHash = try await self.interactor.confirmSwap(tx: crossChainTx)
                    let transaction = AssetTransactionData(
                        transactionId: txHash,
                        status: .pending,
                        assetId: "",
                        peerId: "",
                        peerFirstName: nil,
                        peerLastName: nil,
                        peerName: nil,
                        details: "",
                        amount: AmountDecimal(value: sendAmountDecimal.or(.zero)),
                        fees: [],
                        timestamp: Int64(Date().timeIntervalSince1970),
                        type: "",
                        reason: reason,
                        context: nil
                    )

                    await MainActor.run {
                            self.router.presentStatusTrackingScreen(
                                transaction: transaction,
                                chainAsset: self.swapFromChainAsset,
                                wallet: self.wallet,
                                from: self.view
                            )
                    }
                } catch {
                    await MainActor.run {
                        self.view?.setButtonLoadingState(isLoading: false)
                        
                        if let rpcError = error as? RPCResponse<EthereumQuantity>.Error {
                            self.showDefaultError(
                                title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: self.selectedLocale.rLanguages),
                                message: rpcError.message
                            )
                        } else {
                            self.router.presentError(for: error.localizedDescription, message: "", view: view, locale: self.selectedLocale)
                        }
                        
                    }
                }
            }
        }
    }

    func didTapBackButton() {
        timer?.invalidate()
        timer = nil

        router.dismiss(view: view)
    }
}

// MARK: - CrossChainSwapConfirmInteractorOutput

extension CrossChainSwapConfirmPresenter: CrossChainSwapConfirmInteractorOutput {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset) {
        switch result {
        case let .success(accountInfo):
            if chainAsset == swapFromChainAsset.chain.utilityChainAssets().first {
                utilityBalance = accountInfo.map {
                    Decimal.fromSubstrateAmount(
                        $0.data.sendAvailable,
                        precision: Int16(chainAsset.asset.precision)
                    )
                } ?? .zero
            }
            if swapFromChainAsset.chainAssetId == chainAsset.chainAssetId {
                swapFromBalance = accountInfo.map {
                    Decimal.fromSubstrateAmount(
                        $0.data.sendAvailable,
                        precision: Int16(chainAsset.asset.precision)
                    )
                } ?? .zero
            }
            if swapToChainAsset == chainAsset {
                swapToBalance = accountInfo.map {
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

extension CrossChainSwapConfirmPresenter: Localizable {
    func applyLocalization() {}
}

extension CrossChainSwapConfirmPresenter: CrossChainSwapConfirmModuleInput {}
