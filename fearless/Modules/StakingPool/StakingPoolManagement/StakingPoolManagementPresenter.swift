import Foundation
import SoraFoundation
import BigInt

enum PoolAccount: UInt8 {
    case stash = 0
    case rewards = 1
}

final class StakingPoolManagementPresenter {
    // MARK: Private properties

    private weak var view: StakingPoolManagementViewInput?
    private let router: StakingPoolManagementRouterInput
    private let interactor: StakingPoolManagementInteractorInput
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let viewModelFactory: StakingPoolManagementViewModelFactoryProtocol
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let logger: LoggerProtocol
    private var rewardCalculator: StakinkPoolRewardCalculatorProtocol

    private var balance: Decimal?
    private var stakeInfo: StakingPoolMember?
    private var priceData: PriceData?
    private var eraStakersInfo: EraStakersInfo?
    private var stakingDuration: StakingDuration?
    private var stakingPool: StakingPool?
    private var palletId: Data?
    private var poolAccountInfo: AccountInfo?
    private var poolRewards: StakingPoolRewards?
    private var existentialDeposit: BigUInt?
    private var totalRewardsDecimal: Decimal?

    private var electedValidators: [ElectedValidatorInfo]?

    // MARK: - Constructors

    init(
        interactor: StakingPoolManagementInteractorInput,
        router: StakingPoolManagementRouterInput,
        localizationManager: LocalizationManagerProtocol,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        viewModelFactory: StakingPoolManagementViewModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        rewardCalculator: StakinkPoolRewardCalculatorProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.viewModelFactory = viewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.logger = logger
        self.rewardCalculator = rewardCalculator
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let viewModel = viewModelFactory.buildViewModel(stakeInfo: stakeInfo, era: eraStakersInfo?.activeEra)
        view?.didReceive(viewModel: viewModel)
    }

    private func provideBalanceViewModel() {
        guard let balance = balance else {
            return
        }

        let balanceViewModel = balanceViewModelFactory.balanceFromPrice(balance, priceData: priceData)
        view?.didReceive(balanceViewModel: balanceViewModel.value(for: selectedLocale))
    }

    private func provideUnstakingViewModel() {
        guard let era = eraStakersInfo?.activeEra,
              let stakeInfo = stakeInfo,
              let unstakingAmount = Decimal.fromSubstrateAmount(
                  stakeInfo.unbonding(inEra: era),
                  precision: Int16(chainAsset.asset.precision)
              ) else {
            view?.didReceive(unstakingViewModel: nil)
            return
        }

        let unstakingViewModel = balanceViewModelFactory.balanceFromPrice(unstakingAmount, priceData: priceData)
        view?.didReceive(unstakingViewModel: unstakingViewModel.value(for: selectedLocale))
    }

    private func provideStakeAmountViewModel() {
        guard let stakeInfo = stakeInfo,
              let stakedAmount = Decimal.fromSubstrateAmount(
                  stakeInfo.points,
                  precision: Int16(chainAsset.asset.precision)
              ) else {
            return
        }

        let viewModel = viewModelFactory.createStakedAmountViewModel(stakedAmount)
        view?.didReceive(stakedAmountString: viewModel.value(for: selectedLocale))
    }

    private func provideRedeemDelayViewModel() {
        let viewModel = viewModelFactory.buildUnstakeViewModel(unstakePeriod: stakingDuration?.unlocking)
        view?.didReceive(redeemDelayViewModel: viewModel)
    }

    private func provideRedeemableViewModel() {
        guard let era = eraStakersInfo?.activeEra,
              let claimable = stakeInfo?.redeemable(inEra: era),
              let claimableDecimal = Decimal.fromSubstrateAmount(
                  claimable,
                  precision: Int16(chainAsset.asset.precision)
              ),
              claimableDecimal > 0 else {
            return
        }

        let viewModel = balanceViewModelFactory.balanceFromPrice(claimableDecimal, priceData: priceData)

        view?.didReceive(redeemableViewModel: viewModel.value(for: selectedLocale))
    }

    private func provideClaimableViewModel() {
        guard
            let stakeInfo = stakeInfo,
            let poolRewards = poolRewards,
            let poolInfo = stakingPool,
            let poolAccountInfo = poolAccountInfo,
            let existentialDeposit = existentialDeposit
        else {
            view?.didReceive(claimableViewModel: nil)
            return
        }

        let rewards = rewardCalculator.calculate(
            wallet: wallet,
            chainAsset: chainAsset,
            poolInfo: poolInfo,
            poolAccountInfo: poolAccountInfo,
            poolRewards: poolRewards,
            stakeInfo: stakeInfo,
            existentialDeposit: existentialDeposit,
            priceData: priceData,
            locale: selectedLocale
        )

        guard !rewards.totalRewardsDecimal.isZero else {
            view?.didReceive(claimableViewModel: nil)
            return
        }

        view?.didReceive(claimableViewModel: rewards.totalRewards)
        totalRewardsDecimal = rewards.totalRewardsDecimal
    }

    private func presentStakingPoolInfo() {
        guard let stakingPool = stakingPool else {
            return
        }

        router.presentPoolInfo(
            stakingPool: stakingPool,
            chainAsset: chainAsset,
            wallet: wallet,
            from: view
        )
    }

    private func fetchPoolBalance() {
        guard let poolAccountId = fetchPoolAccount(for: .rewards) else {
            return
        }

        interactor.fetchPoolBalance(poolAccountId: poolAccountId)
    }

    private func fetchSelectedValidators() {
        guard
            let stashAccount = fetchPoolAccount(for: .stash),
            let electedValidators = electedValidators
        else {
            return
        }

        let selectedValidators = electedValidators.map { validator in
            validator.toSelected(for: try? stashAccount.toAddress(using: chainAsset.chain.chainFormat))
        }.filter { $0.isActive }

        view?.didReceiveSelectValidator(visible: selectedValidators.isEmpty)
    }

    private func fetchActiveValidators() {
        guard
            let stash = fetchPoolAccount(for: .stash),
            let stashAddress = try? stash.toAddress(using: chainAsset.chain.chainFormat)
        else {
            return
        }

        interactor.fetchActiveValidators(for: stashAddress)
    }

    private func fetchPoolAccount(for type: PoolAccount) -> AccountId? {
        guard
            let modPrefix = "modl".data(using: .utf8),
            let palletIdData = palletId,
            let poolId = stakingPool?.id,
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
}

// MARK: - StakingPoolManagementViewOutput

extension StakingPoolManagementPresenter: StakingPoolManagementViewOutput {
    func didTapSelectValidators() {
        guard
            let stakeInfo = stakeInfo,
            let stakedAmount = Decimal.fromSubstrateAmount(
                stakeInfo.points,
                precision: Int16(chainAsset.asset.precision)
            ),
            let payoutAccount = wallet.fetch(for: chainAsset.chain.accountRequest())
        else {
            return
        }

        let state = InitiatedBonding(
            amount: stakedAmount,
            rewardDestination: .payout(account: payoutAccount)
        )

        router.proceedToSelectValidatorsStart(
            from: view,
            poolId: stakeInfo.poolId.value,
            state: state,
            chainAsset: chainAsset,
            wallet: wallet
        )
    }

    func didLoad(view: StakingPoolManagementViewInput) {
        self.view = view
        interactor.setup(with: self)
    }

    func didTapCloseButton() {
        router.dismiss(view: view)
    }

    func didTapStakeMoreButton() {
        router.presentStakeMoreFlow(
            flow: .pool,
            chainAsset: chainAsset,
            wallet: wallet,
            from: view
        )
    }

    func didTapUnstakeButton() {
        router.presentUnbondFlow(
            flow: .pool,
            chainAsset: chainAsset,
            wallet: wallet,
            from: view
        )
    }

    func didTapOptionsButton() {
        let validatorsOptionViewModel = TitleWithSubtitleViewModel(
            title: R.string.localizable.stakingValidatorNominators(preferredLanguages: selectedLocale.rLanguages)
        )
        let poolInfoOptionViewModel = TitleWithSubtitleViewModel(
            title: R.string.localizable.poolCommon(preferredLanguages: selectedLocale.rLanguages).capitalized
        )

        let viewModels = [validatorsOptionViewModel, poolInfoOptionViewModel]

        router.presentOptions(viewModels: viewModels, callback: { [weak self] selectedOption in
            if selectedOption == viewModels.firstIndex(of: validatorsOptionViewModel) {}

            if selectedOption == viewModels.firstIndex(of: poolInfoOptionViewModel) {
                self?.presentStakingPoolInfo()
            }
        }, from: view)
    }

    func didTapClaimButton() {
        guard let totalRewardsDecimal = totalRewardsDecimal else {
            return
        }
        router.presentClaim(
            rewardAmount: totalRewardsDecimal,
            chainAsset: chainAsset,
            wallet: wallet,
            from: view
        )
    }

    func didTapRedeemButton() {
        router.presentRedeemFlow(
            flow: .pool,
            chainAsset: chainAsset,
            wallet: wallet,
            from: view
        )
    }
}

// MARK: - StakingPoolManagementInteractorOutput

extension StakingPoolManagementPresenter: StakingPoolManagementInteractorOutput {
    func didReceive(poolAccountInfo: AccountInfo?) {
        self.poolAccountInfo = poolAccountInfo
        provideClaimableViewModel()
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            if let balance = accountInfo?.data.available {
                self.balance = Decimal.fromSubstrateAmount(
                    balance,
                    precision: Int16(chainAsset.asset.precision)
                )
                provideBalanceViewModel()
            }
        case let .failure(error):
            logger.error(error.localizedDescription)
        }
    }

    func didReceive(priceData: PriceData?) {
        self.priceData = priceData

        provideBalanceViewModel()
        provideUnstakingViewModel()
    }

    func didReceive(priceError _: Error) {}

    func didReceive(stakeInfo: StakingPoolMember?) {
        self.stakeInfo = stakeInfo
        provideUnstakingViewModel()
        provideStakeAmountViewModel()
        provideRedeemableViewModel()
        provideClaimableViewModel()
        provideViewModel()
    }

    func didReceive(stakeInfoError _: Error) {}

    func didReceive(eraStakersInfo: EraStakersInfo) {
        self.eraStakersInfo = eraStakersInfo
        provideUnstakingViewModel()
        provideRedeemableViewModel()
        provideClaimableViewModel()
        provideViewModel()
    }

    func didReceive(eraCountdownResult _: Result<EraCountdown, Error>) {}

    func didReceive(eraStakersInfoError _: Error) {}

    func didReceive(stakingPool: StakingPool?) {
        self.stakingPool = stakingPool
        fetchPoolBalance()
        fetchSelectedValidators()
        fetchActiveValidators()
        view?.didReceive(poolName: stakingPool?.name)
    }

    func didReceive(error: Error) {
        logger.error(error.localizedDescription)
    }

    func didReceive(stakingDuration: StakingDuration) {
        self.stakingDuration = stakingDuration
        provideRedeemDelayViewModel()
    }

    func didReceive(poolRewards: StakingPoolRewards?) {
        self.poolRewards = poolRewards
        provideClaimableViewModel()
    }

    func didReceive(poolRewardsError _: Error) {}

    func didReceive(palletIdResult: Result<Data, Error>) {
        switch palletIdResult {
        case let .success(palletId):
            self.palletId = palletId
            fetchPoolBalance()
            fetchActiveValidators()
        case let .failure(error):
            logger.error(error.localizedDescription)
        }
    }

    func didReceive(existentialDepositResult: Result<BigUInt, Error>) {
        switch existentialDepositResult {
        case let .success(existentialDeposit):
            self.existentialDeposit = existentialDeposit
            provideClaimableViewModel()
        case let .failure(error):
            logger.error(error.localizedDescription)
        }
    }

    func didReceiveValidators(result: Result<[ElectedValidatorInfo], Error>) {
        switch result {
        case let .success(electedValidators):
            self.electedValidators = electedValidators
            fetchSelectedValidators()
        case let .failure(error):
            logger.error(error.localizedDescription)
        }
    }
}

// MARK: - Localizable

extension StakingPoolManagementPresenter: Localizable {
    func applyLocalization() {}
}

extension StakingPoolManagementPresenter: StakingPoolManagementModuleInput {}
