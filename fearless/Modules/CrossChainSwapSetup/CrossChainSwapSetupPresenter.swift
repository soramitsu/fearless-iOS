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
}

protocol CrossChainSwapSetupInteractorInput: AnyObject {
    func setup(with output: CrossChainSwapSetupInteractorOutput)
    func getQuotes(chainAsset: ChainAsset, destinationChainAsset: ChainAsset, amount: String) async throws -> [CrossChainSwap]
    func subscribeOnBalance(for chainAssets: [ChainAsset])
}

final class CrossChainSwapSetupPresenter {
    // MARK: Private properties

    private weak var view: CrossChainSwapSetupViewInput?
    private let router: CrossChainSwapSetupRouterInput
    private let interactor: CrossChainSwapSetupInteractorInput
    private let viewModelFactory: CrossChainSwapSetupViewModelFactory
    private let wallet: MetaAccountModel
    private var swapFromChainAsset: ChainAsset?
    private var swapToChainAsset: ChainAsset?
    private var swapVariant: SwapVariant = .desiredInput
    private var prices: [PriceData]?
    private var swap: CrossChainSwap?
    private let dataValidatingFactory: SendDataValidatingFactory

    private var swapFromInputResult: AmountInputResult?
    private var swapFromBalance: Decimal?
    private var swapToInputResult: AmountInputResult?
    private var swapToBalance: Decimal?
    private var utilityBalance: Decimal?

    private var totalFeesDecimal: Decimal? {
        guard let swapFromChainAsset, let fees = swap?.totalFees else {
            return nil
        }

        return Decimal.fromSubstrateAmount(fees, precision: Int16(swapFromChainAsset.asset.precision))
    }

    private var balanceMinusFee: Decimal? {
        guard swapFromChainAsset?.isUtility == true, let swapFromBalance, let totalFeesDecimal else {
            return swapFromBalance
        }

        return swapFromBalance - totalFeesDecimal
    }

    // MARK: - Constructors

    init(
        interactor: CrossChainSwapSetupInteractorInput,
        router: CrossChainSwapSetupRouterInput,
        localizationManager: LocalizationManagerProtocol,
        viewModelFactory: CrossChainSwapSetupViewModelFactory,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        dataValidatingFactory: SendDataValidatingFactory
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.wallet = wallet
        swapFromChainAsset = chainAsset
        self.dataValidatingFactory = dataValidatingFactory

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func fetchQuotes() {
        guard let swapFromChainAsset = swapFromChainAsset,
              let swapToChainAsset = swapToChainAsset
        else {
            return
        }

        let amount: String
        if swapVariant == .desiredInput {
            guard let fromAmountDecimal = swapFromInputResult?.absoluteValue(from: balanceMinusFee ?? .zero) else {
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

        Task {
            do {
                let quotes = try await interactor.getQuotes(
                    chainAsset: swapFromChainAsset,
                    destinationChainAsset: swapToChainAsset,
                    amount: amount
                )
                print("quotes : ", quotes)

                self.swap = quotes.first
                provideViewModel()
                provideDestinationInput()
                provideAssetViewModel()
            } catch {
                DispatchQueue.main.async { [weak self] in
                    if let error = error as? OKXDexError, let view = self?.view {
                        let message = error.decode(with: swapFromChainAsset)
                        self?.router.presentError(for: "", message: message ?? "", view: view, locale: self?.selectedLocale)
                    } else {
                        self?.router.present(error: error, from: self?.view, locale: self?.selectedLocale)
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

    func toggleSwapDirection() {
        if swapVariant == .desiredInput {
            swapVariant = .desiredOutput
        } else {
            swapVariant = .desiredInput
        }
    }

    private func runLoadingState() {
//        view?.setButtonLoadingState(isLoading: true)
//        loadingCollector.reset()
    }

    private func checkLoadingState() {
//        guard let isReady = loadingCollector.isReady else {
//            return
//        }
//        view?.setButtonLoadingState(isLoading: !isReady)
    }

    private func provideInputViewModel() {
//        let balanceViewModelFactory = buildBalanceViewModelFactory(
//            wallet: wallet,
//            for: selectedAmountChainAsset
//        )
//        let inputAmount = calculateAbsoluteValue()
//        let inputViewModel = balanceViewModelFactory?
//            .createBalanceInputViewModel(inputAmount)
//            .value(for: selectedLocale)
//        self.inputViewModel = inputViewModel
//
//        view?.didReceive(amountInputViewModel: inputViewModel)
    }

    private func provideViewModel() {
        guard let swap, let swapFromChainAsset, let swapToChainAsset else {
            return
        }

        let viewModel = viewModelFactory.buildSwapViewModel(
            swap: swap,
            sourceChainAsset: swapFromChainAsset,
            targetChainAsset: swapToChainAsset,
            wallet: wallet,
            locale: selectedLocale
        )

        DispatchQueue.main.async { [weak self] in
            self?.view?.didReceiveViewModel(viewModel: viewModel)
        }
    }

    private func provideAssetViewModel() {
        var balance: Decimal? = balanceMinusFee

        let inputAmount = swapFromInputResult?
            .absoluteValue(from: balance ?? .zero)

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
        interactor.subscribeOnBalance(for: chainAssets)
    }
}

// MARK: - CrossChainSwapSetupViewOutput

extension CrossChainSwapSetupPresenter: CrossChainSwapSetupViewOutput {
    func selectFromAmountPercentage(_ percentage: Float) {
        runLoadingState()

        swapVariant = .desiredInput
        swapFromInputResult = .rate(Decimal(Double(percentage)))
        provideAssetViewModel()
        fetchQuotes()
    }

    func updateFromAmount(_ newValue: Decimal) {
        runLoadingState()

        swapVariant = .desiredInput
        swapFromInputResult = .absolute(newValue)
        provideAssetViewModel()
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
        provideAssetViewModel()
        provideDestinationAssetViewModel()
        fetchQuotes()
    }

    func didTapSelectAsset() {
        router.showSelectAsset(
            from: view,
            wallet: wallet,
            output: self
        )
    }

    func didLoad(view: CrossChainSwapSetupViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideAssetViewModel()
        subscribeOnBalance()
    }

    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapContinueButton() {
        guard let swapFromChainAsset else {
            return
        }

        let precision = Int16(swapFromChainAsset.chain.utilityChainAssets().first?.asset.precision ?? swapFromChainAsset.asset.precision)
        let networkFee = swap?.totalFees.flatMap { Decimal.fromSubstrateAmount($0, precision: precision) }
        DataValidationRunner(validators: [
            dataValidatingFactory.has(fee: networkFee, locale: selectedLocale, onError: {}),
            dataValidatingFactory.canPayFeeAndAmount(
                balanceType: .utility(balance: utilityBalance),
                feeAndTip: networkFee,
                sendAmount: .zero,
                locale: selectedLocale
            ),
            dataValidatingFactory.canPayFeeAndAmount(
                balanceType: .utility(balance: swapFromBalance),
                feeAndTip: networkFee,
                sendAmount: swapToInputResult?.absoluteValue(from: swapFromBalance.or(.zero)),
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            print("Validation has passed")
        }
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

        fetchQuotes()
    }
}

// MARK: - Localizable

extension CrossChainSwapSetupPresenter: Localizable {
    func applyLocalization() {}
}

extension CrossChainSwapSetupPresenter: CrossChainSwapSetupModuleInput {}

extension CrossChainSwapSetupPresenter: SelectAssetModuleOutput {
    func assetSelection(didCompleteWith chainAsset: ChainAsset?, contextTag _: Int?) {
        swapToChainAsset = chainAsset
        swapToInputResult = nil
        provideDestinationAssetViewModel()
        view?.didReceiveViewModel(viewModel: nil)

        subscribeOnBalance()
        fetchQuotes()
    }
}
