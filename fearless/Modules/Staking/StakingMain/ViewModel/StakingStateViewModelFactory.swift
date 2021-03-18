import Foundation
import CommonWallet
import SoraFoundation
import BigInt
import IrohaCrypto

protocol StakingStateViewModelFactoryProtocol {
    func createViewModel(from state: StakingStateProtocol) -> StakingViewState
}

final class StakingStateViewModelFactory {
    let primitiveFactory: WalletPrimitiveFactoryProtocol
    let logger: LoggerProtocol?

    private var lastViewModel: StakingViewState = .undefined

    private var balanceViewModelFactory: BalanceViewModelFactoryProtocol?
    private var rewardViewModelFactory: RewardViewModelFactoryProtocol?
    private var cachedChain: Chain?

    private lazy var addressFactory = SS58AddressFactory()

    init(primitiveFactory: WalletPrimitiveFactoryProtocol, logger: LoggerProtocol? = nil) {
        self.primitiveFactory = primitiveFactory
        self.logger = logger
    }

    private func updateCacheForChain(_ newChain: Chain) {
        if newChain != cachedChain {
            balanceViewModelFactory = nil
            rewardViewModelFactory = nil
            cachedChain = newChain
        }
    }

    private func convertAmount(_ amount: BigUInt?,
                               for chain: Chain) -> Decimal? {
        if let amount = amount {
            return Decimal.fromSubstrateAmount(amount,
                                               precision: chain.addressType.precision)
        } else {
            return nil
        }

    }

    private func convertAmount(_ amount: BigUInt?,
                               for chain: Chain,
                               defaultValue: Decimal) -> Decimal {
        if let amount = amount {
            return Decimal.fromSubstrateAmount(amount,
                                               precision: chain.addressType.precision) ?? defaultValue
        } else {
            return defaultValue
        }

    }

    private func getBalanceViewModelFactory(for chain: Chain) -> BalanceViewModelFactoryProtocol {
        if let factory = balanceViewModelFactory {
            return factory
        }

        let factory = BalanceViewModelFactory(walletPrimitiveFactory: primitiveFactory,
                                              selectedAddressType: chain.addressType,
                                              limit: StakingConstants.maxAmount)

        self.balanceViewModelFactory = factory

        return factory
    }

    private func getRewardViewModelFactory(for chain: Chain) -> RewardViewModelFactoryProtocol {
        if let factory = rewardViewModelFactory {
            return factory
        }

        let factory = RewardViewModelFactory(walletPrimitiveFactory: primitiveFactory,
                                             selectedAddressType: chain.addressType)

        self.rewardViewModelFactory = factory

        return factory
    }

    private func createNominationStatus(for chain: Chain,
                                        commonData: StakingStateCommonData,
                                        nomination: Nomination) -> NominationViewStatus {
        guard
            let address = commonData.address,
            let eraStakers = commonData.eraStakersInfo,
            let electionStatus = commonData.electionStatus else {
            return .undefined
        }

        if case .open = electionStatus {
            return .election
        }

        do {
            let accountId = try addressFactory.accountId(from: address)

            if eraStakers.validators
                .first(where: { $0.exposure.others.contains(where: { $0.who == accountId})}) != nil {
                return .active(era: eraStakers.era)
            }

            if nomination.submittedIn >= eraStakers.era {
                return .waiting
            }

            return .inactive(era: eraStakers.era)

        } catch {
            return .undefined
        }
    }

    private func createNominationViewModel(for chain: Chain,
                                           commonData: StakingStateCommonData,
                                           ledgerInfo: DyStakingLedger,
                                           nomination: Nomination)
    -> LocalizableResource<NominationViewModelProtocol> {
        let balanceViewModelFactory = getBalanceViewModelFactory(for: chain)

        let stakedAmount = convertAmount(ledgerInfo.active, for: chain, defaultValue: 0.0)
        let staked = balanceViewModelFactory.balanceFromPrice(stakedAmount,
                                                              priceData: commonData.price)

        let rewards = balanceViewModelFactory.balanceFromPrice(0.0,
                                                               priceData: commonData.price)

        let nominationStatus = createNominationStatus(for: chain,
                                                      commonData: commonData,
                                                      nomination: nomination)

        return LocalizableResource { locale in
            let stakedViewModel = staked.value(for: locale)
            let rewardsViewModel = rewards.value(for: locale)

            return NominationViewModel(totalStakedAmount: stakedViewModel.amount,
                                       totalStakedPrice: stakedViewModel.price ?? "",
                                       totalRewardAmount: rewardsViewModel.amount,
                                       totalRewardPrice: rewardsViewModel.price ?? "",
                                       status: nominationStatus)
        }
    }

    private func createEstimationViewModel(for chain: Chain,
                                           commonData: StakingStateCommonData,
                                           amount: Decimal)
    throws -> LocalizableResource<StakingEstimationViewModelProtocol> {
        let monthlyReturn: Decimal
        let yearlyReturn: Decimal

        if let calculator = commonData.calculatorEngine {
            monthlyReturn = try calculator.calculateNetworkReturn(isCompound: true,
                                                                  period: .month)
            yearlyReturn = try calculator.calculateNetworkReturn(isCompound: true,
                                                                 period: .year)
        } else {
            monthlyReturn = 0.0
            yearlyReturn = 0.0
        }

        let balanceViewModelFactory = getBalanceViewModelFactory(for: chain)
        let rewardViewModelFactory = getRewardViewModelFactory(for: chain)

        let balance = convertAmount(commonData.accountInfo?.data.available, for: chain)

        let balanceViewModel = balanceViewModelFactory
            .createAssetBalanceViewModel(amount,
                                         balance: balance,
                                         priceData: commonData.price)

        let monthlyViewModel = rewardViewModelFactory
            .createRewardViewModel(reward: amount * monthlyReturn,
                                   targetReturn: monthlyReturn,
                                   priceData: commonData.price)

        let yearlyViewModel = rewardViewModelFactory
            .createRewardViewModel(reward: amount * yearlyReturn,
                                   targetReturn: yearlyReturn,
                                   priceData: commonData.price)

        let asset = primitiveFactory.createAssetForAddressType(chain.addressType)

        return LocalizableResource { locale in
            StakingEstimationViewModel(assetBalance: balanceViewModel.value(for: locale),
                                       monthlyReward: monthlyViewModel.value(for: locale),
                                       yearlyReward: yearlyViewModel.value(for: locale),
                                       asset: asset)
        }
    }
}

extension StakingStateViewModelFactory: StakingStateVisitorProtocol {
    func visit(state: InitialStakingState) {
        logger?.debug("Initial state")

        guard let chain = state.commonData.chain else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChain(chain)

        lastViewModel = .undefined
    }

    func visit(state: NoStashState) {
        logger?.debug("No stash state")

        guard let chain = state.commonData.chain else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChain(chain)

        do {
            let viewModel = try createEstimationViewModel(for: chain,
                                                          commonData: state.commonData,
                                                          amount: state.rewardEstimationAmount ?? 0.0)

            lastViewModel = .noStash(viewModel: viewModel)
        } catch {
            lastViewModel = .undefined
        }
    }

    func visit(state: StashState) {
        logger?.debug("Stash state")

        guard let chain = state.commonData.chain else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChain(chain)

        lastViewModel = .undefined
    }

    func visit(state: PendingBondedState) {
        logger?.debug("Pending bonded state")

        guard let chain = state.commonData.chain else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChain(chain)

        lastViewModel = .undefined
    }

    func visit(state: BondedState) {
        logger?.debug("Bonded state")

        guard let chain = state.commonData.chain else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChain(chain)

        do {
            let viewModel = try createEstimationViewModel(for: chain,
                                                          commonData: state.commonData,
                                                          amount: state.rewardEstimationAmount ?? 0.0)

            lastViewModel = .noStash(viewModel: viewModel)
        } catch {
            lastViewModel = .undefined
        }
    }

    func visit(state: PendingNominatorState) {
        logger?.debug("Pending nominator state")

        guard let chain = state.commonData.chain else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChain(chain)

        lastViewModel = .undefined
    }

    func visit(state: NominatorState) {
        logger?.debug("Nominator state")

        guard let chain = state.commonData.chain else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChain(chain)

        let viewModel = createNominationViewModel(for: chain,
                                                  commonData: state.commonData,
                                                  ledgerInfo: state.ledgerInfo,
                                                  nomination: state.nomination)

        lastViewModel = .nominator(viewModel: viewModel)
    }

    func visit(state: PendingValidatorState) {
        logger?.debug("Pending validator")

        guard let chain = state.commonData.chain else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChain(chain)

        lastViewModel = .undefined
    }

    func visit(state: ValidatorState) {
        logger?.debug("Validator state")

        guard let chain = state.commonData.chain else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChain(chain)

        lastViewModel = .validator
    }
}

extension StakingStateViewModelFactory: StakingStateViewModelFactoryProtocol {
    func createViewModel(from state: StakingStateProtocol) -> StakingViewState {
        state.accept(visitor: self)
        return lastViewModel
    }
}
