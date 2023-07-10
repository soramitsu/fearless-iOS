import Foundation
import SoraFoundation
import SSFXCM
import Web3
import SSFExtrinsicKit
import SSFUtils
import SSFModels

protocol CrossChainViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(assetBalanceViewModel: AssetBalanceViewModelProtocol?)
    func didReceive(amountInputViewModel: IAmountInputViewModel?)
    func didReceive(originSelectNetworkViewModel: SelectNetworkViewModel)
    func didReceive(destSelectNetworkViewModel: SelectNetworkViewModel)
    func didReceive(originFeeViewModel: LocalizableResource<BalanceViewModelProtocol>?)
    func didReceive(destinationFeeViewModel: LocalizableResource<BalanceViewModelProtocol>?)
    func didReceive(recipientViewModel: RecipientViewModel)
}

protocol CrossChainInteractorInput: AnyObject {
    var deps: CrossChainDepsContainer.CrossChainConfirmationDeps? { get }
    func setup(with output: CrossChainInteractorOutput)
    func didReceive(originChainAsset: ChainAsset?)
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
    private let dataValidatingFactory: SendDataValidatingFactory

    private let selectedOriginChainModel: ChainModel
    private var selectedAmountChainAsset: ChainAsset
    private var amountInputResult: AmountInputResult?
    private var availableOriginChainAssets: [ChainAsset] = []

    private var originNetworkBalanceValue: BigUInt = .zero
    private var originNetworkSelectedAssetBalance: Decimal = .zero
    private var originNetworkUtilityTokenBalance: BigUInt = .zero
    private var existentialDeposit: BigUInt?

    private var prices: [PriceData] = []

    private var destWallet: MetaAccountModel?
    private var recipientAddress: String?
    private var selectedDestChainModel: ChainModel?
    private var availableDestChainModels: [ChainModel] = []

    private var originNetworkFee: Decimal?
    private var destNetworkFee: Decimal?
    private var inputViewModel: IAmountInputViewModel?
    private var originNetworkFeeViewModel: BalanceViewModelProtocol?
    private var destNetworkFeeViewModel: BalanceViewModelProtocol?

    // MARK: - Constructors

    init(
        originChainAsset: ChainAsset,
        wallet: MetaAccountModel,
        viewModelFactory: CrossChainViewModelFactoryProtocol,
        dataValidatingFactory: SendDataValidatingFactory,
        logger: LoggerProtocol,
        interactor: CrossChainInteractorInput,
        router: CrossChainRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        selectedAmountChainAsset = originChainAsset
        selectedOriginChainModel = originChainAsset.chain
        self.wallet = wallet
        self.viewModelFactory = viewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
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
            .absoluteValue(from: originNetworkSelectedAssetBalance - (destNetworkFee ?? .zero))
        let inputViewModel = balanceViewModelFactory?
            .createBalanceInputViewModel(inputAmount)
            .value(for: selectedLocale)
        self.inputViewModel = inputViewModel

        view?.didReceive(amountInputViewModel: inputViewModel)
    }

    private func provideAssetViewModel() {
        let balanceViewModelFactory = buildBalanceViewModelFactory(
            wallet: wallet,
            for: selectedAmountChainAsset
        )

        let inputAmount = amountInputResult?
            .absoluteValue(from: originNetworkSelectedAssetBalance)

        let priceData = prices.first(where: { $0.priceId == selectedAmountChainAsset.asset.priceId })
        let assetBalanceViewModel = balanceViewModelFactory?.createAssetBalanceViewModel(
            inputAmount,
            balance: originNetworkSelectedAssetBalance,
            priceData: priceData
        ).value(for: selectedLocale)

        view?.didReceive(assetBalanceViewModel: assetBalanceViewModel)
    }

    private func provideOriginSelectNetworkViewModel() {
        let viewModel = viewModelFactory.buildNetworkViewModel(chain: selectedOriginChainModel)
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
            let utilityOriginChainAsset = selectedAmountChainAsset.chain.utilityChainAssets().first,
            let originNetworkFee = originNetworkFee,
            let viewModelFactory = buildBalanceViewModelFactory(
                wallet: wallet,
                for: utilityOriginChainAsset
            )
        else {
            view?.didReceive(originFeeViewModel: nil)
            return
        }

        let priceData = prices.first(where: { $0.priceId == utilityOriginChainAsset.asset.priceId })
        let viewModel = viewModelFactory.balanceFromPrice(
            originNetworkFee,
            priceData: priceData,
            usageCase: .detailsCrypto
        )

        originNetworkFeeViewModel = viewModel.value(for: selectedLocale)
        view?.didReceive(originFeeViewModel: viewModel)
    }

    private func provideDestNetworkFeeViewModel() {
        guard
            let destNetworkFee = destNetworkFee,
            let viewModelFactory = buildBalanceViewModelFactory(
                wallet: wallet,
                for: selectedAmountChainAsset
            )
        else {
            view?.didReceive(destinationFeeViewModel: nil)
            return
        }

        let priceData = prices.first(where: { $0.priceId == selectedAmountChainAsset.asset.priceId })
        let viewModel = viewModelFactory.balanceFromPrice(
            destNetworkFee,
            priceData: priceData,
            usageCase: .detailsCrypto
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
        DispatchQueue.main.async {
            self.provideAssetViewModel()
            self.provideOriginNetworkFeeViewModel()
            self.provideDestNetworkFeeViewModel()
        }
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

    private func continueWithValidation() {
        let inputAmountDecimal = amountInputResult?
            .absoluteValue(from: originNetworkSelectedAssetBalance - (destNetworkFee ?? .zero)) ?? .zero

        guard let utilityChainAsset = selectedAmountChainAsset.chain.utilityChainAssets().first else {
            return
        }
        let spendingAmount = originNetworkFee?.toSubstrateAmount(precision: Int16(utilityChainAsset.asset.precision))
        let edParameters: ExistentialDepositValidationParameters = .utility(
            spendingAmount: spendingAmount,
            totalAmount: originNetworkUtilityTokenBalance,
            minimumBalance: existentialDeposit
        )

        let originFeeValidating = dataValidatingFactory.has(
            fee: originNetworkFee,
            locale: selectedLocale
        ) { [weak self] in
            self?.estimateFee()
        }

        let destFeeValidating = dataValidatingFactory.has(
            fee: destNetworkFee,
            locale: selectedLocale,
            onError: { [weak self] in
                self?.estimateFee()
            }
        )

        let sendAmount: Decimal
        let balanceType: BalanceType
        let utilityBalance = Decimal.fromSubstrateAmount(originNetworkUtilityTokenBalance, precision: Int16(utilityChainAsset.asset.precision))
        if selectedAmountChainAsset.chainAssetId == utilityChainAsset.chainAssetId {
            sendAmount = inputAmountDecimal + (originNetworkFee ?? .zero)
            balanceType = .utility(balance: utilityBalance)
        } else {
            sendAmount = inputAmountDecimal
            balanceType = .orml(balance: originNetworkSelectedAssetBalance, utilityBalance: utilityBalance)
        }

        let canPayOriginalFeeAndAmount = dataValidatingFactory.canPayFeeAndAmount(
            balanceType: balanceType,
            feeAndTip: originNetworkFee,
            sendAmount: sendAmount,
            locale: selectedLocale
        )

        let exsitentialDepositIsNotViolated = dataValidatingFactory.exsitentialDepositIsNotViolated(
            parameters: edParameters,
            locale: selectedLocale,
            chainAsset: selectedAmountChainAsset
        )

        let validators: [DataValidating] = [
            originFeeValidating,
            canPayOriginalFeeAndAmount,
            exsitentialDepositIsNotViolated,
            destFeeValidating
        ]
        DataValidationRunner(validators: validators)
            .runValidation { [weak self] in
                self?.prepareAndShowConfirmation()
            }
    }

    private func prepareAndShowConfirmation() {
        guard let selectedDestChainModel = selectedDestChainModel,
              let inputViewModel = inputViewModel,
              let originChainFee = originNetworkFeeViewModel,
              let destChainFee = destNetworkFeeViewModel,
              let inputAmount = amountInputResult?.absoluteValue(from: originNetworkSelectedAssetBalance),
              let substrateAmout = inputAmount.toSubstrateAmount(precision: Int16(selectedAmountChainAsset.asset.precision)),
              let xcmServices = interactor.deps?.xcmServices,
              let recipientAddress = recipientAddress,
              let destChainFeeDecimal = destNetworkFee
        else {
            return
        }
        let data = CrossChainConfirmationData(
            wallet: wallet,
            originChainAsset: selectedAmountChainAsset,
            destChainModel: selectedDestChainModel,
            amount: substrateAmout,
            displayAmount: inputViewModel.displayAmount,
            originChainFee: originChainFee,
            destChainFee: destChainFee,
            destChainFeeDecimal: destChainFeeDecimal,
            recipientAddress: recipientAddress
        )
        guard addressIsValid() else {
            return
        }
        router.showConfirmation(
            from: view,
            data: data,
            xcmServices: xcmServices
        )
    }

    private func estimateFee() {
        guard let selectedDestChainModel = selectedDestChainModel else {
            return
        }
        let inputAmount = amountInputResult?
            .absoluteValue(from: originNetworkSelectedAssetBalance) ?? 1

        interactor.estimateFee(
            originChainAsset: selectedAmountChainAsset,
            destinationChainModel: selectedDestChainModel,
            amount: inputAmount
        )
    }

    private func addressIsValid() -> Bool {
        guard let selectedDestChainModel = selectedDestChainModel else {
            return false
        }
        let validAddressResult = interactor.validate(address: recipientAddress, for: selectedDestChainModel)

        switch validAddressResult {
        case .valid, .sameAddress:
            return true
        case .invalid:
            showInvalidAddressAlert()
            return false
        }
    }

    private func showInvalidAddressAlert() {
        let message = R.string.localizable
            .xcmCrossChainInvalidAddressMessage(preferredLanguages: selectedLocale.rLanguages)
        let title = R.string.localizable
            .xcmCrossChainInvalidAddressTitle(preferredLanguages: selectedLocale.rLanguages)
        router.present(
            message: message,
            title: title,
            closeAction: R.string.localizable.commonOk(preferredLanguages: selectedLocale.rLanguages),
            from: view,
            actions: []
        )
    }
}

// MARK: - CrossChainViewOutput

extension CrossChainPresenter: CrossChainViewOutput {
    func selectAmountPercentage(_ percentage: Float) {
        view?.didStartLoading()
        amountInputResult = .rate(Decimal(Double(percentage)))
        provideAssetViewModel()
        provideInputViewModel()
        estimateFee()
    }

    func updateAmount(_ newValue: Decimal) {
        view?.didStartLoading()
        amountInputResult = .absolute(newValue)
        provideAssetViewModel()
        estimateFee()
    }

    func didTapSelectAsset() {
        router.showSelectAsset(
            from: view,
            wallet: wallet,
            chainAssets: availableOriginChainAssets,
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

    func didTapContinueButton() {
        continueWithValidation()
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
            selectedWalletId: destWallet?.metaId,
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
    func didReceiveDestinationFee(result: Result<DestXcmFee, Error>) {
        switch result {
        case let .success(response):
            guard let feeInPlanks = response.feeInPlanks else {
                return
            }
            var precision = Int16(selectedAmountChainAsset.asset.precision)
            if let destinationPrecision = response.precision,
               let intDestPrecision = Int16(destinationPrecision) {
                precision = intDestPrecision
            }
            destNetworkFee = Decimal.fromSubstrateAmount(
                feeInPlanks,
                precision: precision
            )

        case let .failure(error):
            destNetworkFee = nil
            logger.customError(error)
        }
        provideDestNetworkFeeViewModel()
    }

    func didReceiveOriginFee(result: SSFExtrinsicKit.FeeExtrinsicResult) {
        view?.didStopLoading()
        switch result {
        case let .success(response):
            guard
                let utilityOriginChainAsset = selectedAmountChainAsset.chain.utilityChainAssets().first,
                let fee = BigUInt(string: response.fee),
                let feeDecimal = Decimal.fromSubstrateAmount(fee, precision: Int16(utilityOriginChainAsset.asset.precision))
            else {
                return
            }
            originNetworkFee = feeDecimal
        case let .failure(error):
            originNetworkFee = nil
            logger.customError(error)
        }
        provideOriginNetworkFeeViewModel()
    }

    func didReceivePricesData(result: Result<[PriceData], Error>) {
        switch result {
        case let .success(prices):
            self.prices = self.prices.filter { !prices.map { $0.priceId }.contains($0.priceId) }
            self.prices.append(contentsOf: prices)
            providePrices()
        case let .failure(error):
            logger.customError(error)
        }
    }

    func didReceiveAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId: AccountId,
        chainAsset: ChainAsset
    ) {
        let receiveUniqueKey = chainAsset.uniqueKey(accountId: accountId)

        switch result {
        case let .success(success):
            originNetworkBalanceValue = success?.data.sendAvailable ?? .zero
            if receiveUniqueKey == selectedAmountChainAsset.uniqueKey(accountId: accountId) {
                originNetworkSelectedAssetBalance = success.map {
                    Decimal.fromSubstrateAmount(
                        $0.data.sendAvailable,
                        precision: Int16(chainAsset.asset.precision)
                    ) ?? .zero
                } ?? .zero
                provideAssetViewModel()
            }
            if let originUtilityChainAsset = selectedAmountChainAsset.chain.utilityChainAssets().first,
               receiveUniqueKey == originUtilityChainAsset.uniqueKey(accountId: accountId) {
                originNetworkUtilityTokenBalance = success?.data.sendAvailable ?? .zero
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
        estimateFee()
    }

    func didSetup() {
        interactor.didReceive(originChainAsset: selectedAmountChainAsset)
    }

    func didReceiveOrigin(chainAssets: [ChainAsset]) {
        availableOriginChainAssets = chainAssets
    }

    func didReceiveExistentialDeposit(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(existentialDeposit):
            self.existentialDeposit = existentialDeposit
        case let .failure(error):
            logger.customError(error)
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

        view?.didStartLoading()

        destNetworkFee = nil
        originNetworkFee = nil
        provideOriginNetworkFeeViewModel()
        provideDestNetworkFeeViewModel()

        selectedAmountChainAsset = chainAsset
        selectedDestChainModel = nil
        interactor.didReceive(originChainAsset: chainAsset)
        estimateFee()
        provideInputViewModel()
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

        view?.didStartLoading()

        destNetworkFee = nil
        originNetworkFee = nil
        provideOriginNetworkFeeViewModel()
        provideDestNetworkFeeViewModel()

        selectedDestChainModel = chain
        provideDestSelectNetworkViewModel()
        provideAddress()
        interactor.didReceive(originChainAsset: selectedAmountChainAsset)
        estimateFee()
        provideInputViewModel()
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
