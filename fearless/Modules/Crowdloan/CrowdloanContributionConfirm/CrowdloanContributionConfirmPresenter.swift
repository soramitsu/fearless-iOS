import Foundation
import BigInt
import SoraFoundation
import SSFModels

final class CrowdloanContributionConfirmPresenter {
    weak var view: CrowdloanContributionConfirmViewProtocol?
    let wireframe: CrowdloanContributionConfirmWireframeProtocol
    let interactor: CrowdloanContributionConfirmInteractorInputProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let contributionViewModelFactory: CrowdloanContributionViewModelFactoryProtocol
    let dataValidatingFactory: CrowdloanDataValidatorFactoryProtocol
    let inputAmount: Decimal
    let bonusRate: Decimal?
    let assetInfo: AssetBalanceDisplayInfo
    let logger: LoggerProtocol?
    let chainAsset: ChainAsset
    private var displayAddress: DisplayAddress?
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
    private var leasingOffset: LeasingOffset?

    private var crowdloanMetadata: CrowdloanMetadata? {
        if
            let blockNumber = blockNumber,
            let blockDuration = blockDuration,
            let leasingPeriod = leasingPeriod,
            let leasingOffset = leasingOffset {
            return CrowdloanMetadata(
                blockNumber: blockNumber,
                blockDuration: blockDuration,
                leasingPeriod: leasingPeriod,
                leasingOffset: leasingOffset
            )
        } else {
            return nil
        }
    }

    private var confirmationData: CrowdloanContributionConfirmData? {
        guard let displayAddress = displayAddress else {
            return nil
        }

        return CrowdloanContributionConfirmData(
            contribution: inputAmount,
            displayAddress: displayAddress
        )
    }

    init(
        interactor: CrowdloanContributionConfirmInteractorInputProtocol,
        wireframe: CrowdloanContributionConfirmWireframeProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        contributionViewModelFactory: CrowdloanContributionViewModelFactoryProtocol,
        dataValidatingFactory: CrowdloanDataValidatorFactoryProtocol,
        inputAmount: Decimal,
        bonusRate: Decimal?,
        assetInfo: AssetBalanceDisplayInfo,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil,
        chainAsset: ChainAsset
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.balanceViewModelFactory = balanceViewModelFactory
        self.contributionViewModelFactory = contributionViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.inputAmount = inputAmount
        self.bonusRate = bonusRate
        self.assetInfo = assetInfo
        self.logger = logger
        self.chainAsset = chainAsset
        self.localizationManager = localizationManager
    }

    private func provideAssetVewModel() {
        guard minimumBalance != nil else {
            return
        }

        let assetViewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount,
            balance: balance,
            priceData: priceData
        ).value(for: selectedLocale)

        view?.didReceiveAsset(viewModel: assetViewModel)
    }

    private func provideFeeViewModel() {
        let feeViewModel = fee
            .map { balanceViewModelFactory.balanceFromPrice($0, priceData: priceData, usageCase: .detailsCrypto) }?
            .value(for: selectedLocale)

        view?.didReceiveFee(viewModel: feeViewModel)
    }

    private func provideConfirmationViewModel() {
        guard
            let crowdloan = crowdloan,
            let metadata = crowdloanMetadata,
            let confirmationData = confirmationData else {
            return
        }

        let maybeViewModel = try? contributionViewModelFactory.createContributionConfirmViewModel(
            from: crowdloan,
            metadata: metadata,
            confirmationData: confirmationData,
            locale: selectedLocale
        )

        maybeViewModel.map { view?.didReceiveCrowdloan(viewModel: $0) }
    }

    private func provideEstimatedRewardViewModel() {
        let viewModel = displayInfo.map {
            contributionViewModelFactory.createEstimatedRewardViewModel(
                inputAmount: inputAmount,
                displayInfo: $0,
                locale: selectedLocale
            )
        } ?? nil

        view?.didReceiveEstimatedReward(viewModel: viewModel)
    }

    private func provideBonusViewModel() {
        let viewModel: String? = {
            if let displayInfo = displayInfo, let bonusRate = bonusRate {
                return contributionViewModelFactory.createAdditionalBonusViewModel(
                    inputAmount: inputAmount,
                    displayInfo: displayInfo,
                    bonusRate: bonusRate,
                    locale: selectedLocale
                )
            } else {
                return nil
            }
        }()

        view?.didReceiveBonus(viewModel: viewModel)
    }

    private func provideViewModels() {
        provideAssetVewModel()
        provideFeeViewModel()
        provideEstimatedRewardViewModel()
        provideBonusViewModel()
    }

    private func refreshFee() {
        guard let amount = inputAmount.toSubstrateAmount(precision: assetInfo.assetPrecision) else {
            return
        }

        interactor.estimateFee(for: amount)
    }
}

extension CrowdloanContributionConfirmPresenter: CrowdloanContributionConfirmPresenterProtocol {
    func setup() {
        provideViewModels()

        interactor.setup()

        refreshFee()
    }

    func confirm() {
        let contributionValue = inputAmount.toSubstrateAmount(precision: assetInfo.assetPrecision)
        let spendingValue = (contributionValue ?? 0) +
            (fee?.toSubstrateAmount(precision: assetInfo.assetPrecision) ?? 0)

        DataValidationRunner(validators: [
            dataValidatingFactory.crowdloanIsNotPrivate(crowdloan: crowdloan, locale: selectedLocale),

            dataValidatingFactory.has(fee: fee, locale: selectedLocale, onError: { [weak self] in
                self?.refreshFee()
            }),

            dataValidatingFactory.canPayFeeAndAmount(
                balance: balance,
                fee: fee,
                spendingAmount: inputAmount,
                locale: selectedLocale
            ),

            dataValidatingFactory.contributesAtLeastMinContribution(
                contribution: contributionValue,
                minimumBalance: minimumContribution,
                locale: selectedLocale
            ),

            dataValidatingFactory.capNotExceeding(
                contribution: contributionValue,
                raised: crowdloan?.fundInfo.raised,
                cap: crowdloan?.fundInfo.cap,
                locale: selectedLocale
            ),

            dataValidatingFactory.crowdloanIsNotCompleted(
                crowdloan: crowdloan,
                metadata: crowdloanMetadata,
                displayInfo: displayInfo,
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
            guard
                let strongSelf = self,
                let contribution = contributionValue else { return }
            strongSelf.view?.didStartLoading()
            strongSelf.interactor.submit(contribution: contribution)
        }
    }

    func presentAccountOptions() {
        guard let address = displayAddress?.address, let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chainAsset.chain,
            locale: selectedLocale
        )
    }
}

extension CrowdloanContributionConfirmPresenter: CrowdloanContributionConfirmInteractorOutputProtocol {
    func didSubmitContribution(result: Result<String, Error>) {
        view?.didStopLoading()

        switch result {
        case .success:
            wireframe.complete(on: view)
        case let .failure(error):
            guard let view = view else {
                return
            }

            if !wireframe.present(error: error, from: view, locale: selectedLocale) {
                wireframe.presentExtrinsicFailed(from: view, locale: selectedLocale)
            }
        }
    }

    func didReceiveDisplayAddress(result: Result<DisplayAddress, Error>) {
        switch result {
        case let .success(displayAddress):
            self.displayAddress = displayAddress

            provideConfirmationViewModel()
        case let .failure(error):
            logger?.error("Did receive account item error: \(error)")
        }
    }

    func didReceiveCrowdloan(result: Result<Crowdloan, Error>) {
        switch result {
        case let .success(crowdloan):
            self.crowdloan = crowdloan

            provideConfirmationViewModel()
        case let .failure(error):
            logger?.error("Did receive crowdloan error: \(error)")
        }
    }

    func didReceiveDisplayInfo(result: Result<CrowdloanDisplayInfo?, Error>) {
        switch result {
        case let .success(displayInfo):
            self.displayInfo = displayInfo

            provideEstimatedRewardViewModel()
            provideBonusViewModel()
        case let .failure(error):
            logger?.error("Did receive display info error: \(error)")
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            totalBalanceValue = accountInfo?.data.total ?? 0

            balance = accountInfo.map {
                Decimal.fromSubstrateAmount($0.data.sendAvailable, precision: assetInfo.assetPrecision)
            } ?? 0.0

            provideAssetVewModel()
        case let .failure(error):
            logger?.error("Did receive account info error: \(error)")
        }
    }

    func didReceiveBlockNumber(result: Result<BlockNumber?, Error>) {
        switch result {
        case let .success(blockNumber):
            self.blockNumber = blockNumber

            provideConfirmationViewModel()
        case let .failure(error):
            logger?.error("Did receive block number error: \(error)")
        }
    }

    func didReceiveBlockDuration(result: Result<BlockTime, Error>) {
        switch result {
        case let .success(blockDuration):
            self.blockDuration = blockDuration

            provideConfirmationViewModel()
        case let .failure(error):
            logger?.error("Did receive block duration error: \(error)")
        }
    }

    func didReceiveLeasingPeriod(result: Result<LeasingPeriod, Error>) {
        switch result {
        case let .success(leasingPeriod):
            self.leasingPeriod = leasingPeriod

            provideConfirmationViewModel()
        case let .failure(error):
            logger?.error("Did receive leasing period error: \(error)")
        }
    }

    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData

            provideAssetVewModel()
            provideFeeViewModel()
        case let .failure(error):
            logger?.error("Did receive price error: \(error)")
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            fee = BigUInt(string: dispatchInfo.fee).map {
                Decimal.fromSubstrateAmount($0, precision: assetInfo.assetPrecision)
            } ?? nil

            provideFeeViewModel()
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }

    func didReceiveMinimumBalance(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(minimumBalance):
            self.minimumBalance = minimumBalance

            provideAssetVewModel()
        case let .failure(error):
            logger?.error("Did receive minimum balance error: \(error)")
        }
    }

    func didReceiveMinimumContribution(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(minimumContribution):
            self.minimumContribution = minimumContribution

            provideAssetVewModel()
        case let .failure(error):
            logger?.error("Did receive minimum contribution error: \(error)")
        }
    }

    func didReceiveLeasingOffset(result: Result<LeasingOffset, Error>) {
        switch result {
        case let .success(leasingOffset):
            self.leasingOffset = leasingOffset

            provideConfirmationViewModel()
        case let .failure(error):
            logger?.error("Did receive leasing period error: \(error)")
        }
    }
}

extension CrowdloanContributionConfirmPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModels()
        }
    }
}
