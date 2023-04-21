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
    private weak var stakingManagmentModuleInput: StakingPoolManagementModuleInput?
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
    private var palletId: Data?
    private var poolAccountInfo: AccountInfo?
    private var existentialDeposit: BigUInt?
    private var nomination: Nomination?
    private var pendingRewards: BigUInt?

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
        if let availableValue = accountInfo?.data.stakingAvailable {
            balance = Decimal.fromSubstrateAmount(
                availableValue,
                precision: Int16(chainAsset.asset.precision)
            )
        } else {
            balance = 0.0
        }

        let balanceViewModel = balanceViewModelFactory.balanceFromPrice(
            balance ?? 0.0,
            priceData: nil,
            usageCase: .listCrypto
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

    @discardableResult
    private func provideStakeInfoViewModel() -> LocalizableResource<NominationViewModelProtocol>? {
        guard let stakeInfo = stakeInfo,
              let pendingRewards = pendingRewards,
              let poolInfo = poolInfo
        else {
            view?.didReceiveNominatorStateViewModel(nil)

            return nil
        }

        let viewModel = viewModelFactory.buildNominatorStateViewModel(
            stakeInfo: stakeInfo,
            priceData: priceData,
            chainAsset: chainAsset,
            era: era,
            poolInfo: poolInfo,
            nomination: nomination,
            pendingRewards: pendingRewards
        )

        view?.didReceiveNominatorStateViewModel(viewModel)

        guard let status = viewModel?.value(for: selectedLocale).status else {
            return nil
        }
        stakingManagmentModuleInput?.didChange(status: status)

        return viewModel
    }

    private func fetchPoolNomination() {
        guard
            let poolStashAccountId = fetchPoolAccount(for: .stash) else {
            return
        }

        interactor.fetchPoolNomination(poolStashAccountId: poolStashAccountId)
    }

    private func fetchPoolBalance() {
        guard
            let poolRewardAccountId = fetchPoolAccount(for: .rewards) else {
            return
        }

        interactor.fetchPoolBalance(poolRewardAccountId: poolRewardAccountId)
    }

    private func fetchPoolAccount(for type: PoolAccount) -> AccountId? {
        guard
            let modPrefix = "modl".data(using: .utf8),
            let palletIdData = palletId,
            let poolId = poolInfo?.id,
            let poolIdUintValue = UInt(poolId)
        else {
            return nil
        }

        var index: UInt8 = type.rawValue
        var poolIdValue = poolIdUintValue
        let indexData = Data(
            bytes: &index,
            count: MemoryLayout.size(ofValue: index)
        )

        let poolIdSize = MemoryLayout.size(ofValue: poolIdValue)
        let poolIdData = Data(
            bytes: &poolIdValue,
            count: poolIdSize
        )

        let emptyH256 = [UInt8](repeating: 0, count: 32)
        let poolAccountId = modPrefix + palletIdData + indexData + poolIdData + emptyH256

        return poolAccountId[0 ... 31]
    }

    private func performChangeValidatorsAction() {
        router.showPoolValidators(
            from: view,
            chainAsset: chainAsset,
            wallet: wallet
        )
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
        router.showAccountsSelection(from: view, moduleOutput: self)
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
        let status = provideStakeInfoViewModel()?.value(for: selectedLocale).status
        let input = router.showStakingManagement(
            chainAsset: chainAsset,
            wallet: wallet,
            status: status,
            from: view
        )
        stakingManagmentModuleInput = input
    }

    func didTapStatusView() {
        switch poolInfo?.info.state {
        case .open:
            if (nomination?.targets).isNullOrEmpty != false {
                performChangeValidatorsAction()
            }
        case .blocked, .destroying:
            break
        case .none:
            break
        }
    }
}

// MARK: - StakingPoolMainInteractorOutput

extension StakingPoolMainPresenter: StakingPoolMainInteractorOutput {
    func didReceive(poolAccountInfo: AccountInfo?) {
        self.poolAccountInfo = poolAccountInfo
        provideStakeInfoViewModel()
    }

    func didReceive(palletIdResult: Result<Data, Error>) {
        switch palletIdResult {
        case let .success(palletId):
            self.palletId = palletId
            fetchPoolBalance()
            fetchPoolNomination()
        case .failure:
            break
        }
    }

    func didReceive(stakingPool: StakingPool?) {
        poolInfo = stakingPool
        fetchPoolBalance()
        fetchPoolNomination()
        provideStakeInfoViewModel()
    }

    func didReceive(era: EraIndex?) {
        self.era = era

        provideStakeInfoViewModel()
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
            logger?.error("StakingPoolMainPresenter:eraCountdownResult:error: \(error.localizedDescription)")
        }
    }

    func didReceive(accountInfo: AccountInfo?) {
        self.accountInfo = accountInfo

        provideBalanceViewModel()
        provideRewardEstimationViewModel()
        provideStakeInfoViewModel()
    }

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

    func didReceive(stakeInfo: StakingPoolMember?) {
        self.stakeInfo = stakeInfo
        provideStakeInfoViewModel()

        fetchPoolNomination()
    }

    func didReceive(poolRewards: StakingPoolRewards?) {
        self.poolRewards = poolRewards
        provideStakeInfoViewModel()
    }

    func didReceive(existentialDepositResult: Result<BigUInt, Error>) {
        switch existentialDepositResult {
        case let .success(existentialDeposit):
            self.existentialDeposit = existentialDeposit
            provideStakeInfoViewModel()
        case let .failure(error):
            logger?.error("StakingPoolMainPresenter:existentialDepositResult:error: \(error.localizedDescription)")
        }
    }

    func didReceive(nomination: Nomination?) {
        self.nomination = nomination
        provideStakeInfoViewModel()
    }

    func didReceiveError(_ error: StakingPoolMainError) {
        logger?.error("\(error)")
    }

    func didReceive(pendingRewards: BigUInt?) {
        self.pendingRewards = pendingRewards
        provideStakeInfoViewModel()
    }

    func didReceive(pendingRewardsError: Error) {
        logger?.error("\(pendingRewardsError)")
    }
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

extension StakingPoolMainPresenter: WalletsManagmentModuleOutput {
    func showAddNewWallet() {
        router.showCreateNewWallet(from: view)
    }

    func showImportWallet() {
        router.showImportWallet(from: view)
    }
}
