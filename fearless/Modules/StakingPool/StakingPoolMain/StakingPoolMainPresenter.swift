import Foundation
import SoraFoundation
import BigInt

final class StakingPoolMainPresenter {
    // MARK: Private properties

    private weak var view: StakingPoolMainViewInput?
    private let router: StakingPoolMainRouterInput
    private let interactor: StakingPoolMainInteractorInput
    private var balanceViewModelFactory: BalanceViewModelFactoryProtocol {
        didSet {
            viewModelFactory.replaceBalanceViewModelFactory(balanceViewModelFactory: balanceViewModelFactory)
        }
    }

    private weak var moduleOutput: StakingMainModuleOutput?
    private let viewModelFactory: StakingPoolMainViewModelFactoryProtocol
    private let logger: LoggerProtocol?

    private var wallet: MetaAccountModel
    private var chainAsset: ChainAsset
    private var accountInfo: AccountInfo?
    private var balance: Decimal?
    private var rewardCalculatorEngine: RewardCalculatorEngineProtocol?
    private var priceData: PriceData?
    private var era: EraIndex?
    private var eraStakersInfo: EraStakersInfo?
    private var eraCountdown: EraCountdown?
    private var stakeInfo: StakingPoolMember?
    private var poolInfo: StakingPool?
    private var poolRewards: StakingPoolRewards?
    private var palletId: String?
    private var poolAccountInfo: AccountInfo?

    private var inputResult: AmountInputResult?

    // MARK: - Constructors

    init(
        interactor: StakingPoolMainInteractorInput,
        router: StakingPoolMainRouterInput,
        localizationManager: LocalizationManagerProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        moduleOutput: StakingMainModuleOutput?,
        viewModelFactory: StakingPoolMainViewModelFactoryProtocol,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        logger: LoggerProtocol?
    ) {
        self.interactor = interactor
        self.router = router
        self.balanceViewModelFactory = balanceViewModelFactory
        self.moduleOutput = moduleOutput
        self.viewModelFactory = viewModelFactory
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.logger = logger
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideBalanceViewModel() {
        if let availableValue = accountInfo?.data.available {
            balance = Decimal.fromSubstrateAmount(
                availableValue,
                precision: Int16(chainAsset.asset.precision)
            )
        } else {
            balance = 0.0
        }

        let balanceViewModel = balanceViewModelFactory.balanceFromPrice(
            balance ?? 0.0,
            priceData: nil
        ).value(for: selectedLocale)

        DispatchQueue.main.async {
            self.view?.didReceiveBalanceViewModel(balanceViewModel)
        }
    }

    private func provideRewardEstimationViewModel() {
        let viewModel = viewModelFactory.createEstimationViewModel(
            for: chainAsset,
            accountInfo: accountInfo,
            amount: inputResult?.absoluteValue(from: balance ?? 0.0),
            priceData: priceData,
            calculatorEngine: rewardCalculatorEngine
        )

        DispatchQueue.main.async {
            self.view?.didReceiveEstimationViewModel(viewModel)
        }
    }

    private func provideStakeInfoViewModel() {
        guard let stakeInfo = stakeInfo,
              let poolRewards = poolRewards,
              let poolInfo = poolInfo,
              let accountInfo = accountInfo else {
            view?.didReceiveNominatorStateViewModel(nil)

            return
        }

        // TODO: existentialDeposit value
        let viewModel = viewModelFactory.buildNominatorStateViewModel(
            stakeInfo: stakeInfo,
            priceData: priceData,
            chainAsset: chainAsset,
            era: eraStakersInfo?.activeEra,
            poolRewards: poolRewards,
            poolInfo: poolInfo,
            accountInfo: accountInfo,
            existentialDeposit: BigUInt.zero
        )

        view?.didReceiveNominatorStateViewModel(viewModel)
    }

    private func fetchPoolBalance() {
        guard let modPrefix = "modl".data(using: .utf8) else {
            return
        }
        guard let palletIdString = palletId else {
            return
        }
        guard let palletIdData = try? Data(hexString: palletIdString) else {
            return
        }
        guard let poolId = poolInfo?.id else {
            return
        }
        var index = 1
        var poolIdValue = poolId
        let indexData = Data(
            bytes: &index,
            count: MemoryLayout.size(ofValue: index)
        )
        let poolIdData = Data(
            bytes: &poolIdValue,
            count: MemoryLayout.size(ofValue: poolIdValue)
        )

        let emptyH256 = Data(capacity: 32)
        let poolAccountId = modPrefix + palletIdData + indexData + poolIdData + emptyH256

        interactor.fetchPoolBalance(poolAccountId: poolAccountId)
    }
}

// MARK: - StakingPoolMainViewOutput

extension StakingPoolMainPresenter: StakingPoolMainViewOutput {
    func didLoad(view: StakingPoolMainViewInput) {
        self.view = view
        interactor.setup(with: self)

        view.didReceiveNominatorStateViewModel(nil)
    }

    func didTapSelectAsset() {
        router.showChainAssetSelection(
            from: view,
            type: .pool(chainAsset: chainAsset),
            delegate: self
        )
    }

    func didTapStartStaking() {
        router.showSetupAmount(
            from: view,
            amount: inputResult?.absoluteValue(from: balance ?? 0.0),
            chainAsset: chainAsset,
            wallet: wallet
        )
    }

    func didTapAccountSelection() {
        router.showAccountsSelection(from: view)
    }

    func performRewardInfoAction() {
        guard let rewardCalculator = rewardCalculatorEngine else {
            return
        }

        let maxReward = rewardCalculator.calculateMaxReturn(isCompound: true, period: .year)
        let avgReward = rewardCalculator.calculateAvgReturn(isCompound: true, period: .year)
        let maxRewardTitle = rewardCalculator.maxEarningsTitle(locale: selectedLocale)
        let avgRewardTitle = rewardCalculator.avgEarningTitle(locale: selectedLocale)

        router.showRewardDetails(
            from: view,
            maxReward: (maxRewardTitle, maxReward),
            avgReward: (avgRewardTitle, avgReward)
        )
    }

    func updateAmount(_ newValue: Decimal) {
        inputResult = .absolute(newValue)

        provideRewardEstimationViewModel()
    }

    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))

        provideRewardEstimationViewModel()
    }

    func networkInfoViewDidChangeExpansion(isExpanded: Bool) {
        interactor.saveNetworkInfoViewExpansion(isExpanded: isExpanded)
    }

    func didTapStakeInfoView() {
        router.showStakingManagement(chainAsset: chainAsset, wallet: wallet, from: view)
    }
}

// MARK: - StakingPoolMainInteractorOutput

extension StakingPoolMainPresenter: StakingPoolMainInteractorOutput {
    func didReceive(poolAccountInfo: AccountInfo?) {
        self.poolAccountInfo = poolAccountInfo
        provideStakeInfoViewModel()
    }

    func didReceive(palletIdResult: Result<String, Error>) {
        switch palletIdResult {
        case let .success(palletId):
            self.palletId = palletId
            fetchPoolBalance()
        case .failure:
            break
        }
    }

    func didReceive(stakingPool: StakingPool?) {
        poolInfo = stakingPool
        fetchPoolBalance()
        provideStakeInfoViewModel()
    }

    func didReceive(era: EraIndex) {
        self.era = era
    }

    func didReceive(eraStakersInfo: EraStakersInfo) {
        self.eraStakersInfo = eraStakersInfo

        provideStakeInfoViewModel()
    }

    func didReceive(eraCountdownResult: Result<EraCountdown, Error>) {
        switch eraCountdownResult {
        case let .success(eraCountdown):
            self.eraCountdown = eraCountdown
        case let .failure(error):
            break
        }
    }

    func didReceive(eraStakersInfoError _: Error) {}

    func didReceive(accountInfo: AccountInfo?) {
        self.accountInfo = accountInfo

        provideBalanceViewModel()
        provideRewardEstimationViewModel()
        provideStakeInfoViewModel()
    }

    func didReceive(balanceError _: Error) {}

    func didReceive(chainAsset: ChainAsset) {
        balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            selectedMetaAccount: wallet
        )

        self.chainAsset = chainAsset

        provideBalanceViewModel()
        provideRewardEstimationViewModel()

        view?.didReceiveChainAsset(chainAsset)
    }

    func didReceive(rewardCalculatorEngine: RewardCalculatorEngineProtocol?) {
        self.rewardCalculatorEngine = rewardCalculatorEngine

        provideRewardEstimationViewModel()
    }

    func didReceive(priceError _: Error) {}

    func didReceive(priceData: PriceData?) {
        self.priceData = priceData

        provideRewardEstimationViewModel()
        provideStakeInfoViewModel()
    }

    func didReceive(wallet: MetaAccountModel) {
        self.wallet = wallet

        balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            selectedMetaAccount: wallet
        )

        provideBalanceViewModel()
        provideRewardEstimationViewModel()
    }

    func didReceive(networkInfo: StakingPoolNetworkInfo) {
        let viewModels = viewModelFactory.buildNetworkInfoViewModels(networkInfo: networkInfo, chainAsset: chainAsset)
        view?.didReceiveNetworkInfoViewModels(viewModels)
    }

    func didReceive(networkInfoError _: Error) {}

    func didReceive(stakeInfo: StakingPoolMember?) {
        self.stakeInfo = stakeInfo
        provideStakeInfoViewModel()
    }

    func didReceive(stakeInfoError _: Error) {}

    func didReceive(poolRewards: StakingPoolRewards?) {
        self.poolRewards = poolRewards
        provideStakeInfoViewModel()
    }

    func didReceive(poolRewardsError _: Error) {}
}

// MARK: - Localizable

extension StakingPoolMainPresenter: Localizable {
    func applyLocalization() {}
}

extension StakingPoolMainPresenter: StakingPoolMainModuleInput {}

extension StakingPoolMainPresenter: AssetSelectionDelegate {
    func assetSelection(
        view _: ChainSelectionViewProtocol,
        didCompleteWith chainAsset: ChainAsset,
        context: Any?
    ) {
        guard let type = context as? AssetSelectionStakingType, let chainAsset = type.chainAsset else {
            return
        }

        interactor.save(chainAsset: chainAsset)

        switch type {
        case .normal:
            moduleOutput?.didSwitchStakingType(type)
        case .pool:
            break
        }
    }
}
