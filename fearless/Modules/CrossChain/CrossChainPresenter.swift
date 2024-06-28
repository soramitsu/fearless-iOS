import Foundation
import SoraFoundation
import SSFXCM
import BigInt
import SSFExtrinsicKit
import SSFUtils
import SSFModels
import SSFQRService

protocol CrossChainViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(assetBalanceViewModel: AssetBalanceViewModelProtocol?)
    func didReceive(amountInputViewModel: IAmountInputViewModel?)
    func didReceive(originSelectNetworkViewModel: SelectNetworkViewModel)
    func didReceive(destSelectNetworkViewModel: SelectNetworkViewModel?)
    func didReceive(originFeeViewModel: LocalizableResource<BalanceViewModelProtocol>?)
    func didReceive(destinationFeeViewModel: LocalizableResource<BalanceViewModelProtocol>?)
    func didReceive(recipientViewModel: RecipientViewModel)
    func setButtonLoadingState(isLoading: Bool)
}

protocol CrossChainInteractorInput: AnyObject {
    var deps: CrossChainDepsContainer.CrossChainConfirmationDeps? { get }
    func setup(with output: CrossChainInteractorOutput)
    func didReceive(originChainAsset: ChainAsset?)
    func didReceive(destinationChain: ChainModel)
    func estimateFee(originChainAsset: ChainAsset, destinationChainModel: ChainModel, amount: Decimal?)
    func validate(address: String?, for chain: ChainModel) -> AddressValidationResult
    func fetchDestinationAccountInfo(address: String)
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
    private var destExistentialDeposit: BigUInt?
    private var destAccountInfo: AccountInfo?
    private var assetAccountInfo: AssetAccountInfo?

    private var prices: [PriceData] = []

    private var destWallet: MetaAccountModel?
    private var recipientAddress: String?
    private var selectedDestChainModel: ChainModel? {
        didSet {
            guard let selectedDestChainModel else {
                return
            }

            interactor.didReceive(destinationChain: selectedDestChainModel)

            if let wallet = destWallet, let address = wallet.fetch(for: selectedDestChainModel.accountRequest())?.toAddress() {
                interactor.fetchDestinationAccountInfo(address: address)
            } else if let address = recipientAddress {
                interactor.fetchDestinationAccountInfo(address: address)
            }
        }
    }

    private var availableDestChainModels: [ChainModel] = []

    private var originNetworkFee: Decimal?
    private var destNetworkFee: Decimal?
    private var inputViewModel: IAmountInputViewModel?
    private var originNetworkFeeViewModel: BalanceViewModelProtocol?
    private var destNetworkFeeViewModel: BalanceViewModelProtocol?

    private var loadingCollector = CrossChainViewLoadingCollector()

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

    private func runLoadingState() {
        view?.setButtonLoadingState(isLoading: true)
        loadingCollector.reset()
    }

    private func checkLoadingState() {
        guard let isReady = loadingCollector.isReady else {
            return
        }
        view?.setButtonLoadingState(isLoading: !isReady)
    }

    private func provideInputViewModel() {
        let balanceViewModelFactory = buildBalanceViewModelFactory(
            wallet: wallet,
            for: selectedAmountChainAsset
        )
        let inputAmount = calculateAbsoluteValue()
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

        let inputAmount = calculateAbsoluteValue()
        let locked = assetAccountInfo.map { Decimal.fromSubstrateAmount($0.locked, precision: Int16(selectedAmountChainAsset.asset.precision)) }?.or(.zero)
        let balance = originNetworkSelectedAssetBalance - locked.or(.zero)
        let priceData = prices.first(where: { $0.priceId == selectedAmountChainAsset.asset.priceId })
        let assetBalanceViewModel = balanceViewModelFactory?.createAssetBalanceViewModel(
            inputAmount,
            balance: balance,
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
            view?.didReceive(destSelectNetworkViewModel: nil)
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

        loadingCollector.originFeeReady = true
        checkLoadingState()
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

        loadingCollector.destinationFeeReady = true
        checkLoadingState()
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
        loadingCollector.addressExists = !newAddress.isEmpty
        checkLoadingState()
        interactor.fetchDestinationAccountInfo(address: newAddress)
        recipientAddress = newAddress
        let viewModel = viewModelFactory.buildRecipientViewModel(address: newAddress)
        view?.didReceive(recipientViewModel: viewModel)
    }

    private func provideAddress() {
        if let destWallet = destWallet {
            selectedWallet(destWallet, for: 0)
        } else {
            guard let chain = selectedDestChainModel else {
                return
            }
            let isValid = interactor.validate(address: recipientAddress, for: chain).isValidOrSame
            if isValid, let recipientAddress = recipientAddress {
                handle(newAddress: recipientAddress)
            } else {
                handle(newAddress: "")
            }
        }
    }

    private func calculateAbsoluteValue() -> Decimal? {
        amountInputResult?
            .absoluteValue(from: originNetworkSelectedAssetBalance - (destNetworkFee ?? .zero) - originNetworkFeeIfRequired())
    }

    private func continueWithValidation() {
        guard let utilityChainAsset = selectedAmountChainAsset.chain.utilityChainAssets().first else {
            return
        }
        let utilityBalance = Decimal.fromSubstrateAmount(originNetworkUtilityTokenBalance, precision: Int16(utilityChainAsset.asset.precision))
        let minimumBalance = Decimal.fromSubstrateAmount(existentialDeposit ?? .zero, precision: Int16(utilityChainAsset.asset.precision)) ?? .zero
        let inputAmountDecimal = amountInputResult?
            .absoluteValue(from: originNetworkSelectedAssetBalance - (destNetworkFee ?? .zero) - originNetworkFeeIfRequired()) ?? .zero
        let edParameters: ExistentialDepositValidationParameters = .utility(
            spendingAmount: originNetworkFeeIfRequired() + inputAmountDecimal,
            totalAmount: utilityBalance,
            minimumBalance: minimumBalance
        )
        let destChainAsset = selectedDestChainModel.map {
            ChainAsset(chain: $0, asset: selectedAmountChainAsset.asset)
        }

        let destBalanceDecimal: Decimal? = (destAccountInfo?.data.sendAvailable).flatMap {
            guard let destChainAsset else {
                return nil
            }

            return Decimal.fromSubstrateAmount($0, precision: Int16(destChainAsset.asset.precision))
        }

        let destMinimumBalance: Decimal? = destExistentialDeposit.flatMap {
            Decimal.fromSubstrateAmount($0, precision: Int16(utilityChainAsset.asset.precision))
        }

        let totalDestinationAmount = destBalanceDecimal.map { $0 + inputAmountDecimal }

        let destEdParameters: ExistentialDepositValidationParameters = .utility(
            spendingAmount: 0,
            totalAmount: totalDestinationAmount,
            minimumBalance: destMinimumBalance
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

        let sendAmount = inputAmountDecimal
        let balanceType: BalanceType

        if selectedAmountChainAsset.chainAssetId == utilityChainAsset.chainAssetId {
            balanceType = .utility(balance: utilityBalance)
        } else {
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
            chainAsset: selectedAmountChainAsset,
            canProceedIfViolated: false,
            proceedAction: {},
            setMaxAction: {},
            cancelAction: {}
        )

        let soraBridgeViolated = dataValidatingFactory.soraBridgeViolated(
            originCHain: selectedOriginChainModel,
            destChain: selectedDestChainModel,
            amount: inputAmountDecimal,
            locale: selectedLocale,
            asset: selectedAmountChainAsset.asset
        )

        let soraBridgeAmountLessFeeViolated = dataValidatingFactory.soraBridgeAmountLessFeeViolated(
            originCHainId: selectedOriginChainModel.chainId,
            destChainId: selectedDestChainModel?.chainId,
            amount: inputAmountDecimal,
            fee: destNetworkFee,
            locale: selectedLocale
        )

        let validators: [DataValidating] = [
            originFeeValidating,
            canPayOriginalFeeAndAmount,
            exsitentialDepositIsNotViolated,
            destFeeValidating,
            soraBridgeViolated,
            soraBridgeAmountLessFeeViolated
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
              let inputAmount = calculateAbsoluteValue(),
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
        let inputAmount = calculateAbsoluteValue().or(1)
        view?.setButtonLoadingState(isLoading: true)
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

    private func originNetworkFeeIfRequired() -> Decimal {
        if let utilityChainAsset = selectedAmountChainAsset.chain.utilityChainAssets().first,
           selectedAmountChainAsset.chainAssetId == utilityChainAsset.chainAssetId,
           let fee = originNetworkFee {
            return fee
        }
        return .zero
    }

    private func deriveTransferableBalance() {
        let totalBalance = Decimal.fromSubstrateAmount(
            originNetworkBalanceValue,
            precision: Int16(selectedAmountChainAsset.asset.precision)
        ) ?? .zero
        var minimumBalance: Decimal = .zero
        if let utilityChainAsset = selectedAmountChainAsset.chain.utilityChainAssets().first {
            minimumBalance = Decimal.fromSubstrateAmount(existentialDeposit ?? .zero, precision: Int16(utilityChainAsset.asset.precision)) ?? .zero
        }

        originNetworkSelectedAssetBalance = totalBalance - (destNetworkFee ?? .zero) - originNetworkFeeIfRequired() - (minimumBalance * 1.1)
        provideAssetViewModel()
    }
}

// MARK: - CrossChainViewOutput

extension CrossChainPresenter: CrossChainViewOutput {
    func selectAmountPercentage(_ percentage: Float) {
        loadingCollector.originFeeReady = false
        view?.setButtonLoadingState(isLoading: true)
        amountInputResult = .rate(Decimal(Double(percentage)))
        provideAssetViewModel()
        provideInputViewModel()
        estimateFee()
    }

    func updateAmount(_ newValue: Decimal) {
        loadingCollector.originFeeReady = false
        view?.setButtonLoadingState(isLoading: true)
        amountInputResult = .absolute(newValue)
        provideAssetViewModel()
        estimateFee()
    }

    func didTapSelectAsset() {
        router.showSelectAsset(
            from: view,
            wallet: wallet,
            chainAssets: availableOriginChainAssets,
            selectedAssetId: selectedAmountChainAsset.asset.id,
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
        provideDestSelectNetworkViewModel()
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
            loadingCollector.balanceReady = true
            checkLoadingState()

            if receiveUniqueKey == selectedAmountChainAsset.uniqueKey(accountId: accountId) {
                deriveTransferableBalance()
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
            deriveTransferableBalance()
            loadingCollector.existentialDepositReady = true
            checkLoadingState()
        case let .failure(error):
            logger.customError(error)
        }
    }

    func didReceiveDestinationExistentialDeposit(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(value):
            destExistentialDeposit = value
            loadingCollector.destinationExistentialDepositReady = true
            checkLoadingState()
        case let .failure(error):
            logger.customError(error)
            loadingCollector.destinationExistentialDepositReady = true
            checkLoadingState()
        }
    }

    func didReceiveDestinationAccountInfo(accountInfo: AccountInfo?) {
        destAccountInfo = accountInfo
        loadingCollector.destinationBalanceReady = true
        checkLoadingState()
    }

    func didReceiveDestinationAccountInfoError(error: Error) {
        logger.customError(error)
        loadingCollector.destinationBalanceReady = true
        checkLoadingState()
    }

    func didReceiveAssetAccountInfo(assetAccountInfo: AssetAccountInfo?) {
        loadingCollector.assetAccountInfoReady = true
        checkLoadingState()
        self.assetAccountInfo = assetAccountInfo

        provideAssetViewModel()
    }

    func didReceiveAssetAccountInfoError(error: Error) {
        loadingCollector.assetAccountInfoReady = true
        logger.customError(error)
        checkLoadingState()
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
        runLoadingState()

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
        runLoadingState()

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
    func didFinishWith(scanType: QRMatcherType) {
        guard let address = scanType.address else {
            return
        }
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
        destWallet = wallet
        guard
            let chain = selectedDestChainModel,
            let accountId = wallet.fetch(for: chain.accountRequest())?.accountId,
            let address = try? AddressFactory.address(for: accountId, chain: chain)
        else {
            let viewModel = viewModelFactory.buildRecipientViewModel(address: wallet.name)
            view?.didReceive(recipientViewModel: viewModel)
            return
        }

        let viewModel = viewModelFactory.buildRecipientViewModel(address: address)
        view?.didReceive(recipientViewModel: viewModel)
        recipientAddress = address
        loadingCollector.addressExists = true
        checkLoadingState()
        interactor.fetchDestinationAccountInfo(address: address)
    }
}
