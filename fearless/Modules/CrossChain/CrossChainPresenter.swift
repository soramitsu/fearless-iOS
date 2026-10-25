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
    private let reviewedRoute: ReviewedCrossChainRouteContext
    private let viewModelFactory: CrossChainViewModelFactoryProtocol
    private let dataValidatingFactory: SendDataValidatingFactory

    private let selectedOriginChainModel: ChainModel
    private var selectedAmountChainAsset: ChainAsset
    private var amountInputResult: AmountInputResult?
    private var availableOriginChainAssets: [ChainAsset] = []

    private var originNetworkBalanceValue: BigUInt = .zero
    private var originNetworkSelectedAssetBalance: Decimal = .zero
    private var originNetworkUtilityTokenBalance: BigUInt = .zero
    private var originBalanceAvailable = false
    private var existentialDeposit: BigUInt?
    private var destExistentialDeposit: BigUInt?
    private var destinationProblem: Error?
    private var destAccountInfo: AccountInfo?
    private var assetAccountInfo: AssetAccountInfo?

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
        reviewedRoute: ReviewedCrossChainRouteContext,
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
        self.reviewedRoute = reviewedRoute
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
        let priceData = selectedAmountChainAsset.asset.getPrice(for: wallet.selectedCurrency)
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

        let priceData = utilityOriginChainAsset.asset.getPrice(for: wallet.selectedCurrency)
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

        let priceData = selectedAmountChainAsset.asset.getPrice(for: wallet.selectedCurrency)
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

    private func handle(newAddress: String) {
        loadingCollector.addressExists = !newAddress.isEmpty
        checkLoadingState()
        interactor.fetchDestinationAccountInfo(address: newAddress)
        recipientAddress = newAddress
        let isValid = selectedDestChainModel.map {
            interactor.validate(address: recipientAddress, for: $0).isValidOrSame &&
                !recipientIsSystemAccount(newAddress, on: $0)
        }.or(true)
        if selectedDestChainModel != nil, !isValid, newAddress.isNotEmpty {
            showInvalidAddressAlert()
        }
        let viewModel = viewModelFactory.buildRecipientViewModel(address: newAddress, isValid: isValid)
        view?.didReceive(recipientViewModel: viewModel)
    }

    /// The all-zero, pallet and sovereign accounts parse as valid addresses, but no person can spend from them.
    private func recipientIsSystemAccount(_ address: String, on chain: ChainModel) -> Bool {
        guard address.isNotEmpty, let accountId = try? AddressFactory.accountId(from: address, chain: chain) else {
            return false
        }
        return ReviewedCrossChainRecipientPolicy.rejects(accountId)
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
            } else if recipientAddress?.isNotEmpty == true {
                handle(newAddress: "")
            }
        }
    }

    /// The amount field shows at most this many decimals.
    private static let displayedFractionDigits: Int16 = 6

    /// The amount that is validated, shown on the confirmation screen and signed. A percentage resolves against a balance
    /// and fees that keep arriving after the tap, so it is truncated to the decimals the amount field shows: the
    /// confirmation then displays exactly the amount that is signed.
    private func calculateAbsoluteValue() -> Decimal? {
        guard let amountInputResult else {
            return nil
        }
        let available = originNetworkSelectedAssetBalance - (destNetworkFee ?? .zero) - originNetworkFeeIfRequired()
        let value = amountInputResult.absoluteValue(from: available)
        guard case .rate = amountInputResult else {
            return value
        }
        var exact = value
        var truncated = Decimal()
        let scale = Int(min(Self.displayedFractionDigits, Int16(selectedAmountChainAsset.asset.precision)))
        NSDecimalRound(&truncated, &exact, scale, .down)
        return truncated
    }

    /// Facts the reviewed route needs before any amount check can be trusted. Each one that is unknown stops the
    /// transfer with an explanation instead of being treated as zero.
    private func reviewedRouteProblem(amount: BigUInt?) -> String? {
        guard ReviewedXcmRouteRegistry.definition(for: reviewedRoute) != nil else {
            return ReviewedCrossChainSubmissionError.unreviewedRoute.localizedDescription
        }
        if let destinationProblem {
            return destinationProblem.localizedDescription
        }
        guard originBalanceAvailable else {
            return ReviewedCrossChainSubmissionError.balanceUnavailable.localizedDescription
        }
        guard existentialDeposit != nil else {
            return NSLocalizedString(
                "cross_chain.origin_minimum_unavailable",
                value: "The origin network's minimum balance is unavailable. Try again in a moment.",
                comment: ""
            )
        }
        guard destExistentialDeposit != nil else {
            return CrossChainFormError.destinationExistentialDepositUnavailable.localizedDescription
        }
        guard let amount, amount > .zero else {
            return ReviewedCrossChainSubmissionError.invalidAmount.localizedDescription
        }
        if let selectedDestChainModel, let recipientAddress,
           recipientIsSystemAccount(recipientAddress, on: selectedDestChainModel) {
            return ReviewedCrossChainSubmissionError.invalidRecipient.localizedDescription
        }
        return nil
    }

    private func presentRouteProblem(_ message: String) {
        router.present(
            message: message,
            title: NSLocalizedString("cross_chain.route_unavailable", value: "Route unavailable", comment: ""),
            closeAction: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages),
            from: view,
            actions: []
        )
    }

    /// What the recipient holds afterwards, in the destination asset: their current balance plus the amount, which the
    /// bridge credits in full because the destination fee is added to the burn.
    private func destinationBalanceAfterTransfer(amount: Decimal) -> Decimal {
        guard
            let selectedDestChainModel,
            let definition = ReviewedXcmRouteRegistry.definition(for: reviewedRoute),
            let destinationAsset = ReviewedXcmRouteRegistry.destinationChainAsset(for: definition, in: selectedDestChainModel),
            let accountInfo = destAccountInfo,
            let current = Decimal.fromSubstrateAmount(
                accountInfo.data.total,
                precision: Int16(destinationAsset.asset.precision)
            )
        else {
            return amount
        }
        return current + amount
    }

    private func continueWithValidation() {
        guard let utilityChainAsset = selectedAmountChainAsset.chain.utilityChainAssets().first else {
            return
        }
        let utilityBalance = Decimal.fromSubstrateAmount(originNetworkUtilityTokenBalance, precision: Int16(utilityChainAsset.asset.precision))
        let minimumBalance = Decimal.fromSubstrateAmount(existentialDeposit ?? .zero, precision: Int16(utilityChainAsset.asset.precision)) ?? .zero
        let inputAmountDecimal = calculateAbsoluteValue() ?? .zero
        let substrateAmount = inputAmountDecimal.toSubstrateAmount(precision: Int16(selectedAmountChainAsset.asset.precision))
        let reviewedRouteChecks = ErrorThrowingViolation(onError: { [weak self] message in
            self?.presentRouteProblem(message)
        }, preservesCondition: { [weak self] in
            self?.reviewedRouteProblem(amount: substrateAmount)
        })
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

        let spending: Decimal
        if selectedAmountChainAsset.isUtility {
            spending = originNetworkFee.or(.zero) + inputAmountDecimal
        } else {
            spending = originNetworkFee.or(.zero)
        }

        let exsitentialDepositIsNotViolated = dataValidatingFactory.exsitentialDepositIsNotViolated(
            spending: spending,
            balance: utilityBalance.or(.zero),
            minimumBalance: minimumBalance,
            chainAsset: selectedAmountChainAsset,
            locale: selectedLocale,
            canProceedIfViolated: false,
            proceedAction: {},
            setMaxAction: {},
            cancelAction: {}
        )

        let reviewedMinimumIsNotViolated = dataValidatingFactory.reviewedBridgeMinimumIsNotViolated(
            amount: substrateAmount,
            origin: selectedAmountChainAsset,
            destination: selectedDestChainModel,
            locale: selectedLocale
        )

        let destinationMinimumBalance = selectedDestChainModel
            .flatMap { chain in
                ReviewedXcmRouteRegistry.definition(for: reviewedRoute).flatMap {
                    ReviewedXcmRouteRegistry.destinationChainAsset(for: $0, in: chain)
                }
            }
            .flatMap { destinationAsset in
                destExistentialDeposit.flatMap {
                    Decimal.fromSubstrateAmount($0, precision: Int16(destinationAsset.asset.precision))
                }
            }
        let destinationExistentialDepositIsNotViolated = dataValidatingFactory.destinationExistentialDepositIsNotViolated(
            willReceived: destinationBalanceAfterTransfer(amount: inputAmountDecimal),
            minimumBalance: destinationMinimumBalance ?? .zero,
            locale: selectedLocale,
            chainAsset: selectedAmountChainAsset
        )

        let validators: [DataValidating] = [
            reviewedRouteChecks,
            originFeeValidating,
            canPayOriginalFeeAndAmount,
            exsitentialDepositIsNotViolated,
            destFeeValidating,
            reviewedMinimumIsNotViolated,
            destinationExistentialDepositIsNotViolated
        ]
        DataValidationRunner(validators: validators)
            .runValidation { [weak self] in
                self?.prepareAndShowConfirmation()
            }
    }

    private func prepareAndShowConfirmation() {
        guard let selectedDestChainModel = selectedDestChainModel,
              let originChainFee = originNetworkFeeViewModel,
              let destChainFee = destNetworkFeeViewModel,
              let inputAmount = calculateAbsoluteValue(),
              let substrateAmout = inputAmount.toSubstrateAmount(precision: Int16(selectedAmountChainAsset.asset.precision)),
              let recipientAddress = recipientAddress,
              let destChainFeeDecimal = destNetworkFee
        else {
            presentRouteProblem(
                NSLocalizedString(
                    "cross_chain.quote_incomplete",
                    value: "The transfer could not be prepared because a fee, the amount or the recipient is missing. Check them and try again.",
                    comment: ""
                )
            )
            return
        }
        // Formatted from the same value that is signed, at the time it is signed. The field's view model can still hold
        // the amount from when a percentage was tapped, before the fees arrived.
        let displayAmount = buildBalanceViewModelFactory(wallet: wallet, for: selectedAmountChainAsset)?
            .createBalanceInputViewModel(Decimal.fromSubstrateAmount(
                substrateAmout,
                precision: Int16(selectedAmountChainAsset.asset.precision)
            ))
            .value(for: selectedLocale)
            .displayAmount ?? inputAmount.description
        let data = CrossChainConfirmationData(
            wallet: wallet,
            originChainAsset: selectedAmountChainAsset,
            destChainModel: selectedDestChainModel,
            amount: substrateAmout,
            displayAmount: displayAmount,
            originChainFee: originChainFee,
            destChainFee: destChainFee,
            destChainFeeDecimal: destChainFeeDecimal,
            recipientAddress: recipientAddress,
            reviewedRoute: reviewedRoute
        )
        guard addressIsValid() else {
            return
        }
        router.showConfirmation(
            from: view,
            data: data
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
        // The origin chain's existential deposit is denominated in, and only binds, its utility asset. Subtracting it
        // from another asset's balance would mix units; that asset's fee is checked against the utility balance.
        var minimumBalance: Decimal = .zero
        if let utilityChainAsset = selectedAmountChainAsset.chain.utilityChainAssets().first,
           utilityChainAsset.chainAssetId == selectedAmountChainAsset.chainAssetId {
            minimumBalance = Decimal.fromSubstrateAmount(existentialDeposit ?? .zero, precision: Int16(utilityChainAsset.asset.precision)) ?? .zero
        }

        originNetworkSelectedAssetBalance = totalBalance - (destNetworkFee ?? .zero) - originNetworkFeeIfRequired() - (minimumBalance * 1.1)
        provideAssetViewModel()
        refreshPercentageAmount()
    }

    /// A percentage is a share of a balance and of fees that change after the tap; keep the field on what is signed.
    private func refreshPercentageAmount() {
        guard case .rate = amountInputResult else {
            return
        }
        provideInputViewModel()
    }

    private func processDestinationWallet() -> String? {
        guard
            let chain = selectedDestChainModel,
            let destWallet = destWallet,
            let accountId = destWallet.fetch(for: chain.accountRequest())?.accountId,
            let address = try? AddressFactory.address(for: accountId, chain: chain)
        else {
            return nil
        }
        return address
    }
}

// MARK: - CrossChainViewOutput

extension CrossChainPresenter: CrossChainViewOutput {
    func selectAmountPercentage(_ percentage: Float) {
        loadingCollector.originFeeReady = false
        amountInputResult = .rate(Decimal(Double(percentage)))
        provideAssetViewModel()
        provideInputViewModel()
        estimateFee()
    }

    func updateAmount(_ newValue: Decimal) {
        loadingCollector.originFeeReady = false
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
            // A fee without its precision cannot be scaled; reading it in the origin's precision could be off by a
            // factor of 10^n, so it counts as no fee.
            if let feeInPlanks = response.feeInPlanks,
               let destinationPrecision = response.precision.flatMap({ Int16($0) }) {
                destNetworkFee = Decimal.fromSubstrateAmount(feeInPlanks, precision: destinationPrecision)
            } else {
                destNetworkFee = nil
            }
        case let .failure(error):
            destNetworkFee = nil
            logger.customError(error)
        }
        provideDestNetworkFeeViewModel()
        deriveTransferableBalance()

        // Ready either way: a missing fee stops the transfer with an explanation when the user continues.
        loadingCollector.destinationFeeReady = true
        checkLoadingState()
    }

    func didReceiveOriginFee(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(fee):
            originNetworkFee = selectedAmountChainAsset.chain.utilityChainAssets().first.flatMap {
                Decimal.fromSubstrateAmount(fee, precision: Int16($0.asset.precision))
            }
        case let .failure(error):
            originNetworkFee = nil
            logger.customError(error)
        }
        provideOriginNetworkFeeViewModel()
        deriveTransferableBalance()

        loadingCollector.originFeeReady = true
        checkLoadingState()
    }

    func didReceiveAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId: AccountId,
        chainAsset: ChainAsset
    ) {
        let receiveUniqueKey = chainAsset.uniqueKey(accountId: accountId)
        let isSelectedAsset = receiveUniqueKey == selectedAmountChainAsset.uniqueKey(accountId: accountId)
        let isUtilityAsset = selectedAmountChainAsset.chain.utilityChainAssets().first.map {
            receiveUniqueKey == $0.uniqueKey(accountId: accountId)
        } ?? false

        switch result {
        case let .success(success):
            // The utility asset's account info arrives through the same callback; it must not overwrite the balance of
            // the asset being sent.
            if isSelectedAsset {
                originNetworkBalanceValue = success?.data.sendAvailable ?? .zero
                originBalanceAvailable = true
                deriveTransferableBalance()
            }
            if isUtilityAsset {
                originNetworkUtilityTokenBalance = success?.data.sendAvailable ?? .zero
            }
        case let .failure(failure):
            logger.customError(failure)
            if isSelectedAsset {
                originBalanceAvailable = false
            }
        }
        if isSelectedAsset {
            loadingCollector.balanceReady = true
            checkLoadingState()
        }
    }

    func didReceiveAvailableDestChainAssets(_ chainAssets: [ChainAsset]) {
        let filtredChainAssets = chainAssets
            .filter {
                $0.chain.chainId != selectedOriginChainModel.chainId &&
                    reviewedRoute.destinationChainIds.contains($0.chain.chainId)
            }
        availableDestChainModels = filtredChainAssets
            .map { $0.chain }
            .withoutDuplicates()

        // Every reviewed route has exactly one destination; there is nothing for the user to choose.
        if selectedDestChainModel == nil, availableDestChainModels.count == 1, let destination = availableDestChainModels.first {
            selectDestination(destination)
        }
    }

    func didSetup() {
        interactor.didReceive(originChainAsset: selectedAmountChainAsset)
    }

    func didReceiveOrigin(chainAssets: [ChainAsset]) {
        availableOriginChainAssets = chainAssets.filter {
            reviewedRoute.validates(origin: $0)
        }
    }

    func didReceiveExistentialDeposit(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(existentialDeposit):
            self.existentialDeposit = existentialDeposit
            deriveTransferableBalance()
        case let .failure(error):
            existentialDeposit = nil
            logger.customError(error)
        }
        loadingCollector.existentialDepositReady = true
        checkLoadingState()
    }

    func didReceiveDestinationExistentialDeposit(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(value):
            destExistentialDeposit = value
            destinationProblem = nil
        case let .failure(error):
            destExistentialDeposit = nil
            if case CrossChainFormError.destinationAssetUnavailable = error {
                destinationProblem = error
            }
            logger.customError(error)
        }
        loadingCollector.destinationExistentialDepositReady = true
        checkLoadingState()
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
        guard reviewedRoute.validates(origin: chainAsset) else {
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
        selectDestination(chain)
    }

    private func selectDestination(_ chain: ChainModel) {
        guard reviewedRoute.destinationChainIds.contains(chain.chainId) else {
            return
        }
        runLoadingState()

        destNetworkFee = nil
        originNetworkFee = nil
        destExistentialDeposit = nil
        destinationProblem = nil
        destAccountInfo = nil
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
        guard let address = processDestinationWallet() else {
            let viewModel = viewModelFactory.buildRecipientViewModel(address: wallet.name, isValid: false)
            view?.didReceive(recipientViewModel: viewModel)
            return
        }

        let viewModel = viewModelFactory.buildRecipientViewModel(address: address, isValid: true)
        view?.didReceive(recipientViewModel: viewModel)
        recipientAddress = address
        loadingCollector.addressExists = true
        checkLoadingState()
        interactor.fetchDestinationAccountInfo(address: address)
    }
}
