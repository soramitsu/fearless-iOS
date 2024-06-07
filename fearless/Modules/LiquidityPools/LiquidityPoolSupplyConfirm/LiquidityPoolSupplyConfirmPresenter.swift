import Foundation
import SoraFoundation
import SSFPools
import SSFPolkaswap
import SSFModels
import BigInt

protocol LiquidityPoolSupplyConfirmViewInput: ControllerBackedProtocol {
    func didReceiveNetworkFee(fee: BalanceViewModelProtocol?)
    func setButtonLoadingState(isLoading: Bool)
    func didUpdating()
    func didReceiveViewModel(_ viewModel: LiquidityPoolSupplyViewModel)
    func didReceiveConfirmationViewModel(_ viewModel: LiquidityPoolSupplyConfirmViewModel?)
}

protocol LiquidityPoolSupplyConfirmInteractorInput: AnyObject {
    func setup(with output: LiquidityPoolSupplyConfirmInteractorOutput)
    func estimateFee(supplyLiquidityInfo: SupplyLiquidityInfo)
    func submit(supplyLiquidityInfo: SupplyLiquidityInfo)
}

final class LiquidityPoolSupplyConfirmPresenter {
    // MARK: Private properties

    private weak var view: LiquidityPoolSupplyConfirmViewInput?
    private let router: LiquidityPoolSupplyConfirmRouterInput
    private let interactor: LiquidityPoolSupplyConfirmInteractorInput
    private let dataValidatingFactory: SendDataValidatingFactory
    private let logger: LoggerProtocol
    private let liquidityPair: LiquidityPair
    private let chain: ChainModel
    private let inputData: LiquidityPoolSupplyConfirmInputData
    private let viewModelFactory: LiquidityPoolSupplyConfirmViewModelFactory

    private var apyInfo: PoolApyInfo?
    private let wallet: MetaAccountModel
    private var swapFromChainAsset: ChainAsset?
    private var swapToChainAsset: ChainAsset?
    private var prices: [PriceData]?
    private var networkFeeViewModel: BalanceViewModelProtocol?
    private var networkFee: Decimal?
    private var xorBalance: Decimal?
    private var xorBalanceMinusFee: Decimal {
        (xorBalance ?? 0) - (networkFee ?? 0)
    }

    private var swapFromBalance: Decimal?
    private var swapToBalance: Decimal?

    private var dexId: String?

    // MARK: - Constructors

    init(
        interactor: LiquidityPoolSupplyConfirmInteractorInput,
        router: LiquidityPoolSupplyConfirmRouterInput,
        localizationManager: LocalizationManagerProtocol,
        dataValidatingFactory: SendDataValidatingFactory,
        logger: LoggerProtocol,
        liquidityPair: LiquidityPair,
        chain: ChainModel,
        inputData: LiquidityPoolSupplyConfirmInputData,
        wallet: MetaAccountModel,
        viewModelFactory: LiquidityPoolSupplyConfirmViewModelFactory
    ) {
        self.interactor = interactor
        self.router = router
        self.dataValidatingFactory = dataValidatingFactory
        self.logger = logger
        self.liquidityPair = liquidityPair
        self.chain = chain
        self.inputData = inputData
        self.wallet = wallet
        self.viewModelFactory = viewModelFactory

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

        let supplyLiquidityInfo = SupplyLiquidityInfo(
            dexId: dexId,
            baseAsset: baseAssetInfo,
            targetAsset: targetAssetInfo,
            baseAssetAmount: inputData.baseAssetAmount,
            targetAssetAmount: inputData.targetAssetAmount,
            slippage: inputData.slippageTolerance
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

        refreshFee()
    }

    private func provideViewModel() {
        let viewModel = viewModelFactory.buildViewModel(
            slippage: inputData.slippageTolerance,
            apy: apyInfo,
            liquidityPair: liquidityPair,
            chain: chain
        )

        view?.didReceiveViewModel(viewModel)
    }

    private func provideConfirmationViewModel() {
        let viewModel = viewModelFactory.buildViewModel(
            baseAssetAmount: inputData.baseAssetAmount,
            targetAssetAmount: inputData.targetAssetAmount,
            liquidityPair: liquidityPair,
            chain: chain,
            locale: selectedLocale
        )

        view?.didReceiveConfirmationViewModel(viewModel)
    }
}

// MARK: - LiquidityPoolSupplyConfirmViewOutput

extension LiquidityPoolSupplyConfirmPresenter: LiquidityPoolSupplyConfirmViewOutput {
    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapApyInfo() {
        var infoText: String
        var infoTitle: String
        infoTitle = "Strategic Bonus APY"
        infoText = "Farming reward for liquidity provision"
        router.presentInfo(
            message: infoText,
            title: infoTitle,
            from: view
        )
    }

    func didTapConfirmButton() {
        guard
            let dexId,
            let baseAsset = chain.assets.first(where: { $0.currencyId == liquidityPair.baseAssetId }),
            let targetAsset = chain.assets.first(where: { $0.currencyId == liquidityPair.targetAssetId })
        else {
            return
        }

        let baseAssetInfo = PooledAssetInfo(id: liquidityPair.baseAssetId, precision: Int16(baseAsset.precision))
        let targetAssetInfo = PooledAssetInfo(id: liquidityPair.targetAssetId, precision: Int16(targetAsset.precision))

        let supplyLiquidityInfo = SupplyLiquidityInfo(
            dexId: dexId,
            baseAsset: baseAssetInfo,
            targetAsset: targetAssetInfo,
            baseAssetAmount: inputData.baseAssetAmount,
            targetAssetAmount: inputData.targetAssetAmount,
            slippage: inputData.slippageTolerance
        )

        interactor.submit(supplyLiquidityInfo: supplyLiquidityInfo)
    }

    func didLoad(view: LiquidityPoolSupplyConfirmViewInput) {
        self.view = view
        interactor.setup(with: self)
    }

    func handleViewAppeared() {
        DispatchQueue.main.async { [weak self] in
            self?.view?.didReceiveNetworkFee(fee: nil)
            self?.provideViewModel()
            self?.provideConfirmationViewModel()
        }

        refreshFee()
    }
}

// MARK: - LiquidityPoolSupplyConfirmInteractorOutput

extension LiquidityPoolSupplyConfirmPresenter: LiquidityPoolSupplyConfirmInteractorOutput {
    func didReceivePoolAPY(apyInfo: SSFPolkaswap.PoolApyInfo?) {
        self.apyInfo = apyInfo
        provideViewModel()
    }

    func didReceivePoolApyError(error: Error) {
        logger.customError(error)
    }

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
            provideFeeViewModel()
        case let .failure(error):
            prices = []
            logger.error("\(error)")
        }
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
            }
            if swapToChainAsset == chainAsset {
                swapToBalance = accountInfo.map {
                    Decimal.fromSubstrateAmount(
                        $0.data.sendAvailable,
                        precision: Int16(chainAsset.asset.precision)
                    )
                } ?? .zero
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

    func didReceiveTransactionHash(_ hash: String) {
        guard let utilityChainAsset = chain.utilityChainAssets().first else {
            return
        }

        router.complete(on: view, title: hash, chainAsset: utilityChainAsset)
    }

    func didReceiveSubmitError(error: Error) {
        router.present(error: error, from: view, locale: selectedLocale)
    }
}

// MARK: - Localizable

extension LiquidityPoolSupplyConfirmPresenter: Localizable {
    func applyLocalization() {}
}

extension LiquidityPoolSupplyConfirmPresenter: LiquidityPoolSupplyConfirmModuleInput {}
