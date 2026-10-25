import Foundation
import SoraFoundation
import BigInt
import SSFUtils
import SSFModels
import SSFQRService

final class SendPresenter {
    enum State {
        case initialSelection
        case normal
    }

    enum ValidationCase {
        case validateAmount(completionHandler: () -> Void)
        case validateAll
    }

    private enum UnavailableNextStep {
        case close
        case receive
        case retry
    }

    // MARK: Private properties

    private weak var view: SendViewInput?
    private let router: SendRouterInput
    private let interactor: SendInteractorInput
    private let dataValidatingFactory: SendDataValidatingFactory
    private let logger: LoggerProtocol?
    private let wallet: MetaAccountModel
    private let formScope: SolanaSendFormScope
    private let viewModelFactory: SendViewModelFactoryProtocol
    private let tokenCatalog: CanonicalTokenGroupCatalog
    private var initialData: SendFlowInitialData

    private weak var moduleOutput: SendModuleOutput?

    private var recipientAddress: String? {
        didSet {
            if oldValue != recipientAddress {
                formScope.invalidate()
                invalidateScamWarning()
            }
        }
    }

    /// The Solana recipient refusal last shown, so it is explained once per address.
    private var presentedTransferRefusal: String?
    private var selectionGeneration = 0
    private let conversionScope = SendRequestScope()
    private let scamPresentationScope = SendRequestScope()
    private var selectedChain: ChainModel?
    private var selectedChainAsset: ChainAsset? {
        didSet {
            if oldValue != selectedChainAsset {
                formScope.invalidate()
                invalidateScamWarning()
            }
            if oldValue?.assetKey != selectedChainAsset?.assetKey {
                selectionGeneration += 1
                conversionScope.begin()
            }
            if let oldValue, oldValue.assetKey != selectedChainAsset?.assetKey {
                inputResult = nil
                sendAllEnabled = false
                balance = nil
                balanceUnavailable = false
                utilityBalance = nil
                frozenBalance = nil
                fee = nil
                feeViewModel = nil
                tip = nil
                tipValue = nil
                minimumBalance = nil
                assetAccountInfo = .none
                eqUilibriumTotalBalance = nil
                bokoloSwapValues = nil
                view?.switchEnableSendAllState(enabled: false)
                view?.didReceive(feeViewModel: nil)
                view?.didReceive(tipViewModel: nil)
            }
            DispatchQueue.main.async {
                self.checkSendAllVisibility()
                self.view?.setInputAccessoryView(visible: self.selectedChainAsset?.isBokolo == false)
            }
        }
    }

    private var assetAccountInfo: NoneStateOptional<AssetAccountInfo?> = .none {
        didSet { formScope.invalidate() }
    }

    private var frozenBalance: Decimal? {
        didSet {
            if oldValue != frozenBalance {
                formScope.invalidate()
            }
        }
    }

    private var balance: Decimal? {
        didSet {
            if oldValue != balance {
                formScope.invalidate()
            }
        }
    }

    /// The selected asset's remote balance read failed. No amount is shown for it: neither an
    /// older one nor zero.
    private var balanceUnavailable = false

    private var utilityBalance: Decimal? {
        didSet {
            if oldValue != utilityBalance {
                formScope.invalidate()
            }
        }
    }

    private var tip: Decimal? {
        didSet {
            if oldValue != tip {
                formScope.invalidate()
            }
        }
    }

    private var tipValue: BigUInt? {
        didSet {
            if oldValue != tipValue {
                formScope.invalidate()
            }
        }
    }

    private var fee: Decimal? {
        didSet {
            if oldValue != fee {
                formScope.invalidate()
            }
        }
    }

    private var minimumBalance: BigUInt? {
        didSet {
            if oldValue != minimumBalance {
                formScope.invalidate()
            }
        }
    }

    private var amountInputRevision = UUID()
    private var inputResult: AmountInputResult? {
        didSet {
            amountInputRevision = UUID()
            formScope.invalidate()
        }
    }

    private var scamInfo: ScamInfo? {
        didSet {
            if oldValue != scamInfo {
                formScope.invalidate()
            }
        }
    }

    private var state: State = .normal
    private var eqUilibriumTotalBalance: Decimal? {
        didSet {
            if oldValue != eqUilibriumTotalBalance {
                formScope.invalidate()
            }
        }
    }

    private var sendAllEnabled: Bool = false {
        didSet {
            if oldValue != sendAllEnabled {
                formScope.invalidate()
            }
        }
    }

    private var isPresentingUnavailableReason = false
    private var balanceMinusFeeAndTip: Decimal {
        let feePaymentChainAsset = interactor.getFeePaymentChainAsset(for: selectedChainAsset)
        if feePaymentChainAsset?.identifier != selectedChainAsset?.identifier {
            return (balance ?? 0) - (frozenBalance ?? 0)
        }
        return (balance ?? 0) - (fee ?? 0) - (tip ?? 0) - (frozenBalance ?? 0)
    }

    private var freeBalance: Decimal {
        (balance ?? 0) - (frozenBalance ?? 0)
    }

    private var fullAmount: Decimal {
        let feePaymentChainAsset = interactor.getFeePaymentChainAsset(for: selectedChainAsset)
        if feePaymentChainAsset?.identifier != selectedChainAsset?.identifier {
            return balance ?? 0
        }
        return (balance ?? 0) + (fee ?? 0) + (tip ?? 0)
    }

    private var feeViewModel: BalanceViewModelProtocol?
    private var balanceViewModelFactoryByAsset: [String: BalanceViewModelFactoryProtocol] = [:]

    // MARK: - Bokolo cash properties

    private var bokoloSwapValues: (swap: SwapValues, fee: Decimal?)?

    // MARK: - Constructors

    init(
        interactor: SendInteractorInput,
        router: SendRouterInput,
        localizationManager: LocalizationManagerProtocol,
        viewModelFactory: SendViewModelFactoryProtocol,
        dataValidatingFactory: SendDataValidatingFactory,
        logger: LoggerProtocol? = nil,
        wallet: MetaAccountModel,
        initialData: SendFlowInitialData,
        tokenCatalog: CanonicalTokenGroupCatalog = .bundled,
        selectedWalletSettings: SelectedWalletSettings = .shared
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.logger = logger
        self.wallet = wallet
        formScope = SolanaSendFormScope(selection: selectedWalletSettings.sendAuthority.capture(for: wallet))
        self.initialData = initialData
        self.tokenCatalog = tokenCatalog

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func checkSendAllVisibility() {
        let visible = minimumBalance.map { $0 > BigUInt.zero && freeBalance > 0 && selectedChainAsset?.isUtility == true }
        view?.switchEnableSendAllVisibility(isVisible: visible == true)
    }

    private func buildBalanceViewModelFactory(
        wallet: MetaAccountModel,
        for chainAsset: ChainAsset?
    ) -> BalanceViewModelFactoryProtocol? {
        guard let chainAsset = chainAsset else {
            return nil
        }

        if let factory = balanceViewModelFactoryByAsset[chainAsset.identifier] {
            return factory
        }

        let assetInfo = chainAsset.asset
            .displayInfo(with: chainAsset.chain.icon)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            selectedMetaAccount: wallet
        )

        balanceViewModelFactoryByAsset[chainAsset.identifier] = balanceViewModelFactory
        return balanceViewModelFactory
    }

    private func provideAssetVewModel() {
        guard let chainAsset = selectedChainAsset, case .value = assetAccountInfo else { return }
        let priceData = AssetTrustResolver.displayPrice(for: chainAsset, currency: wallet.selectedCurrency)
        let balanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: chainAsset)
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFeeAndTip) ?? 0.0

        let viewModel = balanceViewModelFactory?.createAssetBalanceViewModel(
            inputAmount,
            balance: balanceUnavailable ? nil : freeBalance,
            priceData: priceData,
            selectable: initialData.selectableAsset
        ).value(for: selectedLocale)

        DispatchQueue.main.async {
            self.view?.didReceive(assetBalanceViewModel: viewModel)
        }

        let fullAmount = inputResult?.absoluteValue(from: fullAmount) ?? .zero
        interactor.calculateEquilibriumBalance(chainAsset: chainAsset, amount: fullAmount)
    }

    private func provideTipViewModel() {
        guard let chainAsset = selectedChainAsset,
              let utilityAsset = interactor.getFeePaymentChainAsset(for: selectedChainAsset),
              let balanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: utilityAsset)
        else { return }

        let priceData = AssetTrustResolver.displayPrice(for: chainAsset, currency: wallet.selectedCurrency)
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

    private func handleFeeReceived() {
        if selectedChainAsset?.isBokolo == true {
            checkXorFeePaymentPossibles()
        } else {
            provideFeeViewModel()
        }
    }

    private func provideFeeViewModel(checkBokolo _: Bool = true) {
        guard
            let utilityAsset = interactor.getFeePaymentChainAsset(for: selectedChainAsset),
            let balanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: utilityAsset)
        else { return }

        let priceData = utilityAsset.asset.getPrice(for: wallet.selectedCurrency)
        let viewModel = fee
            .map { balanceViewModelFactory.balanceFromPrice($0, priceData: priceData, usageCase: .detailsCrypto) }?
            .value(for: selectedLocale)

        DispatchQueue.main.async {
            self.view?.didReceive(feeViewModel: viewModel)
        }
        feeViewModel = viewModel
    }

    private func provideInputViewModel() {
        guard let chainAsset = selectedChainAsset else { return }

        let balanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: chainAsset)

        let available: Decimal
        if chainAsset.isBokolo {
            available = (balance ?? .zero) - (bokoloSwapValues?.fee ?? .zero)
        } else {
            available = balanceMinusFeeAndTip
        }
        let inputAmount = inputResult?.absoluteValue(from: available)

        let inputViewModel = balanceViewModelFactory?.createBalanceInputViewModel(inputAmount)
            .value(for: selectedLocale)
        let revision = amountInputRevision

        DispatchQueue.main.async {
            guard self.amountInputRevision == revision else { return }
            self.view?.didReceive(amountInputViewModel: inputViewModel)
            let isVisible = chainAsset.chain.externalApi?.history != nil
            self.view?.setHistoryButton(isVisible: isVisible)
        }
    }

    private func provideNetworkViewModel(for chain: ChainModel, canEdit: Bool) {
        let viewModel = viewModelFactory.buildNetworkViewModel(chain: chain, canEdit: canEdit)
        let generation = selectionGeneration
        DispatchQueue.main.async {
            guard self.selectionGeneration == generation else { return }
            self.view?.didReceive(selectNetworkViewModel: viewModel)
        }
    }

    private func refreshFee(for chainAsset: ChainAsset, address: String?) {
        switch initialData {
        case .address, .chainAsset, .soraMainnet:
            if selectedChainAsset?.isBokolo == true {
                guard let transfer = prepareXorlessTransfer() else {
                    return
                }
                interactor.didReceive(xorlessTransfer: transfer)
                return
            }
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
    }

    private func invalidateScamWarning() {
        interactor.invalidateScamInfo()
        didReceive(scamInfo: nil)
    }

    private func handle(newAddress: String) {
        if let chainAsset = selectedChainAsset {
            let accountScoreViewModel = viewModelFactory.buildAccountScoreViewModel(address: newAddress, chain: chainAsset.chain)
            DispatchQueue.main.async {
                self.view?.didReceive(accountScoreViewModel: accountScoreViewModel)
            }
        }

        recipientAddress = newAddress.isEmpty ? nil : newAddress
        guard newAddress.isNotEmpty, let chainAsset = selectedChainAsset else { return }
        let viewModel = viewModelFactory.buildRecipientViewModel(
            address: newAddress,
            isValid: interactor.validate(address: newAddress, for: chainAsset.chain).isValid,
            canEditing: true
        )

        DispatchQueue.main.async {
            self.view?.didReceive(viewModel: viewModel)
        }

        interactor.updateSubscriptions(for: chainAsset)
        interactor.fetchScamInfo(for: newAddress, chain: chainAsset.chain)
    }

    private func handle(selectedChain: ChainModel?) {
        guard let selectedChain else { return }
        switch state {
        case .initialSelection:
            self.selectedChain = selectedChain
            state = .normal
            defineOrSelectAsset(for: selectedChain)
        case .normal:
            guard let current = selectedChainAsset else { return }
            guard let member = SendNetworkSelection.member(for: current, on: selectedChain, catalog: tokenCatalog) else {
                router.present(
                    message: R.string.localizable.sendNetworkUnavailable(selectedChain.name, preferredLanguages: selectedLocale.rLanguages),
                    title: R.string.localizable.commonWarning(preferredLanguages: selectedLocale.rLanguages),
                    closeAction: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages),
                    from: view
                )
                return
            }
            self.selectedChain = selectedChain
            selectedChainAsset = member
            handle(selectedChainAsset: member)
        }
    }

    private func provideNetworkSelection(for chainAsset: ChainAsset) {
        provideNetworkViewModel(for: chainAsset.chain, canEdit: false)
        guard tokenCatalog.group(for: chainAsset) != nil else { return }
        let generation = selectionGeneration
        interactor.defineAvailableChains(for: chainAsset, wallet: wallet) { [weak self] chains in
            guard let self, self.selectionGeneration == generation, self.selectedChainAsset?.assetKey == chainAsset.assetKey else { return }
            self.provideNetworkViewModel(for: chainAsset.chain, canEdit: (chains?.count ?? 0) > 1)
        }
    }

    private func handle(selectedChainAsset: ChainAsset) {
        fee = nil
        provideNetworkSelection(for: selectedChainAsset)
        provideAssetVewModel()
        provideInputViewModel()
        if let recipientAddress = recipientAddress {
            handle(newAddress: recipientAddress)
        } else {
            interactor.updateSubscriptions(for: selectedChainAsset)
        }
    }

    private func defineOrSelectAsset(for chain: ChainModel) {
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

    private func showSameAddressAlert(
        _ address: String, formReceipt: UUID?, successCompletion: @escaping (String) -> Void
    ) {
        let action = SheetAlertPresentableAction(
            title: R.string.localizable.commonProceed(preferredLanguages: selectedLocale.rLanguages)
        ) {
            successCompletion(address)
        }
        let message = R.string.localizable.sameAddressTransferWarningMessage(
            preferredLanguages: selectedLocale.rLanguages
        )
        let title = R.string.localizable.commonWarning(preferredLanguages: selectedLocale.rLanguages)
        let close = R.string.localizable.commonCancel(preferredLanguages: selectedLocale.rLanguages)
        guard let formReceipt else {
            router.present(message: message, title: title, closeAction: close, from: view, actions: [action])
            return
        }
        let presentationID = UUID()
        let model = SheetAlertPresentableViewModel(
            title: title, message: message, actions: [action], closeAction: close,
            dismissCompletion: { [weak self] in self?.formScope.endPresentation(presentationID) },
            presentationID: presentationID
        )
        formScope.bindPresentation(presentationID, to: formReceipt)
        router.presentFormWarning(viewModel: model, from: view)
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

    private func presentUnavailable(reason: SendUnavailableReason, chainAsset: ChainAsset) {
        isPresentingUnavailableReason = true
        let languages = selectedLocale.rLanguages
        var nextStep = UnavailableNextStep.close
        var actions: [SheetAlertPresentableAction] = []
        if reason.offersReceive {
            actions.append(SheetAlertPresentableAction(
                title: R.string.localizable.commonActionReceive(preferredLanguages: languages),
                style: .pinkBackgroundWhiteText
            ) {
                nextStep = .receive
            })
        }
        if reason.offersRetry {
            actions.append(SheetAlertPresentableAction(
                title: R.string.localizable.commonRetry(preferredLanguages: languages),
                style: .pinkBackgroundWhiteText
            ) {
                nextStep = .retry
            })
        }

        let viewModel = SheetAlertPresentableViewModel(
            title: reason.title(for: selectedLocale),
            message: reason.message(for: selectedLocale),
            actions: actions,
            closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
            // Every way out of the sheet ends here, so the choice decides the next screen.
            dismissCompletion: { [weak self] in
                guard let self else { return }
                switch nextStep {
                case .close:
                    router.dismiss(view: view)
                case .receive:
                    router.presentReceive(leavingSendFlowFrom: view, chainAsset: chainAsset, wallet: wallet)
                case .retry:
                    isPresentingUnavailableReason = false
                    interactor.updateSubscriptions(for: chainAsset)
                }
            },
            icon: R.image.iconWarningBig()
        )
        router.present(viewModel: viewModel, from: view)
    }

    private func showUnsupportedAssetAlert() {
        let dissmissAction = SheetAlertPresentableAction(
            title: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages)
        ) { [weak self] in
            self?.router.dismiss(view: self?.view)
        }
        let assetManagementAction = SheetAlertPresentableAction(
            title: R.string.localizable.walletManageAssets(preferredLanguages: selectedLocale.rLanguages),
            style: .pinkBackgroundWhiteText
        ) { [weak self] in
            guard let self else { return }
            self.router.showManageAsset(from: self.view, wallet: self.wallet)
        }
        let alertViewModel = SheetAlertPresentableViewModel(
            title: R.string.localizable.commonActionReceive(preferredLanguages: selectedLocale.rLanguages),
            message: R.string.localizable.errorScanQrDisabledAsset(preferredLanguages: selectedLocale.rLanguages),
            actions: [assetManagementAction, dissmissAction],
            closeAction: nil,
            dismissCompletion: { [weak self] in
                self?.router.dismiss(view: self?.view)
            }
        )
        router.present(viewModel: alertViewModel, from: view)
    }

    private func isCurrentFormReceipt(_ receipt: UUID?) -> Bool {
        guard let receipt else { return true }
        if let visibility = view as? SolanaSendFormViewState, !visibility.allowsSendFormContinuation {
            formScope.suspend()
            return false
        }
        return formScope.isCurrent(receipt)
    }

    private func consumeFormReceipt(_ receipt: UUID?) -> Bool {
        guard isCurrentFormReceipt(receipt) else { return false }
        guard let receipt else { return true }
        return formScope.consume(receipt)
    }

    private func formAction(_ receipt: UUID?, action: @escaping (SendPresenter) -> Void) -> () -> Void {
        { [weak self] in
            guard let self else { return }
            guard consumeFormReceipt(receipt) else { return }
            action(self)
        }
    }

    private func warningPresenter(for receipt: UUID?) -> BaseErrorPresentable? {
        guard let receipt else { return nil }
        return SolanaSendFormWarningPresenter { [weak self] model, view in
            guard let self, self.isCurrentFormReceipt(receipt) else { return }
            let owned = SheetAlertPresentableViewModel(
                title: model.title, titleStyle: model.titleStyle, message: model.message,
                messageStyle: model.messageStyle, actions: model.actions, isInfo: model.isInfo,
                closeAction: model.closeAction,
                dismissCompletion: { [weak self] in
                    self?.formScope.endPresentation(model.presentationID)
                    model.dismissCompletion?()
                },
                icon: model.icon, actionAxis: model.actionAxis, scrollableContent: model.scrollableContent,
                presentationID: model.presentationID
            )
            self.formScope.bindPresentation(model.presentationID, to: receipt)
            self.router.presentFormWarning(viewModel: owned, from: view)
        }
    }

    private func validateAddress(
        with chainAsset: ChainAsset, formReceipt: UUID? = nil, successCompletion: @escaping (String) -> Void
    ) {
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
                    guard isCurrentFormReceipt(formReceipt) else { return }
                    guard let possibleChains = possibleChains, possibleChains.isNotEmpty else {
                        showInvalidAddressAlert()
                        return
                    }

                    showPossibleChainsAlert(possibleChains)
                }
            }
        case let .sameAddress(address):
            showSameAddressAlert(address, formReceipt: formReceipt, successCompletion: successCompletion)
        }
    }

    private func validateAmountInput(with chainAsset: ChainAsset, completion: @escaping () -> Void) {
        let ownsSolana = UniversalWalletRegistry.solanaNetwork(for: chainAsset.chain.chainId) != nil
        if ownsSolana, let visibility = view as? SolanaSendFormViewState {
            guard visibility.allowsSendFormContinuation else { formScope.suspend(); return }
            formScope.resume()
        }
        let receipt = ownsSolana ? formScope.begin(awaitingAddress: false) : nil
        guard !ownsSolana || receipt != nil else { return }
        validateInputData(
            with: "", chainAsset: chainAsset,
            validationCase: .validateAmount(completionHandler: completion), formReceipt: receipt
        )
    }

    private func validateInputData(
        with address: String,
        chainAsset: ChainAsset,
        validationCase: ValidationCase,
        formReceipt: UUID? = nil
    ) {
        guard isCurrentFormReceipt(formReceipt) else { return }
        let warningPresentable = warningPresenter(for: formReceipt)
        let sendAmountDecimal = inputResult?.absoluteValue(from: balanceMinusFeeAndTip)
        let spendingValue = (sendAmountDecimal ?? 0) + (fee ?? 0) + (tip ?? 0)

        let balanceType: BalanceType = !chainAsset.isUtility ?
            .orml(balance: balance, utilityBalance: utilityBalance) : .utility(balance: utilityBalance)
        var minimumBalanceDecimal: Decimal?
        if let minBalance = minimumBalance {
            let feePaymentChainAsset = interactor.getFeePaymentChainAsset(for: selectedChainAsset).or(chainAsset)

            let precision = feePaymentChainAsset.asset.precision
            minimumBalanceDecimal = Decimal.fromSubstrateAmount(
                minBalance,
                precision: Int16(precision)
            )
        } else if chainAsset.chain.isEthereum {
            minimumBalanceDecimal = .zero
        }

        let spending: Decimal
        if chainAsset.isUtility {
            spending = spendingValue
        } else {
            spending = fee.or(.zero)
        }

        var validators: [DataValidating?]
        switch validationCase {
        case let .validateAmount(handler):
            validators = [minimumBalance != nil ? dataValidatingFactory.exsitentialDepositIsNotViolated(
                spending: spending,
                balance: eqUilibriumTotalBalance ?? utilityBalance.or(.zero),
                minimumBalance: minimumBalanceDecimal.or(.zero),
                chainAsset: chainAsset,
                locale: selectedLocale,
                sendAllEnabled: sendAllEnabled,
                warningPresentable: warningPresentable,
                proceedAction: formAction(formReceipt) { presenter in
                    presenter.sendAllEnabled = true
                    presenter.view?.switchEnableSendAllState(enabled: true)
                    handler()
                },
                setMaxAction: formAction(formReceipt) { presenter in
                    presenter.sendAllEnabled = true
                    presenter.view?.switchEnableSendAllState(enabled: true)
                    presenter.selectAmountPercentage(1, validate: false)
                },
                cancelAction: formAction(formReceipt) { presenter in
                    presenter.sendAllEnabled = false
                    presenter.view?.switchEnableSendAllState(enabled: false)
                    presenter.selectAmountPercentage(0, validate: false)
                }
            ) : nil]
        case .validateAll:
            validators = [
                dataValidatingFactory.has(
                    fee: fee, locale: selectedLocale,
                    onError: formAction(formReceipt) { presenter in
                        presenter.refreshFee(for: chainAsset, address: address)
                    }
                ),
                dataValidatingFactory.canPayFeeAndAmount(
                    balanceType: balanceType,
                    feeAndTip: (fee ?? 0) + (tip ?? 0),
                    sendAmount: sendAmountDecimal,
                    locale: selectedLocale
                ),
                dataValidatingFactory.exsitentialDepositIsNotViolated(
                    spending: spending,
                    balance: eqUilibriumTotalBalance ?? utilityBalance.or(.zero),
                    minimumBalance: minimumBalanceDecimal.or(.zero),
                    chainAsset: chainAsset,
                    locale: selectedLocale,
                    sendAllEnabled: sendAllEnabled,
                    warningPresentable: warningPresentable,
                    proceedAction: formAction(formReceipt) { presenter in
                        presenter.sendAllEnabled = true
                        presenter.view?.switchEnableSendAllState(enabled: true)
                    },
                    setMaxAction: formAction(formReceipt) { presenter in
                        presenter.sendAllEnabled = true
                        presenter.view?.switchEnableSendAllState(enabled: true)
                        presenter.selectAmountPercentage(1)
                    },
                    cancelAction: formAction(formReceipt) { presenter in
                        presenter.sendAllEnabled = false
                        presenter.view?.switchEnableSendAllState(enabled: false)
                        presenter.selectAmountPercentage(0)
                    }
                )
            ]
        }
        DataValidationRunner(validators: validators.compactMap { $0 }).runValidation { [weak self] in
            switch validationCase {
            case let .validateAmount(handler):
                self?.formAction(formReceipt, action: { _ in handler() })()
            case .validateAll:
                guard
                    let strongSelf = self,
                    strongSelf.consumeFormReceipt(formReceipt),
                    let amount = sendAmountDecimal?.toSubstrateAmount(precision: Int16(chainAsset.asset.precision))
                else { return }
                // SSF ChainOptions no longer includes .checkAppId; appId is not used
                let appId: BigUInt? = nil

                let transfer = Transfer(
                    chainAsset: chainAsset,
                    amount: amount,
                    receiver: address,
                    tip: strongSelf.tipValue,
                    appId: appId
                )
                strongSelf.router.presentConfirm(
                    from: strongSelf.view,
                    wallet: strongSelf.wallet,
                    chainAsset: chainAsset,
                    call: .transfer(transfer),
                    scamInfo: strongSelf.scamInfo,
                    feeViewModel: strongSelf.feeViewModel,
                    selection: formReceipt == nil ? nil : strongSelf.formScope.selection
                )
            }
        }
    }

    private func validateXorlessTransfer() {
        guard
            let bokoloChainAsset = selectedChainAsset,
            let xorBalance = utilityBalance,
            let bokoloBalance = balance
        else {
            return
        }

        var sendAmountDecimal = inputResult?.absoluteValue(from: bokoloBalance)
        var balanceType: BalanceType
        var feeAndTip: Decimal
        var feeForValidation: Decimal?
        if let xorFee = fee, xorBalance > xorFee {
            balanceType = .orml(balance: bokoloBalance, utilityBalance: xorBalance)
            feeAndTip = xorFee
            feeForValidation = fee
        } else {
            balanceType = .utility(balance: bokoloBalance)
            feeAndTip = bokoloSwapValues?.fee ?? .zero
            sendAmountDecimal = (sendAmountDecimal ?? .zero) - (bokoloSwapValues?.fee ?? .zero)
            feeForValidation = bokoloSwapValues?.fee
        }

        DataValidationRunner(validators: [
            dataValidatingFactory.has(fee: feeForValidation, locale: selectedLocale, onError: { [weak self] in
                guard let transfer = self?.prepareXorlessTransfer() else {
                    return
                }
                self?.interactor.didReceive(xorlessTransfer: transfer)
            }),
            dataValidatingFactory.canPayFeeAndAmount(
                balanceType: balanceType,
                feeAndTip: feeAndTip,
                sendAmount: sendAmountDecimal,
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            guard
                let strongSelf = self,
                let transfer = strongSelf.prepareXorlessTransfer()
            else { return }

            strongSelf.router.presentConfirm(
                from: strongSelf.view,
                wallet: strongSelf.wallet,
                chainAsset: bokoloChainAsset,
                call: .xorlessTransfer(transfer),
                scamInfo: nil,
                feeViewModel: strongSelf.feeViewModel,
                selection: nil
            )
        }
    }

    private func provideBokoloFeeViewModel(for chainAsset: ChainAsset) {
        guard let balanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: chainAsset) else { return }

        let priceData = chainAsset.asset.getPrice(for: wallet.selectedCurrency)
        let viewModel = bokoloSwapValues?.fee
            .map { balanceViewModelFactory.balanceFromPrice($0, priceData: priceData, usageCase: .detailsCrypto) }?
            .value(for: selectedLocale)

        view?.didReceive(feeViewModel: viewModel)
        feeViewModel = viewModel
    }

    // MARK: - QR handlers

    private func handleSora(qrInfo: SoraQRInfo) {
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

            var isUserInteractiveAmount = true
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

    private func prepareXorlessTransfer() -> XorlessTransfer? {
        do {
            guard let selectedChainAsset = selectedChainAsset else {
                throw ConvenienceError(error: "Can't prepare xorless transfer")
            }

            let receiver: Data
            if let recipientAddress = recipientAddress {
                receiver = try AddressFactory.accountId(from: recipientAddress, chain: selectedChainAsset.chain)
            } else {
                receiver = AddressFactory.randomAccountId(for: selectedChainAsset.chain)
            }
            let filterMode: PolkaswapLiquidityFilterMode = .disabled
            let maxAmountIn = ((bokoloSwapValues?.fee ?? .zero) * 1.5).toSubstrateAmount(precision: Int16(selectedChainAsset.asset.precision))

            let available = (balance ?? .zero) - (bokoloSwapValues?.fee ?? .zero)
            let amount = inputResult?
                .absoluteValue(from: available)
                .toSubstrateAmount(precision: Int16(selectedChainAsset.asset.precision))
                ?? .zero
            let fee = fee?.toSubstrateAmount(precision: Int16(selectedChainAsset.asset.precision)) ?? .zero
            let feeReserve = BigUInt(10_000_000_000_000_000)

            let dexId = String(bokoloSwapValues?.swap.dexId ?? 0)
            return XorlessTransfer(
                dexId: dexId,
                assetId: SoraAssetId(wrappedValue: BokoloConstants.bokoloCashAssetCurrencyId),
                receiver: receiver,
                amount: amount,
                desiredXorAmount: fee + feeReserve,
                maxAmountIn: maxAmountIn ?? .zero,
                selectedSourceTypes: [],
                filterMode: PolkaswapCallFilterModeType(wrappedName: filterMode.code, wrappedValue: nil),
                additionalData: Data()
            )
        } catch {
            logger?.customError(error)
            return nil
        }
    }

    private func checkXorFeePaymentPossibles() {
        let request = conversionScope.begin()
        let generation = selectionGeneration
        bokoloSwapValues = nil
        guard
            let xorBalance = utilityBalance,
            let xorFee = fee
        else {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.conversionScope.isCurrent(request) else { return }
                self.view?.didReceive(feeViewModel: nil)
            }
            return
        }

        if xorBalance > xorFee {
            provideFeeViewModel()
        } else {
            feeViewModel = nil
            view?.didReceive(feeViewModel: nil)
            Task { @MainActor [weak self] in
                guard let self, self.selectionGeneration == generation, self.conversionScope.isCurrent(request),
                      let bokoloChainAsset = selectedChainAsset,
                      let xorChainAsset = interactor.getFeePaymentChainAsset(for: bokoloChainAsset),
                      let feeValue = xorFee.toSubstrateAmount(precision: Int16(xorChainAsset.asset.precision))
                else {
                    return
                }
                do {
                    guard let bokoloSwap = try await interactor.convert(
                        chainAsset: xorChainAsset,
                        toChainAsset: bokoloChainAsset,
                        amount: feeValue
                    ), selectionGeneration == generation, conversionScope.isCurrent(request) else { return }
                    let bokoloAmount = BigUInt(bokoloSwap.amount) ?? .zero
                    let bokoloFee = Decimal.fromSubstrateAmount(bokoloAmount, precision: Int16(bokoloChainAsset.asset.precision))
                    bokoloSwapValues = (bokoloSwap, bokoloFee)
                    provideBokoloFeeViewModel(for: bokoloChainAsset)
                } catch {
                    guard selectionGeneration == generation, conversionScope.isCurrent(request), !(error is CancellationError) else { return }
                    view?.didStopFeeCalculation()
                    router.present(error: error, from: view, locale: selectedLocale)
                }
            }
        }
    }
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
            provideNetworkSelection(for: chainAsset)
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
        case let .soraMainnet(qrInfo):
            handleSora(qrInfo: qrInfo)
        }
    }

    func selectAmountPercentage(_ percentage: Float, validate: Bool = true) {
        inputResult = .rate(Decimal(Double(percentage)))
        if let chainAsset = selectedChainAsset, validate {
            validateAmountInput(with: chainAsset) { [weak self] in
                self?.inputResult = .rate(Decimal(Double(percentage)))
                self?.provideAssetVewModel()
                self?.provideInputViewModel()
            }
        }

        provideAssetVewModel()
        provideInputViewModel()
        guard let chainAsset = selectedChainAsset else { return }
        refreshFee(for: chainAsset, address: recipientAddress)
    }

    func didEditAmount(_ newValue: Decimal) -> () -> Void {
        // Commit the visible draft now and bind deferred work to its original input and form lifetime.
        inputResult = .absolute(newValue)
        let revision = amountInputRevision
        let lifetime = formScope.inputLifetime
        let ownsSolana = selectedChainAsset.map {
            UniversalWalletRegistry.solanaNetwork(for: $0.chain.chainId) != nil
        } ?? false
        return { [weak self] in
            guard let self, let lifetime, self.formScope.inputLifetime == lifetime,
                  self.amountInputRevision == revision else { return }
            guard !ownsSolana || self.formScope.selection.isCurrent else { return }
            self.updateAmount(newValue)
        }
    }

    func updateAmount(_ newValue: Decimal) {
        inputResult = .absolute(newValue)
        if let chainAsset = selectedChainAsset {
            validateAmountInput(with: chainAsset) { [weak self] in
                self?.provideAssetVewModel()
            }
        }

        provideAssetVewModel()
        guard let chainAsset = selectedChainAsset else { return }
        refreshFee(for: chainAsset, address: recipientAddress)
    }

    func didTapBackButton() {
        formScope.suspend()
        router.dismiss(view: view)
    }

    func didTapContinueButton() {
        guard let chainAsset = selectedChainAsset else { return }
        if chainAsset.isBokolo {
            validateXorlessTransfer()
        } else {
            let ownsSolana = UniversalWalletRegistry.solanaNetwork(for: chainAsset.chain.chainId) != nil
            if ownsSolana, let visibility = view as? SolanaSendFormViewState {
                guard visibility.allowsSendFormContinuation else { formScope.suspend(); return }
                formScope.resume()
            }
            let receipt = ownsSolana ? formScope.begin() : nil
            guard !ownsSolana || receipt != nil else { return }
            validateAddress(with: chainAsset, formReceipt: receipt) { [weak self] address in
                guard let self else { return }
                guard isCurrentFormReceipt(receipt) else { return }
                if let receipt, !formScope.acceptAddress(receipt) { return }
                validateInputData(
                    with: address,
                    chainAsset: chainAsset,
                    validationCase: .validateAll,
                    formReceipt: receipt
                )
            }
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
            selectedAssetId: selectedChainAsset?.asset.id,
            chainAssets: nil,
            output: self
        )
    }

    func didTapSelectNetwork() {
        guard let chainAsset = selectedChainAsset, tokenCatalog.group(for: chainAsset) != nil else { return }
        let generation = selectionGeneration
        interactor.defineAvailableChains(for: chainAsset, wallet: wallet) { [weak self] chains in
            guard let strongSelf = self, let availableChains = chains, availableChains.count > 1,
                  strongSelf.selectionGeneration == generation,
                  strongSelf.selectedChainAsset?.assetKey == chainAsset.assetKey else { return }
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

    func didSwitchSendAll(_ enabled: Bool) {
        sendAllEnabled = enabled
        selectAmountPercentage(Float(enabled.intValue), validate: false)
    }
}

// MARK: - SendInteractorOutput

extension SendPresenter: SendInteractorOutput {
    func didReceiveAssetAccountInfo(assetAccountInfo: AssetAccountInfo?) {
        self.assetAccountInfo = .value(assetAccountInfo)
        frozenBalance = selectedChainAsset.flatMap { Decimal.fromSubstrateAmount((assetAccountInfo?.locked).or(.zero), precision: Int16($0.asset.precision)) }
        provideAssetVewModel()
    }

    func didReceiveAssetAccountInfoError(error: Error) {
        assetAccountInfo = .value(nil)
        provideAssetVewModel()
        logger?.customError(error)
    }

    func didReceive(scamInfo: ScamInfo?) {
        let request = scamPresentationScope.begin()
        self.scamInfo = scamInfo

        DispatchQueue.main.async { [weak self] in
            guard let self, self.scamPresentationScope.isCurrent(request) else { return }
            self.view?.didReceive(scamInfo: scamInfo)
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset) {
        switch result {
        case let .success(accountInfo):
            if chainAsset == selectedChainAsset {
                balanceUnavailable = false
                balance = accountInfo.map {
                    Decimal.fromSubstrateAmount(
                        $0.data.sendAvailable,
                        precision: Int16(chainAsset.asset.precision)
                    )
                } ?? 0.0

                if chainAsset.isUtility {
                    utilityBalance = balance
                }
                checkSendAllVisibility()
            } else if let utilityAsset = interactor.getFeePaymentChainAsset(for: chainAsset),
                      utilityAsset == chainAsset {
                utilityBalance = accountInfo.map {
                    Decimal.fromSubstrateAmount(
                        $0.data.sendAvailable,
                        precision: Int16(utilityAsset.asset.precision)
                    )
                } ?? 0
            }
            if selectedChainAsset?.isBokolo == true {
                provideAssetVewModel()
                checkXorFeePaymentPossibles()
            } else {
                provideAssetVewModel()
            }
        case let .failure(error):
            logger?.error("Did receive account info error: \(error.logSafeDescription)")
            // A one-shot remote read that failed leaves no current balance, so no amount is
            // shown: neither one read earlier nor zero reads as available or as Max. Subscribed
            // balances keep their last update until the next one, as before.
            if chainAsset == selectedChainAsset,
               UniversalWalletRegistry.readsBalanceRemotely(chainAsset.chain.chainId) {
                balanceUnavailable = true
                balance = nil
                if chainAsset.isUtility {
                    utilityBalance = nil
                }
                checkSendAllVisibility()
                provideAssetVewModel()
            }
        }
    }

    func didReceiveMinimumBalance(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(minimumBalance):
            self.minimumBalance = minimumBalance
            checkSendAllVisibility()
            logger?.info("Did receive minimum balance \(minimumBalance)")
        case let .failure(error):
            checkSendAllVisibility()
            logger?.error("Did receive minimum balance error: \(error.logSafeDescription)")
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

            handleFeeReceived()
            provideAssetVewModel()

            switch inputResult {
            case .rate:
                provideInputViewModel()
            default:
                break
            }
        case let .failure(error):
            logger?.error("Did receive fee error: \(error.logSafeDescription)")
            presentTransferRefusalIfNeeded(error)
        }
    }

    /// Solana refuses some recipients before anything is signed (a token account, a program).
    /// The fee quote finds out first, so the reason is shown here, once per address, instead
    /// of leaving the fee empty with no explanation.
    private func presentTransferRefusalIfNeeded(_ error: Error) {
        guard let refusal = error as? SolanaTransferRefusal else {
            return
        }

        let key = "\(recipientAddress ?? "")|\(refusal)"
        guard presentedTransferRefusal != key else {
            return
        }
        presentedTransferRefusal = key
        router.present(error: refusal, from: view, locale: selectedLocale)
    }

    func didReceiveTip(result: Result<BigUInt, Error>) {
        view?.didStopTipCalculation()
        switch result {
        case let .success(tip):
            guard let chainAsset = selectedChainAsset, let address = recipientAddress else { return }
            self.tip = Decimal.fromSubstrateAmount(tip, precision: Int16(chainAsset.asset.precision))
            tipValue = tip

            provideTipViewModel()
            refreshFee(for: chainAsset, address: address)
        case let .failure(error):
            logger?.error("Did receive tip error: \(error.logSafeDescription)")
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

    func didReceiveDependenciesError(_ error: Error, for chainAsset: ChainAsset) {
        logger?.error("Did receive send dependencies error: \(error.logSafeDescription)")
        // A late result for a network the user already left, or a repeat while the sheet is
        // up (each recipient edit re-routes), must not stack another sheet.
        guard
            !isPresentingUnavailableReason,
            selectedChainAsset?.chainAssetId == chainAsset.chainAssetId
        else {
            return
        }

        view?.didStopFeeCalculation()
        presentUnavailable(
            reason: SendUnavailableReason(dependenciesError: error, chain: chainAsset.chain),
            chainAsset: chainAsset
        )
    }
}

// MARK: - ScanQRModuleOutput

extension SendPresenter: ScanQRModuleOutput {
    func didFinishWith(scanType: QRMatcherType) {
        guard let qrInfo = scanType.qrInfo else {
            return
        }

        initialData = SendFlowInitialData(qrInfoType: qrInfo)
        switch qrInfo {
        case let .sora(qrInfo):
            handleSora(qrInfo: qrInfo)
        case let .cex(qrInfo):
            searchTextDidChanged(qrInfo.address)
        }
    }
}

// MARK: - ContactsModuleOutput

extension SendPresenter: ContactsModuleOutput {
    func didSelect(address: String) {
        searchTextDidChanged(address)
    }
}

extension SendPresenter: SendModuleInput {}

// MARK: - SelectAssetModuleOutput

extension SendPresenter: SelectAssetModuleOutput {
    func assetSelection(didCompleteWith chainAsset: ChainAsset?, contextTag _: Int?) {
        guard let chainAsset else {
            if selectedChainAsset == nil {
                router.dismiss(view: view)
            }
            return
        }
        // The picker already returned an exact network asset; never re-derive it from its ticker.
        state = .normal
        selectedChain = chainAsset.chain
        selectedChainAsset = chainAsset
        handle(selectedChainAsset: chainAsset)
    }
}

// MARK: - SelectNetworkDelegate

extension SendPresenter: SelectNetworkDelegate {
    func chainSelection(
        view _: SelectNetworkViewInput,
        didCompleteWith chain: ChainModel?,
        contextTag _: Int?
    ) {
        handle(selectedChain: chain)
    }
}

// MARK: - Localizable

extension SendPresenter: Localizable {
    func applyLocalization() {}
}

extension SendPresenter: SolanaSendFormScopeManaging {
    func resumeSendForm() {
        formScope.resume()
    }

    func suspendSendForm() {
        formScope.suspend()
    }

    func ownsSendFormPresentation(_ identifier: UUID) -> Bool {
        formScope.ownsPresentation(identifier)
    }
}
