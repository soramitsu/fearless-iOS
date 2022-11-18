import Foundation
import SoraFoundation
import BigInt
import FearlessUtils

final class SendPresenter {
    // MARK: Private properties

    private weak var view: SendViewInput?
    private let router: SendRouterInput
    private let interactor: SendInteractorInput
    private let dataValidatingFactory: BaseDataValidatingFactoryProtocol
    private let logger: LoggerProtocol?
    private let wallet: MetaAccountModel
    private let qrParser: QRParser
    private let viewModelFactory: SendViewModelFactoryProtocol
    private let initialData: SendFlowInitialData

    private weak var moduleOutput: SendModuleOutput?

    private var recipientAddress: String?
    private var selectedChainAsset: ChainAsset?
    private var selectedAsset: AssetModel?
    private var totalBalanceValue: BigUInt?
    private var balance: Decimal?
    private var priceData: PriceData?
    private var tip: Decimal?
    private var fee: Decimal?
    private var minimumBalance: BigUInt?
    private var inputResult: AmountInputResult?
    private var balanceMinusFeeAndTip: Decimal { (balance ?? 0) - (fee ?? 0) - (tip ?? 0) }
    private var scamInfo: ScamInfo?

    // MARK: - Constructors

    init(
        interactor: SendInteractorInput,
        router: SendRouterInput,
        localizationManager: LocalizationManagerProtocol,
        viewModelFactory: SendViewModelFactoryProtocol,
        dataValidatingFactory: BaseDataValidatingFactoryProtocol,
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
            provideNetworkViewModel(for: chainAsset.chain)
            provideInputViewModel()
            refreshFee(for: chainAsset, address: nil)
        case let .address(address):
            recipientAddress = address
            router.showSelectAsset(
                from: view,
                wallet: wallet,
                selectedAssetId: nil,
                output: self
            )
        }
    }

    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))
        provideAssetVewModel()
        provideInputViewModel()
        guard let chainAsset = selectedChainAsset, let address = recipientAddress else { return }
        refreshFee(for: chainAsset, address: address)
    }

    func updateAmount(_ newValue: Decimal) {
        inputResult = .absolute(newValue)
        provideAssetVewModel()
        guard let chainAsset = selectedChainAsset, let address = recipientAddress else { return }
        if interactor.validate(address: address, for: chainAsset.chain) {
            refreshFee(for: chainAsset, address: address)
        }
    }

    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapContinueButton() {
        guard let chainAsset = selectedChainAsset else { return }
        guard let address = recipientAddress,
              interactor.validate(address: address, for: chainAsset.chain)
        else {
            router.present(message: nil, title: "Incorrect address", closeAction: "Close", from: view)
            return
        }
        let sendAmountDecimal = inputResult?.absoluteValue(from: balanceMinusFeeAndTip)
        let sendAmountValue = sendAmountDecimal?.toSubstrateAmount(precision: Int16(chainAsset.asset.precision))
        let spendingValue = (sendAmountValue ?? 0) +
            (fee?.toSubstrateAmount(precision: Int16(chainAsset.asset.precision)) ?? 0)

        DataValidationRunner(validators: [
            dataValidatingFactory.has(fee: fee, locale: selectedLocale, onError: { [weak self] in
                self?.refreshFee(for: chainAsset, address: address)
            }),

            dataValidatingFactory.canPayFeeAndAmount(
                balance: balance,
                fee: fee,
                spendingAmount: sendAmountDecimal,
                locale: selectedLocale
            ),

            dataValidatingFactory.exsitentialDepositIsNotViolated(
                spendingAmount: spendingValue,
                totalAmount: totalBalanceValue,
                minimumBalance: minimumBalance,
                locale: selectedLocale,
                chainAsset: chainAsset
            )

        ]).runValidation { [weak self] in
            guard let strongSelf = self, let amount = sendAmountDecimal else { return }
            strongSelf.router.presentConfirm(
                from: strongSelf.view,
                chainAsset: chainAsset,
                receiverAddress: address,
                amount: amount,
                tip: strongSelf.tip,
                scamInfo: strongSelf.scamInfo
            )
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
        view?.didReceive(scamInfo: scamInfo)
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            guard let chainAsset = selectedChainAsset else { return }
            totalBalanceValue = accountInfo?.data.total ?? 0

            balance = accountInfo.map {
                Decimal.fromSubstrateAmount(
                    $0.data.available,
                    precision: Int16(chainAsset.asset.precision)
                )
            } ?? 0.0

            provideAssetVewModel()
        case let .failure(error):
            logger?.error("Did receive account info error: \(error)")
        }
    }

    func didReceiveMinimumBalance(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(minimumBalance):
            self.minimumBalance = minimumBalance
        case let .failure(error):
            logger?.error("Did receive minimum balance error: \(error)")
        }
    }

    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            guard let chainAsset = selectedChainAsset else { return }
            self.priceData = priceData
            provideAssetVewModel()
            provideFeeViewModel()
            provideTipViewModel(for: chainAsset)
        case let .failure(error):
            logger?.error("Did receive price error: \(error)")
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        view?.didStopFeeCalculation()
        switch result {
        case let .success(dispatchInfo):
            guard let chainAsset = selectedChainAsset else { return }
            fee = BigUInt(dispatchInfo.fee).map {
                Decimal.fromSubstrateAmount($0, precision: Int16(chainAsset.asset.precision))
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

            provideTipViewModel(for: chainAsset)
            refreshFee(for: chainAsset, address: address)
        case let .failure(error):
            logger?.error("Did receive tip error: \(error)")
            // Even though no tip received, let's refresh fee, because we didn't load it at start
            guard let chainAsset = selectedChainAsset, let address = recipientAddress else { return }
            refreshFee(for: chainAsset, address: address)
        }
    }
}

extension SendPresenter: ScanQRModuleOutput {
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
    func assetSelection(didCompleteWith asset: AssetModel?) {
        selectedAsset = asset
        if let asset = asset {
            interactor.defineAvailableChains(for: asset) { [weak self] chains in
                if let availableChains = chains, let strongSelf = self {
                    strongSelf.router.showSelectNetwork(
                        from: strongSelf.view,
                        wallet: strongSelf.wallet,
                        selectedChainId: strongSelf.selectedChainAsset?.chain.chainId,
                        chainModels: availableChains,
                        delegate: strongSelf
                    )
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
        didCompleteWith chain: ChainModel?
    ) {
        let optionalAsset: AssetModel? = selectedAsset ?? selectedChainAsset?.asset
        if
            let selectedChain = chain,
            let selectedAsset = optionalAsset,
            let selectedChainAsset = selectedChain.chainAssets.first(where: { $0.asset.name == selectedAsset.name }) {
            self.selectedChainAsset = selectedChainAsset
            provideNetworkViewModel(for: selectedChain)
            provideAssetVewModel()
            if let recipientAddress = recipientAddress {
                handle(newAddress: recipientAddress)
            }
            interactor.updateSubscriptions(for: selectedChainAsset)
        } else if selectedChainAsset == nil {
            router.dismiss(view: view)
        }
    }
}

private extension SendPresenter {
    func provideAssetVewModel() {
        guard let chainAsset = selectedChainAsset,
              let balanceViewModelFactory = interactor
              .dependencyContainer
              .prepareDepencies(chainAsset: chainAsset)?
              .balanceViewModelFactory
        else { return }
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFeeAndTip) ?? 0.0

        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount,
            balance: balance,
            priceData: priceData
        ).value(for: selectedLocale)
        view?.didReceive(assetBalanceViewModel: viewModel)
    }

    func provideTipViewModel(for chainAsset: ChainAsset) {
        guard let chainAsset = selectedChainAsset,
              let balanceViewModelFactory = interactor
              .dependencyContainer
              .prepareDepencies(chainAsset: chainAsset)?
              .balanceViewModelFactory
        else { return }
        let viewModel = tip
            .map { balanceViewModelFactory.balanceFromPrice($0, priceData: priceData) }?
            .value(for: selectedLocale)
        let tipViewModel = TipViewModel(
            balanceViewModel: viewModel,
            tipRequired: chainAsset.chain.isTipRequired
        )
        view?.didReceive(tipViewModel: tipViewModel)
    }

    func provideFeeViewModel() {
        guard let chainAsset = selectedChainAsset,
              let balanceViewModelFactory = interactor
              .dependencyContainer
              .prepareDepencies(chainAsset: chainAsset)?
              .balanceViewModelFactory
        else { return }
        let viewModel = fee
            .map { balanceViewModelFactory.balanceFromPrice($0, priceData: priceData) }?
            .value(for: selectedLocale)
        view?.didReceive(feeViewModel: viewModel)
    }

    func provideInputViewModel() {
        guard let chainAsset = selectedChainAsset,
              let balanceViewModelFactory = interactor
              .dependencyContainer
              .prepareDepencies(chainAsset: chainAsset)?
              .balanceViewModelFactory
        else { return }
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFeeAndTip)

        let inputViewModel = balanceViewModelFactory.createBalanceInputViewModel(inputAmount)
            .value(for: selectedLocale)
        view?.didReceive(amountInputViewModel: inputViewModel)
    }

    func provideNetworkViewModel(for chain: ChainModel) {
        let viewModel = viewModelFactory.buildNetworkViewModel(chain: chain)
        view?.didReceive(selectNetworkViewModel: viewModel)
    }

    func refreshFee(for chainAsset: ChainAsset, address: String?) {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFeeAndTip) ?? 0
        guard let amount = inputAmount.toSubstrateAmount(
            precision: Int16(chainAsset.asset.precision)
        ) else {
            return
        }

        view?.didStartFeeCalculation()

        let tip = self.tip?.toSubstrateAmount(precision: Int16(chainAsset.asset.precision))
        interactor.estimateFee(for: amount, tip: tip, for: address, chainAsset: chainAsset)
    }

    func handle(newAddress: String) {
        recipientAddress = newAddress
        guard let chainAsset = selectedChainAsset else { return }
        let addressIsValid = interactor.validate(address: newAddress, for: chainAsset.chain)
        let viewModel = viewModelFactory.buildRecipientViewModel(
            address: newAddress,
            isValid: addressIsValid
        )
        view?.didReceive(viewModel: viewModel)

        if addressIsValid {
            interactor.updateSubscriptions(for: chainAsset)
            interactor.fetchScamInfo(for: newAddress)
            refreshFee(for: chainAsset, address: newAddress)
        }
    }
}

// MARK: - Localizable

extension SendPresenter: Localizable {
    func applyLocalization() {}
}
