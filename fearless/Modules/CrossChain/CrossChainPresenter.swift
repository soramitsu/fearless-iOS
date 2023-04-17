import Foundation
import SoraFoundation
import SSFXCM
import BigInt

protocol CrossChainViewInput: ControllerBackedProtocol {
    func didReceive(assetBalanceViewModel: AssetBalanceViewModelProtocol?)
    func didReceive(amountInputViewModel: IAmountInputViewModel?)
    func didReceive(originalSelectNetworkViewModel: SelectNetworkViewModel)
    func didReceive(destSelectNetworkViewModel: SelectNetworkViewModel)
    func didReceive(originFeeViewModel: LocalizableResource<BalanceViewModelProtocol>?)
    func didReceive(destinationFeeViewModel: LocalizableResource<BalanceViewModelProtocol>?)
}

protocol CrossChainInteractorInput: AnyObject {
    func setup(with output: CrossChainInteractorOutput)
    func didReceive(originalChainAsset: ChainAsset?, destChainAsset: ChainAsset?)
    func estimateFee(originalChainId: String, destinationChainId: String)
}

final class CrossChainPresenter {
    private enum InputTag: Int {
        case selectOriginal = 0
        case selectDest
    }

    // MARK: Private properties

    private weak var view: CrossChainViewInput?
    private let router: CrossChainRouterInput
    private let interactor: CrossChainInteractorInput
    private let logger: LoggerProtocol

    private let wallet: MetaAccountModel
    private let viewModelFactory: CrossChainViewModelFactoryProtocol

    private var selectedOriginalChainModel: ChainModel
    private var selectedAmountChainAsset: ChainAsset
    private var amountInputResult: AmountInputResult?

    private var originalNetworkPriceData: PriceData?
    private var originalNetworkBalance: Decimal?
    private var destNetworkUtilityTokenPriceData: PriceData?
    private var destNetworkUtilityTokenBalance: Decimal?
    private var prices: [PriceData] = []

    private var selectedDestChainModel: ChainModel?
    private var availableDestChainModel: [ChainModel] = []

    private var originalNetworkFee: Decimal?
    private var destNetworkFee: Decimal?
    private var balanceViewModel: BalanceViewModelProtocol?
    private var originalNetworkFeeViewModel: BalanceViewModelProtocol?
    private var destNetworkFeeViewModel: BalanceViewModelProtocol?

    // MARK: - Constructors

    init(
        originalChainAsset: ChainAsset,
        wallet: MetaAccountModel,
        viewModelFactory: CrossChainViewModelFactoryProtocol,
        logger: LoggerProtocol,
        interactor: CrossChainInteractorInput,
        router: CrossChainRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        selectedAmountChainAsset = originalChainAsset
        selectedOriginalChainModel = originalChainAsset.chain
        self.wallet = wallet
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideAssetViewModel() {
        let balanceViewModelFactory = buildBalanceViewModelFactory(
            wallet: wallet,
            for: selectedAmountChainAsset
        )

        let inputAmount = amountInputResult?
            .absoluteValue(from: originalNetworkBalance ?? .zero)

        let assetBalanceViewModel = balanceViewModelFactory?.createAssetBalanceViewModel(
            inputAmount,
            balance: originalNetworkBalance,
            priceData: originalNetworkPriceData
        ).value(for: selectedLocale)

        let balanceViewModel = balanceViewModelFactory?.balanceFromPrice(
            inputAmount ?? .zero,
            priceData: originalNetworkPriceData
        ).value(for: selectedLocale)
        self.balanceViewModel = balanceViewModel

        let inputViewModel = balanceViewModelFactory?
            .createBalanceInputViewModel(inputAmount)
            .value(for: selectedLocale)

        view?.didReceive(assetBalanceViewModel: assetBalanceViewModel)
        view?.didReceive(amountInputViewModel: inputViewModel)
    }

    private func provideOriginalSelectNetworkViewModel() {
        let chain = selectedOriginalChainModel
        let viewModel = viewModelFactory.buildNetworkViewModel(chain: chain)
        view?.didReceive(originalSelectNetworkViewModel: viewModel)
    }

    private func provideDestSelectNetworkViewModel() {
        guard let selectedDestChainModel = selectedDestChainModel else {
            return
        }
        let viewModel = viewModelFactory.buildNetworkViewModel(chain: selectedDestChainModel)
        view?.didReceive(destSelectNetworkViewModel: viewModel)
    }

    private func provideOriginalNetworkFeeViewModel() {
        let viewModelFactory = buildBalanceViewModelFactory(
            wallet: wallet,
            for: selectedAmountChainAsset
        )

        let viewModel = viewModelFactory?.balanceFromPrice(
            originalNetworkFee ?? .zero,
            priceData: originalNetworkPriceData
        )

        originalNetworkFeeViewModel = viewModel?.value(for: selectedLocale)

        view?.didReceive(originFeeViewModel: viewModel)
    }

    private func provideDestNetworkFeeViewModel() {
        let utilituDestChainAsset = selectedDestChainModel?.chainAssets.first(where: { $0.isUtility })
        let viewModelFactory = buildBalanceViewModelFactory(
            wallet: wallet,
            for: utilituDestChainAsset
        )

        let viewModel = viewModelFactory?.balanceFromPrice(
            destNetworkFee ?? .zero,
            priceData: originalNetworkPriceData
        )

        destNetworkFeeViewModel = viewModel?.value(for: selectedLocale)

        view?.didReceive(destinationFeeViewModel: viewModel)
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
            selectedMetaAccount: wallet
        )
        return balanceViewModelFactory
    }

    private func providePrices() {
        let destUtilituChainAsset = selectedDestChainModel?.chainAssets.first(where: { $0.isUtility })
        if let price = prices.first(where: { $0.priceId == selectedAmountChainAsset.asset.priceId }) {
            originalNetworkPriceData = price
            provideAssetViewModel()
        }

        if let price = prices.first(where: { $0.priceId == destUtilituChainAsset?.asset.priceId }) {
            destNetworkUtilityTokenPriceData = price
            provideAssetViewModel()
        }

        provideOriginalNetworkFeeViewModel()
        provideDestNetworkFeeViewModel()
    }
}

// MARK: - CrossChainViewOutput

extension CrossChainPresenter: CrossChainViewOutput {
    func selectAmountPercentage(_ percentage: Float) {
        amountInputResult = .rate(Decimal(Double(percentage)))
        provideAssetViewModel()
    }

    func updateAmount(_ newValue: Decimal) {
        amountInputResult = .absolute(newValue)
        provideAssetViewModel()
    }

    func didTapSelectAsset() {
        let chainAssets = selectedOriginalChainModel.chainAssets

        router.showSelectAsset(
            from: view,
            wallet: wallet,
            chainAssets: chainAssets,
            selectedAssetId: selectedAmountChainAsset.asset.identifier,
            output: self
        )
    }

    func didTapSelectOriginalNetwork() {
        router.showSelectNetwork(
            from: view,
            wallet: wallet,
            selectedChainId: selectedOriginalChainModel.chainId,
            chainModels: nil,
            contextTag: InputTag.selectOriginal.rawValue,
            delegate: self
        )
    }

    func didTapSelectDestNetwoek() {
        router.showSelectNetwork(
            from: view,
            wallet: wallet,
            selectedChainId: selectedDestChainModel?.chainId,
            chainModels: availableDestChainModel,
            contextTag: InputTag.selectDest.rawValue,
            delegate: self
        )
    }

    func didLoad(view: CrossChainViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideOriginalSelectNetworkViewModel()
        interactor.didReceive(originalChainAsset: selectedAmountChainAsset, destChainAsset: nil)
    }

    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapConfirmButton() {
        guard let selectedDestChainModel = selectedDestChainModel,
              let balanceViewModel = balanceViewModel,
              let originalChainFee = originalNetworkFeeViewModel,
              let destChainFee = destNetworkFeeViewModel,
              let inputAmount = amountInputResult?.absoluteValue(from: originalNetworkBalance ?? .zero),
              let substrateAmout = inputAmount.toSubstrateAmount(precision: Int16(selectedAmountChainAsset.asset.precision))
        else {
            return
        }
        let data = CrossChainConfirmationData(
            wallet: wallet,
            originalChainAsset: selectedAmountChainAsset,
            destChainModel: selectedDestChainModel,
            amount: substrateAmout,
            amountViewModel: balanceViewModel,
            originalChainFee: originalChainFee,
            destChainFee: destChainFee
        )
        router.showConfirmation(
            from: view,
            data: data
        )
    }
}

// MARK: - CrossChainInteractorOutput

extension CrossChainPresenter: CrossChainInteractorOutput {
    func didReceiveFee(result: Result<XcmFeeResponse, Error>) {
        switch result {
        case let .success(response):
            originalNetworkFee = Decimal.fromSubstrateAmount(
                response.originalChainFee.origXcmFee,
                precision: Int16(selectedAmountChainAsset.asset.precision)
            )
            destNetworkFee = Decimal.fromSubstrateAmount(
                response.destinationChainFee.destXcmFee,
                precision: Int16(selectedAmountChainAsset.asset.precision)
            )

            provideOriginalNetworkFeeViewModel()
            provideDestNetworkFeeViewModel()
        case let .failure(error):
            logger.error(error.localizedDescription)
        }
    }

    func didReceivePricesData(result: Result<[PriceData], Error>) {
        switch result {
        case let .success(prices):
            self.prices = self.prices.filter { !prices.map { $0.priceId }.contains($0.priceId) }
            self.prices.append(contentsOf: prices)
            providePrices()
        case let .failure(error):
            logger.error("\(error)")
        }
    }

    func didReceiveAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId: AccountId,
        chainAsset: ChainAsset
    ) {
        let receiveUniqueKey = chainAsset.uniqueKey(accountId: accountId)
        let destUtilituChainAsset = selectedDestChainModel?.chainAssets.first(where: { $0.isUtility })

        switch result {
        case let .success(success):
            if receiveUniqueKey == selectedAmountChainAsset.uniqueKey(accountId: accountId) {
                originalNetworkBalance = success.map {
                    Decimal.fromSubstrateAmount(
                        $0.data.sendAvailable,
                        precision: Int16(chainAsset.asset.precision)
                    )
                } ?? .zero
                provideAssetViewModel()
                provideOriginalNetworkFeeViewModel()
            } else if receiveUniqueKey == destUtilituChainAsset?.uniqueKey(accountId: accountId) {
                destNetworkUtilityTokenBalance = success.map {
                    Decimal.fromSubstrateAmount(
                        $0.data.sendAvailable,
                        precision: Int16(chainAsset.asset.precision)
                    )
                } ?? .zero
                provideDestNetworkFeeViewModel()
            }
        case let .failure(failure):
            logger.error("\(failure)")
        }
    }

    func didReceiveAvailableDestChainAssets(_ chainAssets: [ChainAsset]) {
        let filtredChainAssets = chainAssets
            .filter { $0.chain.chainId != selectedOriginalChainModel.chainId }
        availableDestChainModel = filtredChainAssets
            .map { $0.chain }

        if selectedDestChainModel == nil {
            selectedDestChainModel = filtredChainAssets.map { $0.chain }.first
        }
        provideDestSelectNetworkViewModel()

        if let destUtilityChainAsset = filtredChainAssets.first(where: { $0.isUtility }) {
            interactor.didReceive(originalChainAsset: nil, destChainAsset: destUtilityChainAsset)

            interactor.estimateFee(
                originalChainId: selectedAmountChainAsset.chain.chainId,
                destinationChainId: destUtilityChainAsset.chain.chainId
            )
        }
    }
}

// MARK: - Localizable

extension CrossChainPresenter: Localizable {
    func applyLocalization() {}
}

extension CrossChainPresenter: CrossChainModuleInput {}

// MARK: - SelectAssetModuleOutput

extension CrossChainPresenter: SelectAssetModuleOutput {
    func assetSelection(
        didCompleteWith chainAsset: ChainAsset?,
        contextTag _: Int?
    ) {
        guard let chainAsset = chainAsset else {
            return
        }
        selectedAmountChainAsset = chainAsset
        let destUtilityChainAsset = selectedDestChainModel?.utilityChainAssets().first(where: { $0.isUtility })
        interactor.didReceive(originalChainAsset: chainAsset, destChainAsset: destUtilityChainAsset)

        if let destUtilityChainAsset = destUtilityChainAsset {
            interactor.estimateFee(
                originalChainId: selectedAmountChainAsset.chain.chainId,
                destinationChainId: destUtilityChainAsset.chain.chainId
            )
        }
    }
}

// MARK: - SelectNetworkDelegate

extension CrossChainPresenter: SelectNetworkDelegate {
    func chainSelection(
        view _: SelectNetworkViewInput,
        didCompleteWith chain: ChainModel?,
        contextTag: Int?
    ) {
        guard let chain = chain,
              let rawValue = contextTag,
              let input = InputTag(rawValue: rawValue) else {
            return
        }

        switch input {
        case .selectOriginal:
            selectedOriginalChainModel = chain

            if let originalUtilityChainAsset = chain.utilityChainAssets().first(where: { $0.isUtility }) {
                let destUtilityChainAsset = chain.utilityChainAssets().first(where: { $0.isUtility })
                selectedAmountChainAsset = originalUtilityChainAsset
                interactor.didReceive(originalChainAsset: originalUtilityChainAsset, destChainAsset: destUtilityChainAsset)

                if let destUtilityChainAsset = destUtilityChainAsset {
                    interactor.estimateFee(
                        originalChainId: selectedAmountChainAsset.chain.chainId,
                        destinationChainId: destUtilityChainAsset.chain.chainId
                    )
                }
            }
            provideOriginalSelectNetworkViewModel()
        case .selectDest:
            selectedDestChainModel = chain
            provideDestSelectNetworkViewModel()

            if let destUtilityChainAsset = chain.utilityChainAssets().first(where: { $0.isUtility }) {
                interactor.didReceive(originalChainAsset: selectedAmountChainAsset, destChainAsset: destUtilityChainAsset)

                interactor.estimateFee(
                    originalChainId: selectedAmountChainAsset.chain.chainId,
                    destinationChainId: destUtilityChainAsset.chain.chainId
                )
            }
        }
    }
}
