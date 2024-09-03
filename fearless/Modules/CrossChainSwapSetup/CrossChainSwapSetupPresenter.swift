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
    func didReceiveViewModel(viewModel: CrossChainSwapViewModel)
}

protocol CrossChainSwapSetupInteractorInput: AnyObject {
    func setup(with output: CrossChainSwapSetupInteractorOutput)
    func getQuotes(chainAsset: ChainAsset, destinationChainAsset: ChainAsset, amount: String) async throws -> [CrossChainSwap]
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

    private var swapFromInputResult: AmountInputResult?
    private var swapFromBalance: Decimal?
    private var swapToInputResult: AmountInputResult?
    private var swapToBalance: Decimal?

    // MARK: - Constructors

    init(
        interactor: CrossChainSwapSetupInteractorInput,
        router: CrossChainSwapSetupRouterInput,
        localizationManager: LocalizationManagerProtocol,
        viewModelFactory: CrossChainSwapSetupViewModelFactory,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.wallet = wallet
        swapFromChainAsset = chainAsset

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
            guard let fromAmountDecimal = swapFromInputResult?.absoluteValue(from: swapFromBalance ?? .zero) else {
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

                self.swap = quotes.first
                provideViewModel()
                provideDestinationInput()
            } catch {
                print("quotes error: ", error)
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
        var balance: Decimal? = swapFromBalance

        let inputAmount = swapFromInputResult?
            .absoluteValue(from: balance ?? .zero)

        let swapFromPrice = prices?.first(where: { priceData in
            swapFromChainAsset?.asset.priceId == priceData.priceId
        })

        let balanceViewModelFactory = buildBalanceViewModelFactory(
            wallet: wallet,
            for: swapFromChainAsset
        )

        let assetBalanceViewModel = balanceViewModelFactory?.createAssetBalanceViewModel(
            inputAmount,
            balance: swapFromBalance,
            priceData: swapFromPrice
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

        let swapToPrice = prices?.first(where: { priceData in
            swapToChainAsset?.asset.priceId == priceData.priceId
        })

        let balanceViewModelFactory = buildBalanceViewModelFactory(
            wallet: wallet,
            for: swapToChainAsset
        )

        let assetBalanceViewModel = balanceViewModelFactory?.createAssetBalanceViewModel(
            inputAmount,
            balance: swapToBalance,
            priceData: swapToPrice
        ).value(for: selectedLocale)
        let inputViewModel = balanceViewModelFactory?
            .createBalanceInputViewModel(inputAmount)
            .value(for: selectedLocale)

        DispatchQueue.main.async { [weak self] in
            self?.view?.didReceive(destinationAssetBalanceViewModel: assetBalanceViewModel)
            self?.view?.didReceiveSwapTo(amountInputViewModel: inputViewModel)
        }
    }

    private func provideOriginSelectNetworkViewModel() {
//        let viewModel = viewModelFactory.buildNetworkViewModel(chain: selectedOriginChainModel)
//        view?.didReceive(originSelectNetworkViewModel: viewModel)
    }

    private func provideDestSelectNetworkViewModel() {
//        guard let selectedDestChainModel = selectedDestChainModel else {
//            view?.didReceive(destSelectNetworkViewModel: nil)
//            return
//        }
//
//        let viewModel = viewModelFactory.buildNetworkViewModel(chain: selectedDestChainModel)
//        view?.didReceive(destSelectNetworkViewModel: viewModel)
    }

    private func provideOriginNetworkFeeViewModel() {
//        guard
//            let utilityOriginChainAsset = selectedAmountChainAsset.chain.utilityChainAssets().first,
//            let originNetworkFee = originNetworkFee,
//            let viewModelFactory = buildBalanceViewModelFactory(
//                wallet: wallet,
//                for: utilityOriginChainAsset
//            )
//        else {
//            view?.didReceive(originFeeViewModel: nil)
//            return
//        }
//
//        let priceData = prices.first(where: { $0.priceId == utilityOriginChainAsset.asset.priceId })
//        let viewModel = viewModelFactory.balanceFromPrice(
//            originNetworkFee,
//            priceData: priceData,
//            usageCase: .detailsCrypto
//        )
//
//        originNetworkFeeViewModel = viewModel.value(for: selectedLocale)
//        view?.didReceive(originFeeViewModel: viewModel)
//
//        loadingCollector.originFeeReady = true
//        checkLoadingState()
    }

    private func provideDestNetworkFeeViewModel() {
//        guard
//            let destNetworkFee = destNetworkFee,
//            let viewModelFactory = buildBalanceViewModelFactory(
//                wallet: wallet,
//                for: selectedAmountChainAsset
//            )
//        else {
//            view?.didReceive(destinationFeeViewModel: nil)
//            return
//        }
//
//        let priceData = prices.first(where: { $0.priceId == selectedAmountChainAsset.asset.priceId })
//        let viewModel = viewModelFactory.balanceFromPrice(
//            destNetworkFee,
//            priceData: priceData,
//            usageCase: .detailsCrypto
//        )
//
//        destNetworkFeeViewModel = viewModel.value(for: selectedLocale)
//        view?.didReceive(destinationFeeViewModel: viewModel)
//
//        loadingCollector.destinationFeeReady = true
//        checkLoadingState()
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
//        DispatchQueue.main.async {
//            self.provideAssetViewModel()
//            self.provideOriginNetworkFeeViewModel()
//            self.provideDestNetworkFeeViewModel()
//        }
    }

    private func handle(newAddress _: String) {
//        loadingCollector.addressExists = !newAddress.isEmpty
//        checkLoadingState()
//        interactor.fetchDestinationAccountInfo(address: newAddress)
//        recipientAddress = newAddress
//        let isValid = selectedDestChainModel.map { interactor.validate(address: recipientAddress, for: $0).isValidOrSame }.or(true)
//        if selectedDestChainModel != nil, !isValid, newAddress.isNotEmpty {
//            showInvalidAddressAlert()
//        }
//        let viewModel = viewModelFactory.buildRecipientViewModel(address: newAddress, isValid: isValid)
//        view?.didReceive(recipientViewModel: viewModel)
    }

    private func provideAddress() {
//        if let destWallet = destWallet {
//            selectedWallet(destWallet, for: 0)
//        } else {
//            guard let chain = selectedDestChainModel else {
//                return
//            }
//            let isValid = interactor.validate(address: recipientAddress, for: chain).isValidOrSame
//            if isValid, let recipientAddress = recipientAddress {
//                handle(newAddress: recipientAddress)
//            } else if recipientAddress?.isNotEmpty == true {
//                handle(newAddress: "")
//            }
//        }
    }

    private func calculateAbsoluteValue() -> Decimal? {
//        amountInputResult?
//            .absoluteValue(from: originNetworkSelectedAssetBalance - (destNetworkFee ?? .zero) - originNetworkFeeIfRequired())
        nil
    }

    private func continueWithValidation() {
//        guard let utilityChainAsset = selectedAmountChainAsset.chain.utilityChainAssets().first else {
//            return
//        }
//        let utilityBalance = Decimal.fromSubstrateAmount(originNetworkUtilityTokenBalance, precision: Int16(utilityChainAsset.asset.precision))
//        let minimumBalance = Decimal.fromSubstrateAmount(existentialDeposit ?? .zero, precision: Int16(utilityChainAsset.asset.precision)) ?? .zero
//        let inputAmountDecimal = amountInputResult?
//            .absoluteValue(from: originNetworkSelectedAssetBalance - (destNetworkFee ?? .zero) - originNetworkFeeIfRequired()) ?? .zero
//        let destChainAsset = selectedDestChainModel.map {
//            ChainAsset(chain: $0, asset: selectedAmountChainAsset.asset)
//        }
//
//        let destBalanceDecimal: Decimal? = (destAccountInfo?.data.sendAvailable).flatMap {
//            guard let destChainAsset else {
//                return nil
//            }
//
//            return Decimal.fromSubstrateAmount($0, precision: Int16(destChainAsset.asset.precision))
//        }
//
//        let originFeeValidating = dataValidatingFactory.has(
//            fee: originNetworkFee,
//            locale: selectedLocale
//        ) { [weak self] in
//            self?.estimateFee()
//        }
//
//        let destFeeValidating = dataValidatingFactory.has(
//            fee: destNetworkFee,
//            locale: selectedLocale,
//            onError: { [weak self] in
//                self?.estimateFee()
//            }
//        )
//
//        let sendAmount = inputAmountDecimal
//        let balanceType: BalanceType
//
//        if selectedAmountChainAsset.chainAssetId == utilityChainAsset.chainAssetId {
//            balanceType = .utility(balance: utilityBalance)
//        } else {
//            balanceType = .orml(balance: originNetworkSelectedAssetBalance, utilityBalance: utilityBalance)
//        }
//
//        let canPayOriginalFeeAndAmount = dataValidatingFactory.canPayFeeAndAmount(
//            balanceType: balanceType,
//            feeAndTip: originNetworkFee,
//            sendAmount: sendAmount,
//            locale: selectedLocale
//        )
//
//        let spending: Decimal
//        if selectedAmountChainAsset.isUtility {
//            spending = originNetworkFee.or(.zero) + inputAmountDecimal
//        } else {
//            spending = originNetworkFee.or(.zero)
//        }
//
//        let exsitentialDepositIsNotViolated = dataValidatingFactory.exsitentialDepositIsNotViolated(
//            spending: spending,
//            balance: utilityBalance.or(.zero),
//            minimumBalance: minimumBalance,
//            chainAsset: selectedAmountChainAsset,
//            locale: selectedLocale,
//            canProceedIfViolated: false,
//            proceedAction: {},
//            setMaxAction: {},
//            cancelAction: {}
//        )
//
//        let soraBridgeViolated = dataValidatingFactory.soraBridgeViolated(
//            originCHain: selectedOriginChainModel,
//            destChain: selectedDestChainModel,
//            amount: inputAmountDecimal,
//            locale: selectedLocale,
//            asset: selectedAmountChainAsset.asset
//        )
//
//        let soraBridgeAmountLessFeeViolated = dataValidatingFactory.soraBridgeAmountLessFeeViolated(
//            originCHainId: selectedOriginChainModel.chainId,
//            destChainId: selectedDestChainModel?.chainId,
//            amount: inputAmountDecimal,
//            fee: destNetworkFee,
//            locale: selectedLocale
//        )
//
//        let validators: [DataValidating] = [
//            originFeeValidating,
//            canPayOriginalFeeAndAmount,
//            exsitentialDepositIsNotViolated,
//            destFeeValidating,
//            soraBridgeViolated,
//            soraBridgeAmountLessFeeViolated
//        ]
//        DataValidationRunner(validators: validators)
//            .runValidation { [weak self] in
//                self?.prepareAndShowConfirmation()
//            }
    }

    private func prepareAndShowConfirmation() {
//        guard let selectedDestChainModel = selectedDestChainModel,
//              let inputViewModel = inputViewModel,
//              let originChainFee = originNetworkFeeViewModel,
//              let destChainFee = destNetworkFeeViewModel,
//              let inputAmount = calculateAbsoluteValue(),
//              let substrateAmout = inputAmount.toSubstrateAmount(precision: Int16(selectedAmountChainAsset.asset.precision)),
//              let xcmServices = interactor.deps?.xcmServices,
//              let recipientAddress = recipientAddress,
//              let destChainFeeDecimal = destNetworkFee
//        else {
//            return
//        }
//        let data = CrossChainConfirmationData(
//            wallet: wallet,
//            originChainAsset: selectedAmountChainAsset,
//            destChainModel: selectedDestChainModel,
//            amount: substrateAmout,
//            displayAmount: inputViewModel.displayAmount,
//            originChainFee: originChainFee,
//            destChainFee: destChainFee,
//            destChainFeeDecimal: destChainFeeDecimal,
//            recipientAddress: recipientAddress
//        )
//        guard addressIsValid() else {
//            return
//        }
//        router.showConfirmation(
//            from: view,
//            data: data,
//            xcmServices: xcmServices
//        )
    }

    private func estimateFee() {
//        guard let selectedDestChainModel = selectedDestChainModel else {
//            return
//        }
//        let inputAmount = calculateAbsoluteValue().or(1)
//        view?.setButtonLoadingState(isLoading: true)
//        interactor.estimateFee(
//            originChainAsset: selectedAmountChainAsset,
//            destinationChainModel: selectedDestChainModel,
//            amount: inputAmount
//        )
    }

    private func addressIsValid() -> Bool {
//        guard let selectedDestChainModel = selectedDestChainModel else {
//            return false
//        }
//        let validAddressResult = interactor.validate(address: recipientAddress, for: selectedDestChainModel)
//
//        switch validAddressResult {
//        case .valid, .sameAddress:
//            return true
//        case .invalid:
//            showInvalidAddressAlert()
//            return false
//        }
        true
    }

    private func showInvalidAddressAlert() {
//        let message = R.string.localizable
//            .xcmCrossChainInvalidAddressMessage(preferredLanguages: selectedLocale.rLanguages)
//        let title = R.string.localizable
//            .xcmCrossChainInvalidAddressTitle(preferredLanguages: selectedLocale.rLanguages)
//        router.present(
//            message: message,
//            title: title,
//            closeAction: R.string.localizable.commonOk(preferredLanguages: selectedLocale.rLanguages),
//            from: view,
//            actions: []
//        )
    }

    private func originNetworkFeeIfRequired() -> Decimal {
//        if let utilityChainAsset = selectedAmountChainAsset.chain.utilityChainAssets().first,
//           selectedAmountChainAsset.chainAssetId == utilityChainAsset.chainAssetId,
//           let fee = originNetworkFee {
//            return fee
//        }
        .zero
    }

    private func deriveTransferableBalance() {
//        let totalBalance = Decimal.fromSubstrateAmount(
//            originNetworkBalanceValue,
//            precision: Int16(selectedAmountChainAsset.asset.precision)
//        ) ?? .zero
//        var minimumBalance: Decimal = .zero
//        if let utilityChainAsset = selectedAmountChainAsset.chain.utilityChainAssets().first {
//            minimumBalance = Decimal.fromSubstrateAmount(existentialDeposit ?? .zero, precision: Int16(utilityChainAsset.asset.precision)) ?? .zero
//        }
//
//        originNetworkSelectedAssetBalance = totalBalance - (destNetworkFee ?? .zero) - originNetworkFeeIfRequired() - (minimumBalance * 1.1)
//        provideAssetViewModel()
    }

    private func processDestinationWallet() -> String? {
//        guard
//            let chain = selectedDestChainModel,
//            let destWallet = destWallet,
//            let accountId = destWallet.fetch(for: chain.accountRequest())?.accountId,
//            let address = try? AddressFactory.address(for: accountId, chain: chain)
//        else {
//            return nil
//        }
//        return address\
        nil
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

    func selectToAmountPercentage(_ percentage: Float) {
        runLoadingState()

        swapVariant = .desiredOutput
        swapToInputResult = .rate(Decimal(Double(percentage)))
        provideDestinationAssetViewModel()
        fetchQuotes()
    }

    func updateToAmount(_ newValue: Decimal) {
        runLoadingState()

        swapVariant = .desiredOutput
        swapToInputResult = .absolute(newValue)
        provideDestinationAssetViewModel()
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

    func didTapSelectDestNetwoek() {
//        router.showSelectNetwork(
//            from: view,
//            wallet: wallet,
//            selectedChainId: selectedDestChainModel?.chainId,
//            chainModels: availableDestChainModels,
//            contextTag: nil,
//            delegate: self
//        )
    }

    func didLoad(view: CrossChainSwapSetupViewInput) {
        self.view = view
//        interactor.setup(with: self)
        provideOriginSelectNetworkViewModel()
//        provideDestSelectNetworkViewModel()
//        provideInputViewModel()
        provideAssetViewModel()
    }

    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapContinueButton() {
//        continueWithValidation()
    }

    func didTapScanButton() {
//        router.presentScan(from: view, moduleOutput: self)
    }

    func didTapHistoryButton() {
//        router.presentHistory(
//            from: view,
//            wallet: wallet,
//            chainAsset: selectedAmountChainAsset,
//            moduleOutput: self
//        )
    }

    func didTapMyWalletsButton() {
//        router.showWalletManagment(
//            selectedWalletId: destWallet?.metaId,
//            from: view,
//            moduleOutput: self
//        )
    }

    func didTapPasteButton() {
//        if let address = UIPasteboard.general.string {
//            handle(newAddress: address)
//        }
    }

    func searchTextDidChanged(_: String) {
//        destWallet = nil
//        handle(newAddress: text)
    }
}

// MARK: - CrossChainSwapSetupInteractorOutput

extension CrossChainSwapSetupPresenter: CrossChainSwapSetupInteractorOutput {}

// MARK: - Localizable

extension CrossChainSwapSetupPresenter: Localizable {
    func applyLocalization() {}
}

extension CrossChainSwapSetupPresenter: CrossChainSwapSetupModuleInput {}

extension CrossChainSwapSetupPresenter: SelectAssetModuleOutput {
    func assetSelection(didCompleteWith chainAsset: ChainAsset?, contextTag _: Int?) {
        swapToChainAsset = chainAsset
        provideDestinationAssetViewModel()

        fetchQuotes()
    }
}
