import Foundation
import SoraFoundation
import SSFXCM
import BigInt
import SSFExtrinsicKit
import SSFUtils

protocol CrossChainViewInput: ControllerBackedProtocol {
    func didReceive(assetBalanceViewModel: AssetBalanceViewModelProtocol?)
    func didReceive(amountInputViewModel: IAmountInputViewModel?)
    func didReceive(originSelectNetworkViewModel: SelectNetworkViewModel)
    func didReceive(destSelectNetworkViewModel: SelectNetworkViewModel)
    func didReceive(originFeeViewModel: LocalizableResource<BalanceViewModelProtocol>?)
    func didReceive(destinationFeeViewModel: LocalizableResource<BalanceViewModelProtocol>?)
    func didReceive(recipientViewModel: RecipientViewModel)
}

protocol CrossChainInteractorInput: AnyObject {
    var xcmServices: XcmExtrinsicServices? { get }
    func setup(with output: CrossChainInteractorOutput)
    func didReceive(originChainAsset: ChainAsset?, destChainAsset: ChainAsset?)
    func estimateFee(originChainAsset: ChainAsset, destinationChainModel: ChainModel, amount: Decimal?)
    func validate(address: String?, for chain: ChainModel) -> AddressValidationResult
}

final class CrossChainPresenter {
    // MARK: Private properties

    private weak var view: CrossChainViewInput?
    private let router: CrossChainRouterInput
    private let interactor: CrossChainInteractorInput
    private let logger: LoggerProtocol

    private let wallet: MetaAccountModel
    private let viewModelFactory: CrossChainViewModelFactoryProtocol

    private var selectedOriginChainModel: ChainModel
    private var selectedAmountChainAsset: ChainAsset
    private var amountInputResult: AmountInputResult?
    private var availableOriginChainAsset: [ChainAsset] = []

    private var originNetworkPriceData: PriceData?
    private var originNetworkBalance: Decimal?
    private var destNetworkUtilityTokenPriceData: PriceData?
    private var destNetworkUtilityTokenBalance: Decimal?
    private var prices: [PriceData] = []

    private var destWallet: MetaAccountModel?
    private var recipientAddress: String?
    private var selectedDestChainModel: ChainModel?
    private var availableDestChainModels: [ChainModel] = []

    private var originNetworkFee: Decimal?
    private var destNetworkFee: Decimal?
    private var balanceViewModel: BalanceViewModelProtocol?
    private var originNetworkFeeViewModel: BalanceViewModelProtocol?
    private var destNetworkFeeViewModel: BalanceViewModelProtocol?

    // MARK: - Constructors

    init(
        originChainAsset: ChainAsset,
        wallet: MetaAccountModel,
        viewModelFactory: CrossChainViewModelFactoryProtocol,
        logger: LoggerProtocol,
        interactor: CrossChainInteractorInput,
        router: CrossChainRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        selectedAmountChainAsset = originChainAsset
        selectedOriginChainModel = originChainAsset.chain
        self.wallet = wallet
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideInputViewModel() {
        let balanceViewModelFactory = buildBalanceViewModelFactory(
            wallet: wallet,
            for: selectedAmountChainAsset
        )
        let inputAmount = amountInputResult?
            .absoluteValue(from: originNetworkBalance ?? .zero)
        let inputViewModel = balanceViewModelFactory?
            .createBalanceInputViewModel(inputAmount)
            .value(for: selectedLocale)

        view?.didReceive(amountInputViewModel: inputViewModel)
    }

    private func provideAssetViewModel() {
        let balanceViewModelFactory = buildBalanceViewModelFactory(
            wallet: wallet,
            for: selectedAmountChainAsset
        )

        let inputAmount = amountInputResult?
            .absoluteValue(from: originNetworkBalance ?? .zero)

        let assetBalanceViewModel = balanceViewModelFactory?.createAssetBalanceViewModel(
            inputAmount,
            balance: originNetworkBalance,
            priceData: originNetworkPriceData
        ).value(for: selectedLocale)

        let balanceViewModel = balanceViewModelFactory?.balanceFromPrice(
            inputAmount ?? .zero,
            priceData: originNetworkPriceData
        ).value(for: selectedLocale)
        self.balanceViewModel = balanceViewModel

        view?.didReceive(assetBalanceViewModel: assetBalanceViewModel)
    }

    private func provideOriginSelectNetworkViewModel() {
        let chain = selectedOriginChainModel
        let viewModel = viewModelFactory.buildNetworkViewModel(chain: chain)
        view?.didReceive(originSelectNetworkViewModel: viewModel)
    }

    private func provideDestSelectNetworkViewModel() {
        guard let selectedDestChainModel = selectedDestChainModel else {
            return
        }
        let viewModel = viewModelFactory.buildNetworkViewModel(chain: selectedDestChainModel)
        view?.didReceive(destSelectNetworkViewModel: viewModel)
    }

    private func provideOriginNetworkFeeViewModel() {
        guard
            let originNetworkFee = originNetworkFee,
            let viewModelFactory = buildBalanceViewModelFactory(
                wallet: wallet,
                for: selectedAmountChainAsset
            )
        else {
            view?.didReceive(originFeeViewModel: nil)
            return
        }

        let viewModel = viewModelFactory.balanceFromPrice(
            originNetworkFee,
            priceData: originNetworkPriceData
        )

        originNetworkFeeViewModel = viewModel.value(for: selectedLocale)

        view?.didReceive(originFeeViewModel: viewModel)
    }

    private func provideDestNetworkFeeViewModel() {
        guard
            let destNetworkFee = destNetworkFee,
            let utilituDestChainAsset = selectedDestChainModel?.chainAssets.first(where: { $0.isUtility }),
            let viewModelFactory = buildBalanceViewModelFactory(
                wallet: wallet,
                for: utilituDestChainAsset
            )
        else {
            view?.didReceive(destinationFeeViewModel: nil)
            return
        }

        let viewModel = viewModelFactory.balanceFromPrice(
            destNetworkFee,
            priceData: originNetworkPriceData
        )

        destNetworkFeeViewModel = viewModel.value(for: selectedLocale)

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
            originNetworkPriceData = price
            provideAssetViewModel()
        }

        if let price = prices.first(where: { $0.priceId == destUtilituChainAsset?.asset.priceId }) {
            destNetworkUtilityTokenPriceData = price
            provideAssetViewModel()
        }

        provideOriginNetworkFeeViewModel()
        provideDestNetworkFeeViewModel()
    }

    private func handle(newAddress: String) {
        guard let destChain = selectedDestChainModel else {
            return
        }
        recipientAddress = newAddress
        let isValid = interactor.validate(address: newAddress, for: destChain).isValid
        let viewModel = viewModelFactory.buildRecipientViewModel(
            address: newAddress,
            isValid: isValid
        )
        view?.didReceive(recipientViewModel: viewModel)
    }

    private func provideAddress() {
        if let destWallet = destWallet {
            selectedWallet(destWallet, for: 0)
        } else {
            guard let chain = selectedDestChainModel else {
                return
            }
            let isValid = interactor.validate(address: recipientAddress, for: chain).isValid
            if isValid, let recipientAddress = recipientAddress {
                handle(newAddress: recipientAddress)
            } else {
                handle(newAddress: "")
            }
        }
    }
}

// MARK: - CrossChainViewOutput

extension CrossChainPresenter: CrossChainViewOutput {
    func selectAmountPercentage(_ percentage: Float) {
        amountInputResult = .rate(Decimal(Double(percentage)))
        provideAssetViewModel()
        provideInputViewModel()

        if let selectedDestChainModel = selectedDestChainModel {
            let inputAmount = amountInputResult?
                .absoluteValue(from: originNetworkBalance ?? .zero) ?? .zero

            interactor.estimateFee(
                originChainAsset: selectedAmountChainAsset,
                destinationChainModel: selectedDestChainModel,
                amount: inputAmount
            )
        }
    }

    func updateAmount(_ newValue: Decimal) {
        amountInputResult = .absolute(newValue)
        provideAssetViewModel()

        if let selectedDestChainModel = selectedDestChainModel {
            let inputAmount = amountInputResult?
                .absoluteValue(from: originNetworkBalance ?? .zero) ?? .zero

            interactor.estimateFee(
                originChainAsset: selectedAmountChainAsset,
                destinationChainModel: selectedDestChainModel,
                amount: inputAmount
            )
        }
    }

    func didTapSelectAsset() {
        router.showSelectAsset(
            from: view,
            wallet: wallet,
            chainAssets: availableOriginChainAsset,
            selectedAssetId: selectedAmountChainAsset.asset.identifier,
            output: self
        )
    }

    func didTapSelectDestNetwoek() {
        router.showSelectNetwork(
            from: view,
            wallet: wallet,
            selectedChainId: selectedDestChainModel?.chainId,
            chainModels: availableDestChainModels,
            contextTag: nil,
            delegate: self
        )
    }

    func didLoad(view: CrossChainViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideOriginSelectNetworkViewModel()
        provideInputViewModel()
    }

    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapConfirmButton() {
        guard let selectedDestChainModel = selectedDestChainModel,
              let balanceViewModel = balanceViewModel,
              let originChainFee = originNetworkFeeViewModel,
              let destChainFee = destNetworkFeeViewModel,
              let inputAmount = amountInputResult?.absoluteValue(from: originNetworkBalance ?? .zero),
              let substrateAmout = inputAmount.toSubstrateAmount(precision: Int16(selectedAmountChainAsset.asset.precision)),
              let xcmServices = interactor.xcmServices
        else {
            return
        }
        let data = CrossChainConfirmationData(
            wallet: wallet,
            originChainAsset: selectedAmountChainAsset,
            destChainModel: selectedDestChainModel,
            amount: substrateAmout,
            amountViewModel: balanceViewModel,
            originChainFee: originChainFee,
            destChainFee: destChainFee
        )
        router.showConfirmation(
            from: view,
            data: data,
            xcmServices: xcmServices
        )
    }

    func didTapScanButton() {
        router.presentScan(from: view, moduleOutput: self)
    }

    func didTapHistoryButton() {
        router.presentHistory(
            from: view,
            wallet: wallet,
            chainAsset: selectedAmountChainAsset,
            moduleOutput: self
        )
    }

    func didTapMyWalletsButton() {
        router.showWalletManagment(
            from: view,
            moduleOutput: self
        )
    }

    func didTapPasteButton() {
        if let address = UIPasteboard.general.string {
            handle(newAddress: address)
        }
    }

    func searchTextDidChanged(_ text: String) {
        destWallet = nil
        handle(newAddress: text)
    }
}

// MARK: - CrossChainInteractorOutput

extension CrossChainPresenter: CrossChainInteractorOutput {
    func didReceiveDestinationFee(result: Result<XcmFee, Error>) {
        switch result {
        case let .success(response):
            destNetworkFee = Decimal.fromSubstrateAmount(
                response.destXcmFee,
                precision: Int16(selectedAmountChainAsset.asset.precision)
            )

            provideDestNetworkFeeViewModel()
        case let .failure(error):
            logger.customError(error)
        }
    }

    func didReceiveOriginFee(result: SSFExtrinsicKit.FeeExtrinsicResult) {
        switch result {
        case let .success(response):
            if let fee = BigUInt(response.fee), let feeDecimal = Decimal.fromSubstrateAmount(fee, precision: Int16(selectedAmountChainAsset.asset.precision)) {
                originNetworkFee = feeDecimal

                provideOriginNetworkFeeViewModel()
                provideInputViewModel()
            }
        case let .failure(error):
            logger.customError(error)
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
                originNetworkBalance = success.map {
                    Decimal.fromSubstrateAmount(
                        $0.data.sendAvailable,
                        precision: Int16(chainAsset.asset.precision)
                    )
                } ?? .zero
                provideAssetViewModel()
                provideOriginNetworkFeeViewModel()
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
            logger.customError(failure)
        }
    }

    func didReceiveAvailableDestChainAssets(_ chainAssets: [ChainAsset]) {
        let filtredChainAssets = chainAssets
            .filter { $0.chain.chainId != selectedOriginChainModel.chainId }
        availableDestChainModels = filtredChainAssets
            .map { $0.chain }
            .withoutDuplicates()

        if selectedDestChainModel == nil {
            selectedDestChainModel = filtredChainAssets.map { $0.chain }.first
        }
        provideDestSelectNetworkViewModel()

        if let destUtilityChainAsset = filtredChainAssets.first(where: { $0.isUtility }) {
            interactor.didReceive(originChainAsset: nil, destChainAsset: destUtilityChainAsset)

            let inputAmount = amountInputResult?
                .absoluteValue(from: originNetworkBalance ?? .zero) ?? .zero
            interactor.estimateFee(
                originChainAsset: selectedAmountChainAsset,
                destinationChainModel: destUtilityChainAsset.chain,
                amount: inputAmount
            )
        }
    }

    func didSetup() {
        interactor.didReceive(originChainAsset: selectedAmountChainAsset, destChainAsset: nil)
    }

    func didReceiveOrigin(chainAssets: [ChainAsset]) {
        availableOriginChainAsset = chainAssets
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
        interactor.didReceive(originChainAsset: chainAsset, destChainAsset: destUtilityChainAsset)

        if let selectedDestChainModel = selectedDestChainModel {
            let inputAmount = amountInputResult?
                .absoluteValue(from: originNetworkBalance ?? .zero) ?? .zero

            interactor.estimateFee(
                originChainAsset: selectedAmountChainAsset,
                destinationChainModel: selectedDestChainModel,
                amount: inputAmount
            )

            provideInputViewModel()
        }
    }
}

// MARK: - SelectNetworkDelegate

extension CrossChainPresenter: SelectNetworkDelegate {
    func chainSelection(
        view _: SelectNetworkViewInput,
        didCompleteWith chain: ChainModel?,
        contextTag _: Int?
    ) {
        guard let chain = chain else {
            return
        }

        selectedDestChainModel = chain
        provideDestSelectNetworkViewModel()
        provideAddress()

        if let destUtilityChainAsset = chain.utilityChainAssets().first(where: { $0.isUtility }) {
            interactor.didReceive(originChainAsset: selectedAmountChainAsset, destChainAsset: destUtilityChainAsset)
            let inputAmount = amountInputResult?
                .absoluteValue(from: originNetworkBalance ?? .zero) ?? .zero
            interactor.estimateFee(
                originChainAsset: selectedAmountChainAsset,
                destinationChainModel: destUtilityChainAsset.chain,
                amount: inputAmount
            )

            provideInputViewModel()
        }
    }
}

// MARK: - ScanQRModuleOutput

extension CrossChainPresenter: ScanQRModuleOutput {
    func didFinishWith(address: String) {
        handle(newAddress: address)
    }
}

// MARK: - ContactsModuleOutput

extension CrossChainPresenter: ContactsModuleOutput {
    func didSelect(address: String) {
        handle(newAddress: address)
    }
}

// MARK: - WalletsManagmentModuleOutput

extension CrossChainPresenter: WalletsManagmentModuleOutput {
    func selectedWallet(_ wallet: MetaAccountModel, for _: Int) {
        guard
            let chain = selectedDestChainModel,
            let accountId = wallet.fetch(for: chain.accountRequest())?.accountId,
            let address = try? AddressFactory.address(for: accountId, chain: chain)
        else {
            return
        }

        let viewModel = viewModelFactory.buildRecipientViewModel(
            address: address,
            isValid: true
        )
        view?.didReceive(recipientViewModel: viewModel)
        destWallet = wallet
        recipientAddress = address
    }
}
