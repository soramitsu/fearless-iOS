import Foundation
import SSFQRService
import SoraFoundation
import SSFModels
import BigInt
import SSFTransferService

@MainActor
protocol TransferViewInput: ControllerBackedProtocol {
    func didReceive(recipientViewModel: RecipientViewModel?)
    func didReceive(assetBalanceViewModel: AssetBalanceViewModelProtocol?)
    func didReceive(amountInputViewModel: IAmountInputViewModel?)
    func didReceive(selectNetworkViewModel: SelectNetworkViewModel)
    func didReceive(feeViewModel: BalanceViewModelProtocol?)
    func didReceive(tipViewModel: TipViewModel?)
    func setHistoryButton(isVisible: Bool)
    func switchEnableSendAllVisibility(isVisible: Bool)
    func didBlockUserInteractive(isUserInteractiveAmount: Bool)
    func setInputAccessoryView(visible: Bool)
    func didReceiveContinueButton(isReady: Bool)
    func didReceive(scamInfo: ScamInfo?)
    func setCommentInput(isVisible: Bool)
    func setCommentViewModel(_ viewModel: InputViewModelProtocol?)
}

protocol TransferInteractorInput: AnyObject {
    func setup(with output: TransferInteractorOutput) async
    func getPossibleChains(for address: String) async -> [ChainModel]
    func validate(address: String?, for chain: ChainModel) async -> AddressValidationResult
    func fetchTokenStatus(for chainAsset: ChainAsset) async throws -> AssetAccountInfo?
    func fetchAccountInfos(for chainAsset: ChainAsset) async throws -> [ChainAssetKey: AccountInfo?]
    func fetchExistentialDeposit(for chainAsset: ChainAsset) async throws -> BigUInt
    func fetchTip(for chainAsset: ChainAsset) async throws -> BigUInt
    func convert(
        chainAsset: ChainAsset,
        toChainAsset: ChainAsset,
        amount: BigUInt
    ) async throws -> SwapValues?
    func defineAvailableChains(
        for asset: AssetModel,
        wallet: MetaAccountModel
    ) async throws -> [ChainModel]?
    func estimateFee(
        transfer: TransferType,
        chainAsset: ChainAsset
    ) async -> AsyncThrowingStream<BigUInt, Error>
    func submit(
        transfer: TransferType,
        chainAsset: ChainAsset
    ) async throws -> String?
    func getScamInfo(for address: String) async throws -> ScamInfo?
}

final class TransferPresenter {
    // MARK: Private properties

    private weak var view: TransferViewInput?
    private let router: TransferRouterInput
    private let interactor: TransferInteractorInput
    private let viewModelFactory: SendViewModelFactoryProtocol
    private let logger: LoggerProtocol

    private let wallet: MetaAccountModel
    private let possibleFlows: [TransferFlowUseCase]

    // MARK: - Common state

    private var currentFlowUseCase: TransferFlowUseCase?
    private var sendFlow: SendFlowInitialData
    private var scamInfo: ScamInfo?

    // MARK: - Constructors

    init(
        wallet: MetaAccountModel,
        initialData: SendFlowInitialData,
        viewModelFactory: SendViewModelFactoryProtocol,
        possibleFlows: [TransferFlowUseCase],
        interactor: TransferInteractorInput,
        router: TransferRouterInput,
        logger: LoggerProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wallet = wallet
        sendFlow = initialData
        self.viewModelFactory = viewModelFactory
        self.possibleFlows = possibleFlows
        self.interactor = interactor
        self.router = router
        self.logger = logger
        self.localizationManager = localizationManager
    }

    // MARK: - Private provides methids

    private func provideRecipientViewModel() async {
        guard
            let currentFlowUseCase,
            let address = currentFlowUseCase.recipientAddress
        else {
            await view?.didReceive(recipientViewModel: nil)
            return
        }
        let viewModel = viewModelFactory.buildRecipientViewModel(
            address: address,
            isValid: currentFlowUseCase.isValidRecipient,
            canEditing: currentFlowUseCase.canEditRecipient
        )
        await view?.didReceive(recipientViewModel: viewModel)
        await provideScamInfo()
    }

    private func provideScamInfo() async {
        guard let address = currentFlowUseCase?.recipientAddress else {
            return
        }
        do {
            let scamInfo = try await interactor.getScamInfo(for: address)
            await view?.didReceive(scamInfo: scamInfo)
            self.scamInfo = scamInfo
        } catch {
            logger.customError(error)
        }
    }

    private func provideAssetVewModel() async {
        guard
            let currentFlowUseCase,
            let selectedChainAsset = currentFlowUseCase.selectedChainAsset
        else {
            return
        }

        let availableInputBalance = currentFlowUseCase.availableInputBalance ?? .zero
        let canSelectAsset = currentFlowUseCase.canSelectAsset
        let inputAmount = currentFlowUseCase.inputResult?.absoluteValue(from: availableInputBalance)
        let availableBalance = currentFlowUseCase.availableBalance

        let viewModel = viewModelFactory.createAssetBalanceViewModel(
            inputAmount: inputAmount,
            availableBalance: availableBalance,
            chainAsset: selectedChainAsset,
            canSelectAsset: canSelectAsset,
            locale: selectedLocale
        )
        await view?.didReceive(assetBalanceViewModel: viewModel)

        let isVisible = currentFlowUseCase.isSwitchEnableSendAllVisibility
        await view?.switchEnableSendAllVisibility(isVisible: isVisible)
    }

    private func provideInputViewModel() async {
        guard
            let currentFlowUseCase,
            let chainAsset = currentFlowUseCase.selectedChainAsset
        else {
            await view?.didReceive(amountInputViewModel: nil)
            return
        }

        let availableInputBalance = currentFlowUseCase.availableInputBalance ?? .zero
        let inputAmount = currentFlowUseCase.inputResult?.absoluteValue(from: availableInputBalance)

        let inputViewModel = viewModelFactory.createBalanceInputViewModel(
            inputAmount: inputAmount,
            chainAsset: chainAsset,
            locale: selectedLocale
        )

        let isVisible = chainAsset.chain.externalApi?.history != nil
        await view?.setHistoryButton(isVisible: isVisible)
        await view?.didReceive(amountInputViewModel: inputViewModel)

        let isUserInteractiveAmount = currentFlowUseCase.isUserInteractiveAmount
        await view?.didBlockUserInteractive(isUserInteractiveAmount: isUserInteractiveAmount)
    }

    private func provideNetworkViewModel() async {
        guard let currentFlowUseCase else {
            return
        }

        switch currentFlowUseCase.implType {
        case .substrate, .ethereum, .soraMainnetQr, .ton:
            guard let chain = currentFlowUseCase.selectedChainAsset?.chain else {
                return
            }
            let viewModel = viewModelFactory.buildNetworkViewModel(
                chain: chain
            )
            await view?.didReceive(selectNetworkViewModel: viewModel)
        case .bokoloCash:
            let networkViewModel = SelectNetworkViewModel(
                chainName: "Bokolo cash",
                iconViewModel: BundleImageViewModel(image: R.image.bokolocash())
            )
            await view?.didReceive(selectNetworkViewModel: networkViewModel)
        }

        let isVisibleComment = currentFlowUseCase.implType == .ton
        await view?.setCommentInput(isVisible: isVisibleComment)
        await provideCommentInputViewModel()
    }

    private func provideCommentInputViewModel() async {
        guard (currentFlowUseCase?.implType == .ton) == true else {
            await view?.setCommentViewModel(nil)
            return
        }

        let comment = currentFlowUseCase?.comment ?? ""
        let viewModel = InputViewModel(inputHandler: InputHandler(value: comment))
        await view?.setCommentViewModel(viewModel)
    }

    private func provideFeeViewModel() async {
        guard
            let currentFlowUseCase,
            let chainAsset = currentFlowUseCase.utilityChainAsset,
            let fee = currentFlowUseCase.fee
        else {
            await view?.didReceive(feeViewModel: nil)
            return
        }

        let viewModel = viewModelFactory.balanceFromPrice(
            chainAsset: chainAsset,
            balance: fee,
            locale: selectedLocale
        )

        await view?.didReceive(feeViewModel: viewModel)
    }

    private func provideTipViewModel() async {
        guard
            let currentFlowUseCase,
            let chainAsset = currentFlowUseCase.utilityChainAsset,
            let tip = currentFlowUseCase.tip
        else {
            await view?.didReceive(tipViewModel: nil)
            return
        }

        let balanceViewModel = viewModelFactory.balanceFromPrice(
            chainAsset: chainAsset,
            balance: tip,
            locale: selectedLocale
        )

        let tipViewModel = TipViewModel(
            balanceViewModel: balanceViewModel,
            tipRequired: chainAsset.chain.isTipRequired
        )

        await view?.didReceive(tipViewModel: tipViewModel)
    }

    private func provideIsReady() async {
        let isReady = currentFlowUseCase?.isReadyToContinue() == true
        await view?.didReceiveContinueButton(isReady: isReady)
    }

    private func provideInputAccessoryView() async {
        guard let selectedChainAsset = currentFlowUseCase?.selectedChainAsset else {
            return
        }
        let isVisibleInputAccessory = selectedChainAsset.isBokolo == false
        await view?.setInputAccessoryView(visible: isVisibleInputAccessory)
    }

    // MARK: - Private methods

    private func handleSendFlow(address: String?) async {
        await possibleFlows.asyncForEach { await $0.reset() }

        do {
            switch sendFlow {
            case let .chainAsset(chainAsset):
                await setCurrentFlow(for: chainAsset.chain.ecosystem)
                currentFlowUseCase?.recipientAddress = address
                try await currentFlowUseCase?.handle(initialData: sendFlow)
            case let .address(address):
                let possibleChains = await interactor.getPossibleChains(for: address)
                guard possibleChains.isNotEmpty else {
                    await showIncorrectAddressAlert()
                    return
                }
                await handle(possibleChains: possibleChains)
            case .soraMainnet:
                setCurrentFlow(for: .soraMainnetQr)
                try await currentFlowUseCase?.handle(initialData: sendFlow)
            case .bokoloCash:
                setCurrentFlow(for: .bokoloCash)
                try await currentFlowUseCase?.handle(initialData: sendFlow)
            case let .desiredCryptocurrency(qrInfo: qrInfo):
                try await handleDesiredCrypto(qrInfo: qrInfo)
            }
        } catch {
            if let error = error as? TransferFlowUseCaseError {
                switch error {
                case .unsupportedAsset:
                    await showUnsupportedAssetAlert()
                default:
                    logger.customError(error)
                }
            } else {
                logger.customError(error)
            }
        }

        await provideInputAccessoryView()
    }

    private func setCurrentFlow(for ecosystem: Ecosystem) async {
        switch ecosystem {
        case .substrate, .ethereumBased:
            guard let flow = possibleFlows.first(where: { $0.implType == .substrate }) else {
                return
            }
            currentFlowUseCase = flow
        case .ethereum:
            guard let flow = possibleFlows.first(where: { $0.implType == .ethereum }) else {
                return
            }
            currentFlowUseCase = flow
        case .ton:
            guard let flow = possibleFlows.first(where: { $0.implType == .ton }) else {
                return
            }
            currentFlowUseCase = flow
        }
        setupBindings()
    }

    private func setCurrentFlow(for implType: TransferFlowDirectionImpl) {
        guard let flow = possibleFlows.first(where: { $0.implType == implType }) else {
            return
        }
        currentFlowUseCase = flow
        setupBindings()
    }

    private func handle(possibleChains: [ChainModel]) async {
        guard possibleChains.isNotEmpty else {
            await router.showSelectAsset(
                from: view,
                wallet: wallet,
                selectedAssetId: nil,
                chainAssets: nil,
                output: self
            )
            return
        }
        if possibleChains.count == 1, let selectedChain = possibleChains.first {
            await defineOrSelectAsset(for: selectedChain)
        } else {
            await router.showSelectNetwork(
                from: view,
                wallet: wallet,
                selectedChainId: nil,
                chainModels: possibleChains,
                delegate: self
            )
        }
    }

    private func defineOrSelectAsset(for chain: ChainModel) async {
        await setCurrentFlow(for: chain.ecosystem)
        let chainAssets = enabled(
            chainAssets: chain.chainAssets,
            for: wallet
        )
        if chainAssets.count == 1,
           let selectedChainAsset = chainAssets.first {
            let address = sendFlow.address
            sendFlow = .chainAsset(selectedChainAsset)
            await handleSendFlow(address: address)
        } else {
            await router.showSelectAsset(
                from: view,
                wallet: wallet,
                selectedAssetId: nil,
                chainAssets: chainAssets,
                output: self
            )
        }
    }

    private func enabled(
        chainAssets: [ChainAsset],
        for wallet: MetaAccountModel
    ) -> [ChainAsset] {
        let enabledAssetIds: [String] = wallet.assetsVisibility
            .filter { !$0.hidden }
            .map { $0.assetId }
        let enabled = chainAssets.filter {
            enabledAssetIds.contains($0.identifier)
        }
        return enabled
    }

    private func setupBindings() {
        currentFlowUseCase?.provideRecipientViewModel = { [weak self] in
            Task { [weak self] in
                await self?.provideRecipientViewModel()
                await self?.provideIsReady()
            }
        }
        currentFlowUseCase?.provideAssetViewModel = { [weak self] in
            Task { [weak self] in
                await self?.provideAssetVewModel()
                await self?.provideIsReady()
            }
        }
        currentFlowUseCase?.provideInputViewModel = { [weak self] in
            Task { [weak self] in
                await self?.provideInputViewModel()
                await self?.provideIsReady()
            }
        }
        currentFlowUseCase?.provideNetworkViewModel = { [weak self] in
            Task { [weak self] in
                await self?.provideNetworkViewModel()
            }
        }
        currentFlowUseCase?.provideTipViewModel = { [weak self] in
            Task { [weak self] in
                await self?.provideTipViewModel()
            }
        }
        currentFlowUseCase?.provideFeeViewModel = { [weak self] in
            Task { [weak self] in
                await self?.provideFeeViewModel()
            }
        }
    }

    private func validateInputData() async {
        guard
            let currentFlowUseCase,
            let selectedChainAsset = currentFlowUseCase.selectedChainAsset
        else {
            return
        }
        await validateAddress(with: selectedChainAsset) { [weak self] in
            guard let self else { return }
            do {
                let validators = try currentFlowUseCase.getValidators(
                    validationCase: .all,
                    locale: self.selectedLocale
                )
                Task { @MainActor in
                    DataValidationRunner(validators: validators).runValidation { [weak self] in
                        self?.showConfirm()
                    }
                }
            } catch {
                logger.customError(error)
            }
        }
    }

    private func validateAddress(
        with chainAsset: ChainAsset,
        successCompletion: @escaping () -> Void
    ) async {
        switch currentFlowUseCase?.implType {
        case .bokoloCash:
            successCompletion()
        default:
            guard let recipientAddress = currentFlowUseCase?.recipientAddress else {
                return
            }
            let validationResult = await interactor.validate(address: recipientAddress, for: chainAsset.chain)
            switch validationResult {
            case .valid:
                successCompletion()
            case let .invalid(address):
                guard let address = address else {
                    await showInvalidAddressAlert()
                    return
                }
                let possibleChains = await interactor.getPossibleChains(for: address)
                guard possibleChains.isNotEmpty else {
                    await showInvalidAddressAlert()
                    return
                }

                await showPossibleChainsAlert(possibleChains)
            case .sameAddress:
                await showSameAddressAlert(successCompletion: successCompletion)
            }
        }
    }

    private func showConfirm() {
        Task { @MainActor in
            guard
                let useCase = currentFlowUseCase,
                let chainAsset = useCase.selectedChainAsset
            else {
                return
            }
            router.presentConfirm(
                from: view,
                wallet: wallet,
                chainAsset: chainAsset,
                useCase: useCase,
                sendFlow: sendFlow,
                scamInfo: scamInfo
            )
        }
    }

    // MARK: - Alerts

    @MainActor
    private func showSameAddressAlert(successCompletion: @escaping () -> Void) {
        let action = SheetAlertPresentableAction(
            title: R.string.localizable.commonProceed(preferredLanguages: selectedLocale.rLanguages)
        ) {
            successCompletion()
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

    @MainActor
    private func showInvalidAddressAlert() {
        router.present(
            message: R.string.localizable.errorInvalidAddress(preferredLanguages: selectedLocale.rLanguages),
            title: R.string.localizable.commonWarning(preferredLanguages: selectedLocale.rLanguages),
            closeAction: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages),
            from: view
        )
    }

    @MainActor
    private func showPossibleChainsAlert(_ possibleChains: [ChainModel]) async {
        let action = SheetAlertPresentableAction(
            title: R.string.localizable.commonSelectNetwork(preferredLanguages: selectedLocale.rLanguages)
        ) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.router.showSelectNetwork(
                    from: self.view,
                    wallet: self.wallet,
                    selectedChainId: nil,
                    chainModels: possibleChains,
                    delegate: self
                )
            }
        }
        router.present(
            message: R.string.localizable.errorInvalidAddress(preferredLanguages: selectedLocale.rLanguages),
            title: R.string.localizable.commonWarning(preferredLanguages: selectedLocale.rLanguages),
            closeAction: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages),
            from: view,
            actions: [action]
        )
    }

    @MainActor
    private func showIncorrectAddressAlert() async {
        let dissmissAction = SheetAlertPresentableAction(
            title: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages)
        ) { [weak self, view] in
            self?.router.dismiss(view: view)
        }
        let alertViewModel = SheetAlertPresentableViewModel(
            title: R.string.localizable.commonWarning(preferredLanguages: selectedLocale.rLanguages),
            message: R.string.localizable.errorInvalidAddress(preferredLanguages: selectedLocale.rLanguages),
            actions: [dissmissAction],
            closeAction: nil,
            dismissCompletion: { [weak self, view] in
                self?.router.dismiss(view: view)
            }
        )
        await MainActor.run { [view] in
            router.present(viewModel: alertViewModel, from: view)
        }
    }

    @MainActor
    private func showUnsupportedAssetAlert() async {
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
            Task { @MainActor in
                self.router.showManageAsset(from: self.view, wallet: self.wallet)
            }
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
}

// MARK: - TransferViewOutput

extension TransferPresenter: TransferViewOutput {
    func updateComment(_ text: String?) {
        currentFlowUseCase?.comment = text
        Task { await provideCommentInputViewModel() }
    }

    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapContinueButton() {
        Task { await validateInputData() }
    }

    @MainActor
    func didTapScanButton() {
        router.presentScan(from: view, moduleOutput: self)
    }

    @MainActor
    func didTapHistoryButton() {
        guard let chainAsset = currentFlowUseCase?.selectedChainAsset else { return }
        router.presentHistory(from: view, wallet: wallet, chainAsset: chainAsset, moduleOutput: self)
    }

    func didTapPasteButton() {
        Task {
            if let address = UIPasteboard.general.string {
                await currentFlowUseCase?.handleRecipient(address: address)
            }
        }
    }

    @MainActor
    func didTapSelectAsset() {
        let selectedAssetId = currentFlowUseCase?.selectedChainAsset?.asset.id
        router.showSelectAsset(
            from: view,
            wallet: wallet,
            selectedAssetId: selectedAssetId,
            chainAssets: nil,
            output: self
        )
    }

    func searchTextDidChanged(_ text: String) {
        Task {
            await currentFlowUseCase?.handleRecipient(address: text)
        }
    }

    func selectAmountPercentage(_ percentage: Float, validate: Bool = true) {
        currentFlowUseCase?.inputResult = .rate(Decimal(Double(percentage)))

        if validate {
            do {
                let validators = try currentFlowUseCase?.getValidators(
                    validationCase: .validateED,
                    locale: selectedLocale
                ) ?? []
                DataValidationRunner(validators: validators).runValidation {
                    Task { [weak self] in
                        self?.currentFlowUseCase?.inputResult = .rate(Decimal(Double(percentage)))
                        await self?.provideAssetVewModel()
                        await self?.provideInputViewModel()
                    }
                }
            } catch {
                logger.customError(error)
            }
        } else {
            Task {
                await provideAssetVewModel()
                await provideInputViewModel()
            }
        }

        Task { await provideIsReady() }

        guard let transfer = currentFlowUseCase?.getTransfer() else {
            return
        }
        currentFlowUseCase?.refreshFee(for: transfer)
    }

    func updateAmount(_ newValue: Decimal) {
        currentFlowUseCase?.inputResult = .absolute(newValue)

        do {
            let validators = try currentFlowUseCase?.getValidators(
                validationCase: .validateED,
                locale: selectedLocale
            ) ?? []
            DataValidationRunner(validators: validators).runValidation {
                Task { [weak self] in
                    await self?.provideAssetVewModel()
                }
            }
        } catch {
            logger.customError(error)
        }

        Task {
            await provideIsReady()
        }

        guard let transfer = currentFlowUseCase?.getTransfer() else {
            return
        }
        currentFlowUseCase?.refreshFee(for: transfer)
    }

    func didSwitchSendAll(_ enabled: Bool) {
        currentFlowUseCase?.sendAllEnabled = enabled
        selectAmountPercentage(Float(enabled.intValue), validate: false)
    }

    func didLoad(view: TransferViewInput) {
        self.view = view
        Task {
            await interactor.setup(with: self)
            await handleSendFlow(address: nil)
        }
    }

    private func handleDesiredCrypto(qrInfo: DesiredCryptocurrencyQRInfo) async throws {
        let possibleChains = await interactor.getPossibleChains(for: qrInfo.address)
        let chainAsset = possibleChains
            .first(where: { $0.name.lowercased() == qrInfo.assetName.lowercased() })?
            .chainAssets
            .first(where: { $0.asset.isUtility })

        guard let chainAsset else {
            await showUnsupportedAssetAlert()
            return
        }

        await setCurrentFlow(for: chainAsset.chain.ecosystem)
        currentFlowUseCase?.recipientAddress = qrInfo.address
        currentFlowUseCase?.isValidRecipient = true
        currentFlowUseCase?.canEditRecipient = false

        if let qrAmount = Decimal(string: qrInfo.amount ?? "") {
            currentFlowUseCase?.inputResult = .absolute(qrAmount)
            currentFlowUseCase?.isUserInteractiveAmount = false
        }

        try await currentFlowUseCase?.handle(initialData: .chainAsset(chainAsset /* , address: qrInfo.address */ ))
    }
}

// MARK: - TransferInteractorOutput

extension TransferPresenter: TransferInteractorOutput {}

// MARK: - TransferModuleInput

extension TransferPresenter: TransferModuleInput {}

// MARK: - SelectAssetModuleOutput

extension TransferPresenter: SelectAssetModuleOutput {
    nonisolated func assetSelection(
        didCompleteWith chainAsset: ChainAsset?,
        contextTag _: Int?
    ) {
        guard let chainAsset else {
            return
        }
        let address = sendFlow.address
        sendFlow = .chainAsset(chainAsset)
        Task { await handleSendFlow(address: address) }
    }
}

// MARK: - SelectNetworkDelegate

extension TransferPresenter: SelectNetworkDelegate {
    nonisolated func chainSelection(
        view _: any SelectNetworkViewInput,
        didCompleteWith chain: ChainModel?,
        contextTag _: Int?
    ) {
        Task {
            await handle(possibleChains: [chain].compactMap { $0 })
        }
    }
}

// MARK: - ScanQRModuleOutput

extension TransferPresenter: ScanQRModuleOutput {
    func didFinishWith(scanType: QRMatcherType) {
        guard let qrInfo = scanType.qrInfo else {
            return
        }

        sendFlow = SendFlowInitialData(qrInfoType: qrInfo)
        Task { await handleSendFlow(address: nil) }
    }
}

// MARK: - ContactsModuleOutput

extension TransferPresenter: ContactsModuleOutput {
    func didSelect(address: String) {
        searchTextDidChanged(address)
    }
}

// MARK: - Localizable

extension TransferPresenter: Localizable {
    nonisolated func applyLocalization() {}
}
