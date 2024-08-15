import Foundation
import SoraFoundation
import BigInt
import SSFModels

enum PoolAccount: UInt8 {
    case stash = 0
    case rewards = 1
}

final class StakingPoolManagementPresenter {
    // MARK: Private properties

    private weak var view: StakingPoolManagementViewInput?
    private weak var poolInfoModuleInput: StakingPoolInfoModuleInput?
    private let router: StakingPoolManagementRouterInput
    private let interactor: StakingPoolManagementInteractorInput
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let viewModelFactory: StakingPoolManagementViewModelFactoryProtocol
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let logger: LoggerProtocol
    private var rewardCalculator: StakinkPoolRewardCalculatorProtocol
    private var status: NominationViewStatus?

    private var balance: Decimal?
    private var stakeInfo: StakingPoolMember?
    private var eraStakersInfo: EraStakersInfo?
    private var stakingDuration: StakingDuration?
    private var stakingPool: StakingPool?
    private var palletId: Data?
    private var poolAccountInfo: AccountInfo?
    private var poolRewards: StakingPoolRewards?
    private var existentialDeposit: BigUInt?
    private var totalRewardsDecimal: Decimal?
    private var nomination: Nomination?
    private var pendingRewards: BigUInt?

    private var electedValidators: [ElectedValidatorInfo]?

    private var priceData: PriceData? {
        chainAsset.asset.getPrice(for: wallet.selectedCurrency)
    }

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
        status: NominationViewStatus?,
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
        self.status = status
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let viewModel = viewModelFactory.buildViewModel(
            stakeInfo: stakeInfo,
            stakingPool: stakingPool,
            wallet: wallet
        )
        view?.didReceive(viewModel: viewModel)
    }

    private func provideBalanceViewModel() {
        guard let balance = balance else {
            return
        }

        let balanceViewModel = balanceViewModelFactory.balanceFromPrice(balance, priceData: priceData, usageCase: .detailsCrypto)
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

        let unstakingViewModel = balanceViewModelFactory.balanceFromPrice(unstakingAmount, priceData: priceData, usageCase: .detailsCrypto)
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
        let viewModel = viewModelFactory.buildUnstakeViewModel(
            stakingInfo: stakeInfo,
            activeEra: eraStakersInfo?.activeEra,
            stakingDuration: stakingDuration
        )

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

        let viewModel = balanceViewModelFactory.balanceFromPrice(claimableDecimal, priceData: priceData, usageCase: .detailsCrypto)

        view?.didReceive(redeemableViewModel: viewModel.value(for: selectedLocale))
    }

    private func provideClaimableViewModel() {
        guard let pendingRewards = pendingRewards, pendingRewards != BigUInt.zero else {
            view?.didReceive(claimableViewModel: nil)
            return
        }

        let pendingRewardsDecimal = Decimal.fromSubstrateAmount(
            pendingRewards,
            precision: Int16(chainAsset.asset.precision)
        ) ?? Decimal.zero
        let viewModel = balanceViewModelFactory.balanceFromPrice(pendingRewardsDecimal, priceData: priceData, usageCase: .detailsCrypto)

        view?.didReceive(claimableViewModel: viewModel.value(for: selectedLocale))
    }

    private func presentStakingPoolInfo() {
        guard let stakingPool = stakingPool else {
            return
        }

        let moduleInput = router.presentPoolInfo(
            stakingPool: stakingPool,
            chainAsset: chainAsset,
            wallet: wallet,
            status: status,
            from: view
        )

        poolInfoModuleInput = moduleInput
    }

    private func fetchPoolBalance() {
        guard let poolAccountId = fetchPoolAccount(for: .rewards) else {
            return
        }

        interactor.fetchPoolBalance(poolAccountId: poolAccountId)
    }

    private func fetchSelectedValidators() {
        let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId
        let userRoleCanSelectValidators = stakingPool?.info.roles.nominator == accountId

        guard
            let nomination = nomination
        else {
            view?.didReceiveSelectValidator(visible: userRoleCanSelectValidators)

            return
        }

        let shouldSelectValidators = nomination.targets.isEmpty && userRoleCanSelectValidators

        view?.didReceiveSelectValidator(visible: shouldSelectValidators)
    }

    private func providePoolNomination() {
        guard let stashAccountId = fetchPoolAccount(for: .stash) else {
            return
        }

        interactor.fetchPoolNomination(poolStashAccountId: stashAccountId)
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
            title: R.string.localizable
                .poolStakingManagementOptionNominees(preferredLanguages: selectedLocale.rLanguages)
        )
        let poolInfoOptionViewModel = TitleWithSubtitleViewModel(
            title: R.string.localizable.stakingPoolInfoTitle(preferredLanguages: selectedLocale.rLanguages).capitalized
        )

        let viewModels = [validatorsOptionViewModel, poolInfoOptionViewModel]

        router.presentOptions(viewModels: viewModels, callback: { [weak self] selectedOption in
            if selectedOption == viewModels.firstIndex(of: validatorsOptionViewModel) {
                self?.didTapSelectValidators()
            }

            if selectedOption == viewModels.firstIndex(of: poolInfoOptionViewModel) {
                self?.presentStakingPoolInfo()
            }
        }, from: view)
    }

    func didTapClaimButton() {
        guard let pendingRewards = pendingRewards,
              pendingRewards != BigUInt.zero,
              let totalRewardsDecimal = Decimal.fromSubstrateAmount(
                  pendingRewards,
                  precision: Int16(chainAsset.asset.precision)
              )
        else {
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

    func didTapPoolInfoName() {
        presentStakingPoolInfo()
    }
}

// MARK: - StakingPoolManagementInteractorOutput

extension StakingPoolManagementPresenter: StakingPoolManagementInteractorOutput {
    func didReceive(nomination: Nomination?) {
        self.nomination = nomination
        fetchSelectedValidators()
    }

    func didReceive(poolAccountInfo: AccountInfo?) {
        self.poolAccountInfo = poolAccountInfo
        provideClaimableViewModel()
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            if let balance = accountInfo?.data.stakingAvailable {
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

    func didReceive(stakeInfo: StakingPoolMember?) {
        self.stakeInfo = stakeInfo
        provideUnstakingViewModel()
        provideStakeAmountViewModel()
        provideRedeemableViewModel()
        provideClaimableViewModel()
        provideViewModel()
        provideRedeemDelayViewModel()
    }

    func didReceive(stakeInfoError _: Error) {}

    func didReceive(eraStakersInfo: EraStakersInfo) {
        self.eraStakersInfo = eraStakersInfo
        provideUnstakingViewModel()
        provideRedeemableViewModel()
        provideClaimableViewModel()
        provideViewModel()
        provideRedeemDelayViewModel()
    }

    func didReceive(eraCountdownResult _: Result<EraCountdown, Error>) {}

    func didReceive(eraStakersInfoError _: Error) {}

    func didReceive(stakingPool: StakingPool?) {
        self.stakingPool = stakingPool
        fetchPoolBalance()
        providePoolNomination()

        let name = (stakingPool?.name.isNotEmpty).orTrue() ? stakingPool?.name : stakingPool?.id
        view?.didReceive(poolName: name)
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
            providePoolNomination()
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
        case let .failure(error):
            logger.error(error.localizedDescription)
        }
    }

    func didReceive(pendingRewards: BigUInt?) {
        self.pendingRewards = pendingRewards
        provideClaimableViewModel()
    }

    func didReceive(pendingRewardsError: Error) {
        logger.error("\(pendingRewardsError)")
    }
}

// MARK: - Localizable

extension StakingPoolManagementPresenter: Localizable {
    func applyLocalization() {}
}

extension StakingPoolManagementPresenter: StakingPoolManagementModuleInput {
    func didChange(status: NominationViewStatus) {
        self.status = status
        poolInfoModuleInput?.didChange(status: status)
    }
}
