import Foundation
import SoraFoundation
import BigInt
import SSFUtils
import SSFModels

let bokoloCasheBridgeAddress = "cnSftmQkwkLoX2JEVDZ6xKScLDDiCHZoEZvgnUCrwZgrzEEpy"
let bokoloCashAssetCurrencyId = "0x00eacaea6599a04358fda986388ef0bb0c17a553ec819d5de2900c0af0862502"

final class SendPresenter {
    enum State {
        case initialSelection
        case normal
    }

    // MARK: Private properties

    private weak var view: SendViewInput?
    private let router: SendRouterInput
    private let interactor: SendInteractorInput
    private let dataValidatingFactory: SendDataValidatingFactory
    private let logger: LoggerProtocol?
    private let wallet: MetaAccountModel
    private let qrParser: QRParser
    private let viewModelFactory: SendViewModelFactoryProtocol
    private let initialData: SendFlowInitialData

    private weak var moduleOutput: SendModuleOutput?

    private var remark: Data?
    private var recipientAddress: String?
    private var selectedChain: ChainModel?
    private var selectedChainAsset: ChainAsset?
    private var selectedAsset: AssetModel?
    private var balance: Decimal?
    private var utilityBalance: Decimal?
    private var prices: [PriceData] = []
    private var tip: Decimal?
    private var fee: Decimal?
    private var minimumBalance: BigUInt?
    private var inputResult: AmountInputResult?
    private var scamInfo: ScamInfo?
    private var state: State = .normal
    private var eqUilibriumTotalBalance: Decimal?
    private var balanceMinusFeeAndTip: Decimal {
        let feePaymentChainAsset = interactor.getFeePaymentChainAsset(for: selectedChainAsset)
        if feePaymentChainAsset?.identifier != selectedChainAsset?.identifier {
            return (balance ?? 0)
        }
        return (balance ?? 0) - (fee ?? 0) - (tip ?? 0)
    }

    private var fullAmount: Decimal {
        let feePaymentChainAsset = interactor.getFeePaymentChainAsset(for: selectedChainAsset)
        if feePaymentChainAsset?.identifier != selectedChainAsset?.identifier {
            return (balance ?? 0)
        }
        return (balance ?? 0) + (fee ?? 0) + (tip ?? 0)
    }

    // MARK: - Constructors

    init(
        interactor: SendInteractorInput,
        router: SendRouterInput,
        localizationManager: LocalizationManagerProtocol,
        viewModelFactory: SendViewModelFactoryProtocol,
        dataValidatingFactory: SendDataValidatingFactory,
        qrParser: QRParser,
        logger: LoggerProtocol? = nil,
        wallet: MetaAccountModel,
        initialData: SendFlowInitialData
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.qrParser = qrParser
        self.logger = logger
        self.wallet = wallet
        self.initialData = initialData

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - SendViewOutput

extension SendPresenter: SendViewOutput {
    func didLoad(view: SendViewInput) {
        self.view = view
        interactor.setup(with: self)

        switch initialData {
        case let .chainAsset(chainAsset):
            selectedChainAsset = chainAsset
            interactor.updateSubscriptions(for: chainAsset)
            provideNetworkViewModel(for: chainAsset.chain, canEdit: true)
            provideInputViewModel()
        case let .address(address):
            recipientAddress = address
            Task {
                let possibleChains = await interactor.getPossibleChains(for: address)
                await MainActor.run {
                    guard possibleChains?.isNotEmpty == true else {
                        showIncorrectAddressAlert()
                        return
                    }
                    let viewModel = viewModelFactory.buildRecipientViewModel(
                        address: address,
                        isValid: true,
                        canEditing: true
                    )
                    view.didReceive(viewModel: viewModel)
                    didReceive(possibleChains: possibleChains)
                }
            }
        case let .soraMainnetSolomon(address):
            handleSolomon(address)
        case let .soraMainnet(qrInfo):
            handleSora(qrInfo: qrInfo)
        case let .bokoloCash(bokoloCashQRInfo):
            handleBokoloCash(qrInfo: bokoloCashQRInfo)
        }
    }

    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))
        provideAssetVewModel()
        provideInputViewModel()
        guard let chainAsset = selectedChainAsset else { return }
        refreshFee(for: chainAsset, address: recipientAddress)
    }

    func updateAmount(_ newValue: Decimal) {
        inputResult = .absolute(newValue)
        provideAssetVewModel()
        guard let chainAsset = selectedChainAsset else { return }
        refreshFee(for: chainAsset, address: recipientAddress)
    }

    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func validateAddress(with chainAsset: ChainAsset, successCompletion: @escaping (String) -> Void) {
        switch interactor.validate(address: recipientAddress, for: chainAsset.chain) {
        case let .valid(address):
            successCompletion(address)
        case let .invalid(address):
            guard let address = address else {
                showInvalidAddressAlert()
                return
            }
            Task {
                let possibleChains = await interactor.getPossibleChains(for: address)
                await MainActor.run {
                    guard let possibleChains = possibleChains, possibleChains.isNotEmpty else {
                        showInvalidAddressAlert()
                        return
                    }

                    showPossibleChainsAlert(possibleChains)
                }
            }
        case let .sameAddress(address):
            showSameAddressAlert(address, successCompletion: successCompletion)
        }
    }

    func validateInputData(with address: String, chainAsset: ChainAsset) {
        let sendAmountDecimal = inputResult?.absoluteValue(from: balanceMinusFeeAndTip)
        let spendingValue = (sendAmountDecimal ?? 0) + (fee ?? 0) + (tip ?? 0)

        let balanceType: BalanceType = (!chainAsset.isUtility && chainAsset.chain.isUtilityFeePayment) ?
            .orml(balance: balance, utilityBalance: utilityBalance) : .utility(balance: balance)
        var minimumBalanceDecimal: Decimal?
        if let minBalance = minimumBalance {
            minimumBalanceDecimal = Decimal.fromSubstrateAmount(
                minBalance,
                precision: Int16(chainAsset.asset.precision)
            )
        }

        let shouldPayInAnotherUtilityToken = !chainAsset.isUtility && chainAsset.chain.isUtilityFeePayment
        var edParameters: ExistentialDepositValidationParameters = shouldPayInAnotherUtilityToken ?
            .orml(
                minimumBalance: minimumBalanceDecimal,
                feeAndTip: (fee ?? 0) + (tip ?? 0),
                utilityBalance: utilityBalance
            ) :
            .utility(
                spendingAmount: spendingValue,
                totalAmount: balance,
                minimumBalance: minimumBalanceDecimal
            )
        if chainAsset.chain.isEquilibrium {
            edParameters = .equilibrium(
                minimumBalance: minimumBalanceDecimal,
                totalBalance: eqUilibriumTotalBalance
            )
        }

        DataValidationRunner(validators: [
            dataValidatingFactory.has(fee: fee, locale: selectedLocale, onError: { [weak self] in
                self?.refreshFee(for: chainAsset, address: address)
            }),
            dataValidatingFactory.canPayFeeAndAmount(
                balanceType: balanceType,
                feeAndTip: (fee ?? 0) + (tip ?? 0),
                sendAmount: sendAmountDecimal,
                locale: selectedLocale
            ),
            dataValidatingFactory.exsitentialDepositIsNotViolated(
                parameters: edParameters,
                locale: selectedLocale,
                chainAsset: chainAsset
            )

        ]).runValidation { [weak self] in
            guard let strongSelf = self, let amount = sendAmountDecimal else { return }
            strongSelf.router.presentConfirm(
                from: strongSelf.view,
                wallet: strongSelf.wallet,
                chainAsset: chainAsset,
                receiverAddress: address,
                amount: amount,
                tip: strongSelf.tip,
                scamInfo: strongSelf.scamInfo,
                remark: strongSelf.remark
            )
        }
    }

    func didTapContinueButton() {
        guard let chainAsset = selectedChainAsset else { return }
        validateAddress(with: chainAsset) { [weak self] address in
            self?.validateInputData(with: address, chainAsset: chainAsset)
        }
    }

    func didTapPasteButton() {
        if let address = UIPasteboard.general.string {
            handle(newAddress: address)
        }
    }

    func didTapScanButton() {
        router.presentScan(from: view, moduleOutput: self)
    }

    func didTapHistoryButton() {
        guard let chainAsset = selectedChainAsset else { return }
        router.presentHistory(from: view, wallet: wallet, chainAsset: chainAsset, moduleOutput: self)
    }

    func didTapSelectAsset() {
        router.showSelectAsset(
            from: view,
            wallet: wallet,
            selectedAssetId: selectedChainAsset?.asset.identifier,
            chainAssets: nil,
            output: self
        )
    }

    func didTapSelectNetwork() {
        guard let chainAsset = selectedChainAsset else { return }
        interactor.defineAvailableChains(for: chainAsset.asset) { [weak self] chains in
            guard let strongSelf = self, let availableChains = chains else { return }
            strongSelf.router.showSelectNetwork(
                from: strongSelf.view,
                wallet: strongSelf.wallet,
                selectedChainId: strongSelf.selectedChainAsset?.chain.chainId,
                chainModels: availableChains,
                delegate: strongSelf
            )
        }
    }

    func searchTextDidChanged(_ text: String) {
        handle(newAddress: text)
    }
}

// MARK: - SendInteractorOutput

extension SendPresenter: SendInteractorOutput {
    func didReceive(scamInfo: ScamInfo?) {
        self.scamInfo = scamInfo
        view?.didReceive(scamInfo: scamInfo)
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset) {
        switch result {
        case let .success(accountInfo):
            if chainAsset == selectedChainAsset {
                balance = accountInfo.map {
                    Decimal.fromSubstrateAmount(
                        $0.data.sendAvailable,
                        precision: Int16(chainAsset.asset.precision)
                    )
                } ?? 0.0

                provideAssetVewModel()
            } else if let utilityAsset = interactor.getFeePaymentChainAsset(for: chainAsset),
                      utilityAsset == chainAsset {
                utilityBalance = accountInfo.map {
                    Decimal.fromSubstrateAmount(
                        $0.data.sendAvailable,
                        precision: Int16(utilityAsset.asset.precision)
                    )
                } ?? 0
            }
        case let .failure(error):
            logger?.error("Did receive account info error: \(error)")
        }
    }

    func didReceiveMinimumBalance(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(minimumBalance):
            self.minimumBalance = minimumBalance
            logger?.info("Did receive minimum balance \(minimumBalance)")
        case let .failure(error):
            logger?.error("Did receive minimum balance error: \(error)")
        }
    }

    func didReceivePriceData(result: Result<PriceData?, Error>, for _: AssetModel.PriceId?) {
        switch result {
        case let .success(priceData):
            if let priceData = priceData {
                prices.append(priceData)
            }
            provideAssetVewModel()
            provideFeeViewModel()
            provideTipViewModel()
        case let .failure(error):
            logger?.error("Did receive price error: \(error)")
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        view?.didStopFeeCalculation()
        switch result {
        case let .success(dispatchInfo):
            guard let chainAsset = selectedChainAsset,
                  let utilityAsset = interactor.getFeePaymentChainAsset(for: chainAsset) else { return }
            fee = BigUInt(string: dispatchInfo.fee).map {
                Decimal.fromSubstrateAmount($0, precision: Int16(utilityAsset.asset.precision))
            } ?? nil

            provideAssetVewModel()
            provideFeeViewModel()

            switch inputResult {
            case .rate:
                provideInputViewModel()
            default:
                break
            }
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }

    func didReceiveTip(result: Result<BigUInt, Error>) {
        view?.didStopTipCalculation()
        switch result {
        case let .success(tip):
            guard let chainAsset = selectedChainAsset, let address = recipientAddress else { return }
            self.tip = Decimal.fromSubstrateAmount(tip, precision: Int16(chainAsset.asset.precision))

            provideTipViewModel()
            refreshFee(for: chainAsset, address: address)
        case let .failure(error):
            logger?.error("Did receive tip error: \(error)")
            // Even though no tip received, let's refresh fee, because we didn't load it at start
            guard let chainAsset = selectedChainAsset, let address = recipientAddress else { return }
            refreshFee(for: chainAsset, address: address)
        }
    }

    func didReceive(possibleChains: [ChainModel]?) {
        guard let chains = possibleChains else {
            router.showSelectAsset(
                from: view,
                wallet: wallet,
                selectedAssetId: nil,
                chainAssets: nil,
                output: self
            )
            return
        }
        if chains.count == 1, let selectedChain = chains.first {
            defineOrSelectAsset(for: selectedChain)
        } else {
            state = .initialSelection
            router.showSelectNetwork(
                from: view,
                wallet: wallet,
                selectedChainId: nil,
                chainModels: possibleChains,
                delegate: self
            )
        }
    }

    func didReceive(eqTotalBalance: Decimal) {
        eqUilibriumTotalBalance = eqTotalBalance
    }

    func didReceiveDependencies(for chainAsset: ChainAsset) {
        refreshFee(for: chainAsset, address: recipientAddress)
    }
}

extension SendPresenter: ScanQRModuleOutput {
    func didFinishWith(scanType: QRMatcherType) {
        guard let qrInfo = scanType.qrInfo else {
            return
        }

        switch qrInfo {
        case let .bokoloCash(qrInfo):
            handleBokoloCash(qrInfo: qrInfo)
        case let .solomon(qrInfo):
            handleSolomon(qrInfo.address)
        case let .sora(qrInfo):
            handleSora(qrInfo: qrInfo)
        case let .cex(qrInfo):
            searchTextDidChanged(qrInfo.address)
        }
    }

    func didFinishWithSolomon(soraAddress: String) {
        handleSolomon(soraAddress)
    }

    func didFinishWith(address: String) {
        searchTextDidChanged(address)
    }
}

extension SendPresenter: ContactsModuleOutput {
    func didSelect(address: String) {
        searchTextDidChanged(address)
    }
}

extension SendPresenter: SendModuleInput {}

extension SendPresenter: SelectAssetModuleOutput {
    func assetSelection(didCompleteWith chainAsset: ChainAsset?, contextTag _: Int?) {
        selectedAsset = chainAsset?.asset
        if let asset = chainAsset?.asset {
            if let chain = selectedChain {
                state = .normal
                selectedChainAsset = chain.chainAssets.first(where: { $0.asset.symbol == asset.symbol })
                if let selectedChainAsset = selectedChainAsset {
                    handle(selectedChainAsset: selectedChainAsset)
                }
            } else {
                state = .normal
                interactor.defineAvailableChains(for: asset) { [weak self] chains in
                    if let availableChains = chains, let strongSelf = self {
                        if availableChains.count == 1 {
                            self?.handle(selectedChain: availableChains.first)
                        } else {
                            strongSelf.router.showSelectNetwork(
                                from: strongSelf.view,
                                wallet: strongSelf.wallet,
                                selectedChainId: strongSelf.selectedChainAsset?.chain.chainId,
                                chainModels: availableChains,
                                delegate: strongSelf
                            )
                        }
                    }
                }
            }
        } else if selectedChainAsset == nil {
            router.dismiss(view: view)
        }
    }
}

extension SendPresenter: SelectNetworkDelegate {
    func chainSelection(
        view _: SelectNetworkViewInput,
        didCompleteWith chain: ChainModel?,
        contextTag _: Int?
    ) {
        handle(selectedChain: chain)
    }
}

private extension SendPresenter {
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

    func provideAssetVewModel() {
        guard let chainAsset = selectedChainAsset else { return }
        let priceData = prices.first(where: { $0.priceId == chainAsset.asset.priceId })

        let balanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: chainAsset)

        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFeeAndTip) ?? 0.0

        let viewModel = balanceViewModelFactory?.createAssetBalanceViewModel(
            inputAmount,
            balance: balance,
            priceData: priceData
        ).value(for: selectedLocale)

        DispatchQueue.main.async {
            self.view?.didReceive(assetBalanceViewModel: viewModel)
        }

        let fullAmount = inputResult?.absoluteValue(from: fullAmount) ?? .zero
        interactor.calculateEquilibriumBalance(chainAsset: chainAsset, amount: fullAmount)
    }

    func provideTipViewModel() {
        guard let chainAsset = selectedChainAsset,
              let utilityAsset = interactor.getFeePaymentChainAsset(for: selectedChainAsset),
              let balanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: utilityAsset)
        else { return }

        let priceData = prices.first(where: { $0.priceId == chainAsset.asset.priceId })
        let viewModel = tip
            .map { balanceViewModelFactory
                .balanceFromPrice(
                    $0,
                    priceData: priceData,
                    usageCase: .detailsCrypto
                )
            }?.value(for: selectedLocale)
        let tipViewModel = TipViewModel(
            balanceViewModel: viewModel,
            tipRequired: utilityAsset.chain.isTipRequired
        )
        DispatchQueue.main.async {
            self.view?.didReceive(tipViewModel: tipViewModel)
        }
    }

    func provideFeeViewModel() {
        guard
            let utilityAsset = interactor.getFeePaymentChainAsset(for: selectedChainAsset),
            let balanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: utilityAsset)
        else { return }

        let priceData = prices.first(where: { $0.priceId == utilityAsset.asset.priceId })
        let viewModel = fee
            .map { balanceViewModelFactory.balanceFromPrice($0, priceData: priceData, usageCase: .detailsCrypto) }?
            .value(for: selectedLocale)

        DispatchQueue.main.async {
            self.view?.didReceive(feeViewModel: viewModel)
        }
    }

    func provideInputViewModel() {
        guard let chainAsset = selectedChainAsset
        else { return }

        let balanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: chainAsset)

        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFeeAndTip)

        let inputViewModel = balanceViewModelFactory?.createBalanceInputViewModel(inputAmount)
            .value(for: selectedLocale)

        DispatchQueue.main.async {
            self.view?.didReceive(amountInputViewModel: inputViewModel)
        }
    }

    func provideNetworkViewModel(for chain: ChainModel, canEdit: Bool) {
        let viewModel = viewModelFactory.buildNetworkViewModel(chain: chain, canEdit: canEdit)
        DispatchQueue.main.async {
            self.view?.didReceive(selectNetworkViewModel: viewModel)
        }
    }

    func refreshFee(for chainAsset: ChainAsset, address: String?) {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFeeAndTip) ?? 0
        guard let amount = inputAmount.toSubstrateAmount(
            precision: Int16(chainAsset.asset.precision)
        ) else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.view?.didStartFeeCalculation()
        }

        let tip = self.tip?.toSubstrateAmount(precision: Int16(chainAsset.asset.precision))
        interactor.estimateFee(for: amount, tip: tip, for: address, chainAsset: chainAsset)
    }

    func handle(newAddress: String) {
        guard newAddress.isNotEmpty else {
            return
        }
        recipientAddress = newAddress
        guard let chainAsset = selectedChainAsset else { return }
        let viewModel = viewModelFactory.buildRecipientViewModel(
            address: newAddress,
            isValid: interactor.validate(address: newAddress, for: chainAsset.chain).isValid,
            canEditing: true
        )

        DispatchQueue.main.async {
            self.view?.didReceive(viewModel: viewModel)
        }

        interactor.updateSubscriptions(for: chainAsset)
        interactor.fetchScamInfo(for: newAddress)
    }

    func handle(selectedChain: ChainModel?) {
        self.selectedChain = selectedChain
        switch state {
        case .initialSelection:
            if let chain = selectedChain {
                defineOrSelectAsset(for: chain)
            }
            state = .normal
        case .normal:
            let optionalAsset: AssetModel? = selectedAsset ?? selectedChainAsset?.asset
            if
                let selectedChain = selectedChain,
                let selectedAsset = optionalAsset,
                let selectedChainAsset = selectedChain.chainAssets.first(where: {
                    $0.asset.symbol.lowercased() == selectedAsset.symbol.lowercased()
                }) {
                self.selectedChainAsset = selectedChainAsset
                handle(selectedChainAsset: selectedChainAsset)
            }
        }
        if selectedChainAsset == nil {
            router.dismiss(view: view)
        }
    }

    func handle(selectedChainAsset: ChainAsset) {
        fee = nil
        provideNetworkViewModel(for: selectedChainAsset.chain, canEdit: true)
        provideAssetVewModel()
        provideInputViewModel()
        if let recipientAddress = recipientAddress {
            handle(newAddress: recipientAddress)
        } else {
            interactor.updateSubscriptions(for: selectedChainAsset)
        }
    }

    func defineOrSelectAsset(for chain: ChainModel) {
        if chain.chainAssets.count == 1,
           let selectedChainAsset = chain.chainAssets.first {
            self.selectedChainAsset = selectedChainAsset
            handle(selectedChainAsset: selectedChainAsset)
        } else {
            router.showSelectAsset(
                from: view,
                wallet: wallet,
                selectedAssetId: nil,
                chainAssets: chain.chainAssets,
                output: self
            )
        }
    }

    private func showInvalidAddressAlert() {
        router.present(
            message: R.string.localizable.errorInvalidAddress(preferredLanguages: selectedLocale.rLanguages),
            title: R.string.localizable.commonWarning(preferredLanguages: selectedLocale.rLanguages),
            closeAction: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages),
            from: view
        )
    }

    private func showPossibleChainsAlert(_ possibleChains: [ChainModel]) {
        let action = SheetAlertPresentableAction(
            title: R.string.localizable.commonSelectNetwork(preferredLanguages: selectedLocale.rLanguages)
        ) { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.router.showSelectNetwork(
                from: strongSelf.view,
                wallet: strongSelf.wallet,
                selectedChainId: nil,
                chainModels: possibleChains,
                delegate: strongSelf
            )
        }
        router.present(
            message: R.string.localizable.errorInvalidAddress(preferredLanguages: selectedLocale.rLanguages),
            title: R.string.localizable.commonWarning(preferredLanguages: selectedLocale.rLanguages),
            closeAction: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages),
            from: view,
            actions: [action]
        )
    }

    private func showSameAddressAlert(_ address: String, successCompletion: @escaping (String) -> Void) {
        let action = SheetAlertPresentableAction(
            title: R.string.localizable.commonProceed(preferredLanguages: selectedLocale.rLanguages)
        ) {
            successCompletion(address)
        }
        router.present(
            message: R.string.localizable
                .sameAddressTransferWarningMessage(preferredLanguages: selectedLocale.rLanguages),
            title: R.string.localizable.commonWarning(preferredLanguages: selectedLocale.rLanguages),
            closeAction: R.string.localizable.commonCancel(preferredLanguages: selectedLocale.rLanguages),
            from: view,
            actions: [action]
        )
    }

    private func showIncorrectAddressAlert() {
        let dissmissAction = SheetAlertPresentableAction(
            title: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages)
        ) { [weak self] in
            self?.router.dismiss(view: self?.view)
        }
        let alertViewModel = SheetAlertPresentableViewModel(
            title: R.string.localizable.commonWarning(preferredLanguages: selectedLocale.rLanguages),
            message: R.string.localizable.errorInvalidAddress(preferredLanguages: selectedLocale.rLanguages),
            actions: [dissmissAction],
            closeAction: nil,
            dismissCompletion: { [weak self] in
                self?.router.dismiss(view: self?.view)
            }
        )
        router.present(viewModel: alertViewModel, from: view)
    }

    private func showUnsupportedAssetAlert() {
        let dissmissAction = SheetAlertPresentableAction(
            title: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages)
        ) { [weak self] in
            self?.router.dismiss(view: self?.view)
        }
        let alertViewModel = SheetAlertPresentableViewModel(
            title: R.string.localizable.commonWarning(preferredLanguages: selectedLocale.rLanguages),
            message: R.string.localizable.errorUnsupportedAsset(preferredLanguages: selectedLocale.rLanguages),
            actions: [dissmissAction],
            closeAction: nil,
            dismissCompletion: { [weak self] in
                self?.router.dismiss(view: self?.view)
            }
        )
        router.present(viewModel: alertViewModel, from: view)
    }

    func handleSolomon(_ address: String) {
        recipientAddress = address
        Task {
            let possibleChains = await interactor.getPossibleChains(for: address)
            await MainActor.run(body: {
                #if F_DEV
                    let soraMainChainAsset = possibleChains?
                        .first(where: { $0.isSora && $0.isTestnet })?.chainAssets
                        .first(where: { $0.asset.symbol.lowercased() == "xstusd" })

                #else
                    let soraMainChainAsset = possibleChains?
                        .first(where: { $0.isSora })?.chainAssets
                        .first(where: { $0.asset.symbol.lowercased() == "xstusd" })
                #endif
                guard let soraMainChainAsset = soraMainChainAsset else {
                    showUnsupportedAssetAlert()
                    return
                }
                let viewModel = viewModelFactory.buildRecipientViewModel(
                    address: address,
                    isValid: true,
                    canEditing: false
                )
                fee = nil
                tip = nil
                view?.didReceive(viewModel: viewModel)
                selectedChainAsset = soraMainChainAsset
                provideNetworkViewModel(for: soraMainChainAsset.chain, canEdit: false)
                provideInputViewModel()
                interactor.updateSubscriptions(for: soraMainChainAsset)
            })
        }
    }

    func handleSora(qrInfo: SoraQRInfo) {
        recipientAddress = qrInfo.address
        Task {
            let possibleChains = await self.interactor.getPossibleChains(for: qrInfo.address)
            let chainAsset = possibleChains?
                .first(where: { $0.isSora })?.chainAssets
                .first(where: { $0.asset.currencyId == qrInfo.assetId })

            guard let qrChainAsset = chainAsset else {
                showUnsupportedAssetAlert()
                return
            }

            selectedChainAsset = qrChainAsset

            var isUserInteractiveAmount: Bool = true
            if let qrAmount = Decimal(string: qrInfo.amount ?? "") {
                inputResult = .absolute(qrAmount)
                isUserInteractiveAmount = false
            }

            let viewModel = viewModelFactory.buildRecipientViewModel(
                address: qrInfo.address,
                isValid: true,
                canEditing: false
            )

            interactor.updateSubscriptions(for: qrChainAsset)
            await MainActor.run { [isUserInteractiveAmount] in
                view?.didReceive(viewModel: viewModel)
                provideInputViewModel()
                provideNetworkViewModel(for: qrChainAsset.chain, canEdit: false)
                view?.didBlockUserInteractive(isUserInteractiveAmount: isUserInteractiveAmount)
            }
        }
    }

    func handleBokoloCash(qrInfo: BokoloCashQRInfo) {
        recipientAddress = bokoloCasheBridgeAddress
        Task {
            let possibleChains = await self.interactor.getPossibleChains(for: bokoloCasheBridgeAddress)
            let chainAsset = possibleChains?
                .first(where: { $0.isSora })?.chainAssets
                .first(where: { $0.asset.currencyId == bokoloCashAssetCurrencyId })

            guard
                let qrChainAsset = chainAsset,
                let remark = qrInfo.address.data(using: .utf8)
            else {
                showUnsupportedAssetAlert()
                return
            }

            selectedChainAsset = qrChainAsset

            var isUserInteractiveAmount: Bool = true
            if var qrAmount = Decimal(string: qrInfo.transactionAmount ?? ""), qrAmount != .zero {
                var drounded = Decimal()
                NSDecimalRound(&drounded, &qrAmount, 2, .plain)
                inputResult = .absolute(qrAmount)
                isUserInteractiveAmount = false
            }

            let viewModel = viewModelFactory.buildRecipientViewModel(
                address: qrInfo.address,
                isValid: true,
                canEditing: false
            )

            interactor.updateSubscriptions(for: qrChainAsset)
            interactor.addRemark(remark: remark)
            self.remark = remark
            await MainActor.run { [isUserInteractiveAmount] in
                view?.didReceive(viewModel: viewModel)
                provideInputViewModel()
                let networkViewModel = SelectNetworkViewModel(
                    chainName: "Bokolo cash",
                    iconViewModel: BundleImageViewModel(image: R.image.bokolocash()),
                    canEdit: false
                )
                view?.didReceive(selectNetworkViewModel: networkViewModel)
                view?.didBlockUserInteractive(isUserInteractiveAmount: isUserInteractiveAmount)
            }
        }
    }
}

// MARK: - Localizable

extension SendPresenter: Localizable {
    func applyLocalization() {}
}
