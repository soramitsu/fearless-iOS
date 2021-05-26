import Foundation
import BigInt
import SoraFoundation

final class CrowdloanContributionSetupPresenter {
    weak var view: CrowdloanContributionSetupViewProtocol?
    let wireframe: CrowdloanContributionSetupWireframeProtocol
    let interactor: CrowdloanContributionSetupInteractorInputProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let contributionViewModelFactory: CrowdloanContributionViewModelFactoryProtocol
    let chain: Chain
    let logger: LoggerProtocol?

    private var crowdloan: Crowdloan?
    private var displayInfo: CrowdloanDisplayInfo?
    private var balance: Decimal?
    private var priceData: PriceData?
    private var fee: Decimal?
    private var blockNumber: BlockNumber?
    private var blockDuration: BlockTime?
    private var leasingPeriod: LeasingPeriod?

    private var inputAmount: Decimal?

    init(
        interactor: CrowdloanContributionSetupInteractorInputProtocol,
        wireframe: CrowdloanContributionSetupWireframeProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        contributionViewModelFactory: CrowdloanContributionViewModelFactoryProtocol,
        chain: Chain,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.balanceViewModelFactory = balanceViewModelFactory
        self.contributionViewModelFactory = contributionViewModelFactory
        self.chain = chain
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func provideAssetVewModel() {
        let assetViewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount ?? 0.0,
            balance: balance,
            priceData: priceData
        ).value(for: selectedLocale)

        view?.didReceiveAsset(viewModel: assetViewModel)
    }

    private func provideFeeViewModel() {
        let feeViewModel = fee
            .map { balanceViewModelFactory.balanceFromPrice($0, priceData: priceData) }?
            .value(for: selectedLocale)

        view?.didReceiveFee(viewModel: feeViewModel)
    }

    private func provideInputViewModel() {
        let inputViewModel = balanceViewModelFactory.createBalanceInputViewModel(inputAmount)
            .value(for: selectedLocale)
        view?.didReceiveInput(viewModel: inputViewModel)
    }

    private func provideCrowdloanContributionViewModel() {
        guard
            let crowdloan = crowdloan,
            let blockNumber = blockNumber,
            let blockDuration = blockDuration,
            let leasingPeriod = leasingPeriod else {
            return
        }

        let metadata = CrowdloanMetadata(
            blockNumber: blockNumber,
            blockDuration: blockDuration,
            leasingPeriod: leasingPeriod
        )

        let viewModel = contributionViewModelFactory.createCrowdloanViewModel(
            from: crowdloan,
            displayInfo: displayInfo,
            metadata: metadata,
            locale: selectedLocale
        )

        view?.didReceiveCrowdloan(viewModel: viewModel)
    }

    private func provideEstimatedRewardViewModel() {
        let viewModel = displayInfo.map {
            contributionViewModelFactory.createEstimatedRewardViewModel(
                inputAmount: inputAmount ?? 0,
                displayInfo: $0,
                locale: selectedLocale
            )
        } ?? nil

        view?.didReceiveEstimatedReward(viewModel: viewModel)
    }

    private func provideViewModels() {
        provideAssetVewModel()
        provideFeeViewModel()
        provideInputViewModel()
        provideCrowdloanContributionViewModel()
        provideEstimatedRewardViewModel()
    }

    private func refreshFee() {
        guard let amount = (inputAmount ?? 0).toSubstrateAmount(precision: chain.addressType.precision) else {
            return
        }

        interactor.estimateFee(for: amount)
    }
}

extension CrowdloanContributionSetupPresenter: CrowdloanContributionSetupPresenterProtocol {
    func setup() {
        provideViewModels()

        interactor.setup()

        refreshFee()
    }

    func selectAmountPercentage(_: Float) {}

    func updateAmount(_ newValue: Decimal) {
        inputAmount = newValue

        refreshFee()
        provideAssetVewModel()
        provideEstimatedRewardViewModel()
    }

    func proceed() {}
}

extension CrowdloanContributionSetupPresenter: CrowdloanContributionSetupInteractorOutputProtocol {
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

            provideCrowdloanContributionViewModel()
            provideEstimatedRewardViewModel()
        case let .failure(error):
            logger?.error("Did receive display info error: \(error)")
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            balance = accountInfo.map {
                Decimal.fromSubstrateAmount($0.data.available, precision: chain.addressType.precision)
            } ?? nil

            provideAssetVewModel()
            provideCrowdloanContributionViewModel()
        case let .failure(error):
            logger?.error("Did receive account info error: \(error)")
        }
    }

    func didReceiveBlockNumber(result: Result<BlockNumber?, Error>) {
        switch result {
        case let .success(blockNumber):
            self.blockNumber = blockNumber

            provideCrowdloanContributionViewModel()
        case let .failure(error):
            logger?.error("Did receive block number error: \(error)")
        }
    }

    func didReceiveBlockDuration(result: Result<BlockTime, Error>) {
        switch result {
        case let .success(blockDuration):
            self.blockDuration = blockDuration

            provideCrowdloanContributionViewModel()
        case let .failure(error):
            logger?.error("Did receive block duration error: \(error)")
        }
    }

    func didReceiveLeasingPeriod(result: Result<LeasingPeriod, Error>) {
        switch result {
        case let .success(leasingPeriod):
            self.leasingPeriod = leasingPeriod

            provideCrowdloanContributionViewModel()
        case let .failure(error):
            logger?.error("Did receive leasing period error: \(error)")
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            fee = BigUInt(dispatchInfo.fee).map {
                Decimal.fromSubstrateAmount($0, precision: chain.addressType.precision)
            } ?? nil

            provideFeeViewModel()
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }
}

extension CrowdloanContributionSetupPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModels()
        }
    }
}
