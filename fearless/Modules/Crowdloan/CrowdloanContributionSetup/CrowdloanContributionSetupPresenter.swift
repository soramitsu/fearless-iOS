import Foundation
import BigInt
import SoraFoundation
import SoraUI
import CommonWallet

class CrowdloanContributionSetupPresenter {
    weak var view: CrowdloanContributionSetupViewProtocol?
    let wireframe: CrowdloanContributionSetupWireframeProtocol
    let interactor: CrowdloanContributionSetupInteractorInputProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let contributionViewModelFactory: CrowdloanContributionViewModelFactoryProtocol
    let dataValidatingFactory: CrowdloanDataValidatorFactoryProtocol
    let chain: Chain
    let logger: LoggerProtocol?
    let customFlow: CustomCrowdloanFlow?

    private var crowdloan: Crowdloan?
    private var displayInfo: CrowdloanDisplayInfo?
    private var totalBalanceValue: BigUInt?
    private var balance: Decimal?
    private var priceData: PriceData?
    private var fee: Decimal?
    private var blockNumber: BlockNumber?
    private var blockDuration: BlockTime?
    private var leasingPeriod: LeasingPeriod?
    private var minimumBalance: BigUInt?
    private var minimumContribution: BigUInt?
    private var previousContribution: CrowdloanContribution?

    private var bonusService: CrowdloanBonusServiceProtocol?
    private var balanceMinusFee: Decimal { (balance ?? 0) - (fee ?? 0) }

    private var crowdloanMetadata: CrowdloanMetadata? {
        if
            let blockNumber = blockNumber,
            let blockDuration = blockDuration,
            let leasingPeriod = leasingPeriod {
            return CrowdloanMetadata(
                blockNumber: blockNumber,
                blockDuration: blockDuration,
                leasingPeriod: leasingPeriod
            )
        } else {
            return nil
        }
    }

    private var inputResult: AmountInputResult?
    private var hasValidEthereumAddress: Bool = false
    private var ethereumAddress: String?

    init(
        interactor: CrowdloanContributionSetupInteractorInputProtocol,
        wireframe: CrowdloanContributionSetupWireframeProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        contributionViewModelFactory: CrowdloanContributionViewModelFactoryProtocol,
        dataValidatingFactory: CrowdloanDataValidatorFactoryProtocol,
        chain: Chain,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil,
        customFlow: CustomCrowdloanFlow?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.balanceViewModelFactory = balanceViewModelFactory
        self.contributionViewModelFactory = contributionViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.chain = chain
        self.logger = logger
        self.customFlow = customFlow
        self.localizationManager = localizationManager
    }

    private func provideAssetVewModel() -> AssetBalanceViewModelProtocol? {
        guard minimumBalance != nil, minimumContribution != nil, let inputAmount = getInputAmount() else {
            return nil
        }

        let assetViewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount,
            balance: balance,
            priceData: priceData
        ).value(for: selectedLocale)

        return assetViewModel
    }

    private func provideFeeViewModel() -> BalanceViewModelProtocol? {
        let feeViewModel = fee
            .map { balanceViewModelFactory.balanceFromPrice($0, priceData: priceData) }?
            .value(for: selectedLocale)

        return feeViewModel
    }

    @discardableResult
    private func provideInputViewModel() -> AmountInputViewModelProtocol {
        let inputViewModel = balanceViewModelFactory.createBalanceInputViewModel(getInputAmount())
            .value(for: selectedLocale)

        return inputViewModel
    }

    private func provideInputViewModelIfRate() {
        guard case .rate = inputResult else {
            return
        }

        provideInputViewModel()
    }

    private func provideEthereumAddressViewModel() {
        guard customFlow?.hasEthereumReferral == true else { return }

        let predicate = NSPredicate.ethereumAddress
        let inputHandling = InputHandler(value: ethereumAddress ?? "", predicate: predicate)
        let viewModel = InputViewModel(inputHandler: inputHandling, placeholder: "")
        view?.didReceiveEthereumAddress(viewModel: viewModel)

        if inputHandling.completed != hasValidEthereumAddress {
            refreshFee()
        }

        hasValidEthereumAddress = inputHandling.completed
    }

    private func provideCrowdloanContributionViewModel() -> CrowdloanContributionSetupViewModel {
        contributionViewModelFactory.createContributionSetupViewModel(
            from: crowdloan,
            displayInfo: displayInfo,
            metadata: crowdloanMetadata,
            locale: selectedLocale,
            assetBalance: provideAssetVewModel(),
            fee: provideFeeViewModel(),
            estimatedReward: provideEstimatedRewardViewModel(),
            bonus: provideBonusViewModel(),
            amountInput: provideInputViewModel(),
            previousContribution: previousContribution
        )
    }

    private func provideEstimatedRewardViewModel() -> String? {
        guard let inputAmount = getInputAmount() else {
            return nil
        }

        let viewModel = displayInfo.map {
            contributionViewModelFactory.createEstimatedRewardViewModel(
                inputAmount: inputAmount,
                displayInfo: $0,
                locale: selectedLocale
            )
        } ?? nil

        return viewModel
    }

    private func provideBonusViewModel() -> String? {
        guard let inputAmount = getInputAmount() else {
            return nil
        }

        let viewModel: String? = {
            if let displayInfo = displayInfo,
               displayInfo.flowIfSupported != nil,
               displayInfo.flowIfSupported?.hasReferralBonus == true {
                return contributionViewModelFactory.createAdditionalBonusViewModel(
                    inputAmount: inputAmount,
                    displayInfo: displayInfo,
                    bonusRate: bonusService?.bonusRate,
                    locale: selectedLocale
                )
            } else {
                return nil
            }
        }()

        return viewModel
    }

    private func provideViewModels() {
        let viewModel = provideCrowdloanContributionViewModel()
        view?.didReceiveState(state: .loadedDefaultFlow(viewModel))
    }

    private func provideEthereumAddressViewModel() -> InputViewModelProtocol? {
        guard case .moonbeam = customFlow else { return nil }

        let predicate = NSPredicate.ethereumAddress
        let inputHandling = InputHandler(value: ethereumAddress ?? "", predicate: predicate)
        let viewModel = InputViewModel(inputHandler: inputHandling, placeholder: "")

        if inputHandling.completed != hasValidEthereumAddress {
            refreshFee()
        }

        hasValidEthereumAddress = inputHandling.completed

        return viewModel
    }

    private func refreshFee() {
        let amount = getInputAmount()?.toSubstrateAmount(precision: chain.addressType.precision)

        interactor.estimateFee(
            for: amount,
            bonusService: bonusService,
            memo: nil
        )
    }

    private func getInputAmount() -> Decimal? {
        var inputAmount = inputResult?.absoluteValue(from: balanceMinusFee)

        if let customFlow = customFlow, !customFlow.needsContribute {
            inputAmount = nil
        } else {
            inputAmount = inputAmount ?? 0
        }

        return inputAmount
    }
}

extension CrowdloanContributionSetupPresenter: CrowdloanContributionSetupPresenterProtocol {
    func updateEthereumAddress(_ newValue: String) {
        ethereumAddress = newValue
        _ = provideEthereumAddressViewModel()
    }

    func setup() {
        switch customFlow {
        case let .moonbeamMemoFix(memo):
            ethereumAddress = memo
        default: break
        }

        provideViewModels()

        interactor.setup()

        refreshFee()
    }

    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))

        provideViewModels()

        refreshFee()
    }

    func updateAmount(_ newValue: Decimal) {
        inputResult = .absolute(newValue)

        refreshFee()
        provideViewModels()
    }

    func proceed() {
        let contributionDecimal = inputResult?.absoluteValue(from: balanceMinusFee)
        let contributionValue = contributionDecimal?.toSubstrateAmount(precision: chain.addressType.precision)
        let spendingValue = (contributionValue == nil) ? nil : (contributionValue ?? 0) +
            (fee?.toSubstrateAmount(precision: chain.addressType.precision) ?? 0)

        let needsMinContributionValidation = customFlow.map {
            switch $0 {
            case .moonbeamMemoFix: return false
            default: return true
            }
        } ?? true

        DataValidationRunner(validators: [
            //            dataValidatingFactory.crowdloanIsNotPrivate(crowdloan: crowdloan, locale: selectedLocale),

            dataValidatingFactory.has(fee: fee, locale: selectedLocale, onError: { [weak self] in
                self?.refreshFee()
            }),

            dataValidatingFactory.canPayFeeAndAmount(
                balance: balance,
                fee: fee,
                spendingAmount: contributionDecimal,
                locale: selectedLocale
            ),

            needsMinContributionValidation ? dataValidatingFactory.contributesAtLeastMinContribution(
                contribution: contributionValue,
                minimumBalance: minimumContribution,
                locale: selectedLocale
            ) : nil,

            dataValidatingFactory.capNotExceeding(
                contribution: contributionValue,
                raised: crowdloan?.fundInfo.raised,
                cap: crowdloan?.fundInfo.cap,
                locale: selectedLocale
            ),

            dataValidatingFactory.crowdloanIsNotCompleted(
                crowdloan: crowdloan,
                metadata: crowdloanMetadata,
                locale: selectedLocale
            ),

            dataValidatingFactory.exsitentialDepositIsNotViolated(
                spendingAmount: spendingValue,
                totalAmount: totalBalanceValue,
                minimumBalance: minimumBalance,
                locale: selectedLocale
            )

        ].compactMap { $0 }).runValidation { [weak self] in
            guard let strongSelf = self,
                  let paraId = strongSelf.crowdloan?.paraId else { return }
            strongSelf.wireframe.showConfirmation(
                from: strongSelf.view,
                paraId: paraId,
                inputAmount: contributionDecimal,
                bonusService: strongSelf.bonusService,
                customFlow: strongSelf.customFlow,
                ethereumAddress: strongSelf.ethereumAddress
            )
        }
    }

    func presentLearnMore() {
        guard let displayInfo = displayInfo, let url = URL(string: displayInfo.website), let view = view else {
            return
        }

        wireframe.showWeb(url: url, from: view, style: .automatic)
    }

    func presentAdditionalBonuses() {
        guard let displayInfo = displayInfo else { return }

        let contributionDecimal = inputResult?.absoluteValue(from: balanceMinusFee) ?? 0

        wireframe.showAdditionalBonus(
            from: view,
            for: displayInfo,
            inputAmount: contributionDecimal,
            delegate: self,
            existingService: bonusService
        )
    }
}

extension CrowdloanContributionSetupPresenter: CrowdloanContributionSetupInteractorOutputProtocol {
    func didReceiveContribution(result: Result<CrowdloanContribution?, Error>) {
        switch result {
        case let .success(contribution):
            previousContribution = contribution

            provideCrowdloanContributionViewModel()
        case let .failure(error):
            logger?.error("Did receive contribution error: \(error)")
        }
    }

    func didReceiveCrowdloan(result: Result<Crowdloan, Error>) {
        switch result {
        case let .success(crowdloan):
            self.crowdloan = crowdloan

            provideCrowdloanContributionViewModel()
        case let .failure(error):
            logger?.error("Did receive crowdloan error: \(error)")
        }
    }

    func didReceiveDisplayInfo(result: Result<CrowdloanDisplayInfo?, Error>) {
        switch result {
        case let .success(displayInfo):
            self.displayInfo = displayInfo

            provideViewModels()
        case let .failure(error):
            logger?.error("Did receive display info error: \(error)")
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            totalBalanceValue = accountInfo?.data.total ?? 0

            balance = accountInfo.map {
                Decimal.fromSubstrateAmount($0.data.available, precision: chain.addressType.precision)
            } ?? 0.0

            provideViewModels()
        case let .failure(error):
            logger?.error("Did receive account info error: \(error)")
        }
    }

    func didReceiveBlockNumber(result: Result<BlockNumber?, Error>) {
        switch result {
        case let .success(blockNumber):
            self.blockNumber = blockNumber

            provideViewModels()
        case let .failure(error):
            logger?.error("Did receive block number error: \(error)")
        }
    }

    func didReceiveBlockDuration(result: Result<BlockTime, Error>) {
        switch result {
        case let .success(blockDuration):
            self.blockDuration = blockDuration

            provideViewModels()
        case let .failure(error):
            logger?.error("Did receive block duration error: \(error)")
        }
    }

    func didReceiveLeasingPeriod(result: Result<LeasingPeriod, Error>) {
        switch result {
        case let .success(leasingPeriod):
            self.leasingPeriod = leasingPeriod

            provideViewModels()
        case let .failure(error):
            logger?.error("Did receive leasing period error: \(error)")
        }
    }

    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData

            provideViewModels()
        case let .failure(error):
            logger?.error("Did receive price error: \(error)")
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            fee = BigUInt(dispatchInfo.fee).map {
                Decimal.fromSubstrateAmount($0, precision: chain.addressType.precision)
            } ?? nil

            provideViewModels()
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }

    func didReceiveMinimumBalance(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(minimumBalance):
            self.minimumBalance = minimumBalance

            provideViewModels()
        case let .failure(error):
            logger?.error("Did receive minimum balance error: \(error)")
        }
    }

    func didReceiveMinimumContribution(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(minimumContribution):
            self.minimumContribution = minimumContribution

            provideViewModels()
        case let .failure(error):
            logger?.error("Did receive minimum contribution error: \(error)")
        }
    }

    func didReceiveReferralEthereumAddress(address: String) {
        ethereumAddress = address
        provideEthereumAddressViewModel()
    }
}

extension CrowdloanContributionSetupPresenter: CustomCrowdloanDelegate {
    func didReceive(bonusService: CrowdloanBonusServiceProtocol) {
        self.bonusService = bonusService
        provideViewModels()
        refreshFee()
    }
}

extension CrowdloanContributionSetupPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModels()
        }
    }
}
