import Foundation
import SoraFoundation
import SSFModels

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

    private let wallet: MetaAccountModel
    private let xorChainAsset: ChainAsset
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

    // MARK: - Constructors
    init(
        interactor: LiquidityPoolSupplyInteractorInput,
        router: LiquidityPoolSupplyRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }
    
    // MARK: - Private methods
    
    private func runLoadingState() {
        view?.setButtonLoadingState(isLoading: true)
    }

    private func checkLoadingState() {
        view?.setButtonLoadingState(isLoading: false)
    }
    
    private func provideFromAssetVewModel(updateAmountInput: Bool = true) {
        var balance: Decimal? = swapFromBalance
        if swapFromChainAsset == xorChainAsset, let xorBalance = xorBalance, let networkFee = networkFee {
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

        view?.didReceiveSwapFrom(viewModel: viewModel)
        if updateAmountInput {
            view?.didReceiveSwapFrom(amountInputViewModel: inputViewModel)
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

        view?.didReceiveSwapTo(viewModel: viewModel)
        if updateAmountInput {
            view?.didReceiveSwapTo(amountInputViewModel: inputViewModel)
        }

        checkLoadingState()
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
    
    func didTapPreviewButton() {
        
    }
    
    func selectFromAmountPercentage(_ percentage: Float) {
        runLoadingState()

        swapVariant = .desiredInput
        swapFromInputResult = .rate(Decimal(Double(percentage)))
        provideFromAssetVewModel()

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
        provideFromAssetVewModel(updateAmountInput: false)
    }
    
    func selectToAmountPercentage(_ percentage: Float) {
        runLoadingState()

        swapVariant = .desiredOutput
        swapToInputResult = .rate(Decimal(Double(percentage)))
        provideToAssetVewModel()
    }
    
    func updateToAmount(_ newValue: Decimal) {
        runLoadingState()

        swapVariant = .desiredOutput
        swapToInputResult = .absolute(newValue)
        provideToAssetVewModel(updateAmountInput: false)
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
    
    func didLoad(view: LiquidityPoolSupplyViewInput) {
        self.view = view
        interactor.setup(with: self)
    }
}

// MARK: - LiquidityPoolSupplyInteractorOutput
extension LiquidityPoolSupplyPresenter: LiquidityPoolSupplyInteractorOutput {}

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
        view?.didUpdating()
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

        //TODO : Refresh fee
    }
}
