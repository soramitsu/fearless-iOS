import Foundation
import Commons
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
    func didReceive(viewType: CrossChainSwapViewType)
}

protocol CrossChainSwapConfirmInteractorInput: AnyObject, CrossChainBaseInteractor {
    func setup(with output: CrossChainSwapConfirmInteractorOutput)
    func subscribeOnBalance(for chainAssets: [ChainAsset])
    func estimateFee(tx: CrossChainTx) async throws -> BigUInt
    func confirmSwap(tx: CrossChainTx) async throws -> String
    func checkTransactionSucceed(approveTxHash: String) async throws -> Bool
}

final class CrossChainSwapConfirmPresenter: CrossChainSwapBasePresenter<CrossChainSwapConfirmInteractor> {
    // MARK: Private properties

    private weak var view: CrossChainSwapConfirmViewInput?
    private let router: CrossChainSwapConfirmRouterInput
    private let viewModelFactory: CrossChainSwapConfirmViewModelFactory
    private let dataValidatingFactory: SendDataValidatingFactory
    private let logger: LoggerProtocol?

    private let swapFromChainAsset: ChainAsset
    private let swapToChainAsset: ChainAsset
    private var swap: CrossChainSwap

    private var swapFromBalance: Decimal?
    private var swapToBalance: Decimal?
    private var utilityBalance: Decimal?
    private var timer: Timer?
    private let amount: String
    private let selectedDexIds: [String]?
    private var fromNetworkFee: Decimal?
    private var crossChainTx: CrossChainTx?
    private var slippage: Decimal
    private var approveTxHash: String?
    private var feeErrorCounter: Int = 0
    private var viewType: CrossChainSwapViewType

    // MARK: - Constructors

    init(
        interactor: CrossChainSwapConfirmInteractor,
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
        self.router = router
        self.swapFromChainAsset = swapFromChainAsset
        self.swapToChainAsset = swapToChainAsset
        self.swap = swap
        self.viewModelFactory = viewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.amount = amount
        self.selectedDexIds = selectedDexIds
        self.logger = logger
        self.slippage = slippage
        self.approveTxHash = approveTxHash
        self.viewType = CrossChainSwapViewType(isCrossChainSwap: swapFromChainAsset.chain.chainId != swapToChainAsset.chain.chainId)

        super.init(
            wallet: wallet,
            interactor: interactor
        )
        
        self.localizationManager = localizationManager
    }

    // MARK: Private
    
    private func updateButtonLoadingState(isLoading: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.view?.setButtonLoadingState(isLoading: isLoading)
        }
    }
    
    @objc private func handleTimerTick() {
        fetchInfo()
    }

    private func setupTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: 3.0,
            target: self,
            selector: #selector(
                handleTimerTick
            ),
            userInfo: nil,
            repeats: true
        )
    }

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
                } else {
                    showDefaultError(
                        title: "Approve transaction failed",
                        message: "Please return back and try again"
                    )
                }
            } catch {
                logger?.customError(error)
            }
        }
    }

    private func fetchInfo() {
        if let approveTxHash {
            showDefaultError(
                title: R.string.localizable.approveTransactionPendingTitle(
                    preferredLanguages: selectedLocale.rLanguages
                ),
                message: R.string.localizable.blockchainTransactionPendingDescription(
                    preferredLanguages: selectedLocale.rLanguages
                )
            )
            
            checkApproveTransactionSucceed(approveTxHash: approveTxHash)
            return
        }
        
        timer?.invalidate()

        Task {
            do {
                let utilityChainAsset = swapFromChainAsset.chain.utilityChainAssets().first ?? swapFromChainAsset
                let swapSetupInfo = try await interactor.fetchSwapSetupInfo(
                    chainAsset: swapFromChainAsset,
                    destinationChainAsset: swapToChainAsset,
                    amount: amount,
                    slippage: slippage.stringWithPointSeparator,
                    selectedDexIds: selectedDexIds
                )

                self.swap = swapSetupInfo.swap
                self.fromNetworkFee = swapSetupInfo.swap.fee.flatMap {
                    BigUInt($0)
                }.flatMap {
                    Decimal.fromSubstrateAmount($0, precision: Int16(utilityChainAsset.asset.precision))
                }
                self.totalFiatFee = try await calculateTotalFiatFee(
                    for: swapSetupInfo.swap,
                    swapFromChainAsset: swapFromChainAsset,
                    originNetworkFee: fromNetworkFee
                )
                
                provideViewModel()
                
                updateButtonLoadingState(isLoading: false)
            } catch {
                logger?.customError(error)
                                
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }
                    
                    updateButtonLoadingState(isLoading: false)

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
                
                self?.fetchInfo()
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
        fetchInfo()
        setupTimer()
        fetchCrossChainTx()

        view.didReceive(viewType: viewType)
        updateButtonLoadingState(isLoading: true)
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

            updateButtonLoadingState(isLoading: true)

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
                        self.updateButtonLoadingState(isLoading: false)
                        
                        if let rpcError = error as? RPCResponse<EthereumQuantity>.Error {
                            self.showDefaultError(
                                title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: self.selectedLocale.rLanguages),
                                message: rpcError.message
                            )
                        } else if let rpcError = error as? RPCResponse<EthereumData>.Error {
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
