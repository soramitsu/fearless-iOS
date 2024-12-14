import Foundation
import SoraFoundation
import SSFModels
import BigInt

protocol CrossChainSwapConfirmViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(swapAmountInfoViewModel: SwapAmountInfoViewModel)
    func didReceive(viewModel: CrossChainSwapViewModel)
    func didReceive(doubleImageViewModel: PolkaswapDoubleSymbolViewModel)
    func didReceive(feeViewModel: TitleMultiValueViewModel?)
}

protocol CrossChainSwapConfirmInteractorInput: AnyObject, CrossChainBaseInteractor {
    func setup(with output: CrossChainSwapConfirmInteractorOutput)
    func confirmSwap() async throws -> String
    func subscribeOnBalance(for chainAssets: [ChainAsset])
    func estimateFee() async throws -> BigUInt
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
    private let selectedDexIds: [String]
    private var fromNetworkFee: Decimal?

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
        selectedDexIds: [String],
        logger: LoggerProtocol?
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

        self.localizationManager = localizationManager
    }

    // MARK: - Data Fetching

    private func refreshFee() {
        guard let utilityChainAsset = swapFromChainAsset.chain.utilityChainAssets().first else {
            return
        }

        Task {
            let fee = try await interactor.estimateFee()
            self.fromNetworkFee = Decimal.fromSubstrateAmount(fee, precision: Int16(utilityChainAsset.asset.precision))
        }
    }

    private func fetchInfo() {
        guard let utilityChainAsset = swapFromChainAsset.chain.utilityChainAssets().first else {
            return
        }

        Task {
            do {
                let swapSetupInfo = try await interactor.fetchSwapSetupInfo(
                    chainAsset: swapFromChainAsset,
                    destinationChainAsset: swapToChainAsset,
                    amount: amount,
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
            totalFiatFee: totalFiatFee
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
        let fee = swap.fee.flatMap { BigUInt(string: $0) }.flatMap { Decimal.fromSubstrateAmount($0, precision: Int16(swapFromChainAsset.asset.precision)) }
        let sourceChainFeeNativeToken = swapFromChainAsset.chain.chainAssets.first(where: { $0.asset.id == swapFromChainAsset.asset.id })

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

    @objc private func handleTimerTick() {
        fetchInfo()
    }

    private func setupTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 15.0, target: self, selector: #selector(handleTimerTick), userInfo: nil, repeats: true)
    }
}

// MARK: - CrossChainSwapConfirmViewOutput

extension CrossChainSwapConfirmPresenter: CrossChainSwapConfirmViewOutput {
    func handleDismissingSwipe() {
        timer?.invalidate()
        timer = nil
    }

    func didLoad(view: CrossChainSwapConfirmViewInput) {
        self.view = view
        interactor.setup(with: self)

        provideViewModel()
        provideAmountInfoViewModel()
        provideImageViewModel()
        subscribeOnBalance()
        refreshFee()
        calculateTotalFiatFee()
        setupTimer()
        fetchInfo()
    }

    func didTapConfirmButton() {
        let sendAmount = swap.fromAmount.flatMap { BigUInt(string: $0) }
        let sendAmountDecimal = sendAmount.flatMap { Decimal.fromSubstrateAmount($0, precision: Int16(swapToChainAsset.asset.precision)) }

        view?.didStartLoading()

        let fee = fromNetworkFee
        let nativeFee = swapFromChainAsset.asset.isUtility ? fee : .zero

        DataValidationRunner(validators: [
            dataValidatingFactory.has(fee: fromNetworkFee, locale: selectedLocale, onError: {}),
            dataValidatingFactory.canPayFeeAndAmount(
                balanceType: .utility(balance: utilityBalance),
                feeAndTip: nativeFee,
                sendAmount: .zero,
                locale: selectedLocale
            ),
            dataValidatingFactory.canPayFeeAndAmount(
                balanceType: .utility(balance: swapFromBalance),
                feeAndTip: fee,
                sendAmount: sendAmountDecimal,
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            guard let self else {
                return
            }

            Task {
                do {
                    let txHash = try await self.interactor.confirmSwap()
                    let transaction = AssetTransactionData(transactionId: txHash, status: .pending, assetId: "", peerId: "", peerFirstName: nil, peerLastName: nil, peerName: nil, details: "", amount: AmountDecimal(value: sendAmountDecimal.or(.zero)), fees: [], timestamp: Int64(Date().timeIntervalSince1970), type: "", reason: nil, context: nil)
                    self.router.presentStatusTrackingScreen(transaction: transaction, chainAsset: self.swapFromChainAsset, wallet: self.wallet, from: self.view)
                } catch {
                    self.router.present(error: error, from: self.view, locale: self.selectedLocale)
                }
            }
        }
    }

    func didTapBackButton() {
        timer?.invalidate()
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
            if swapFromChainAsset == chainAsset {
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
