import Foundation

final class StakingBalanceParachainViewModelState: StakingBalanceViewModelState {
    var stateListener: StakingBalanceModelStateListener?

    func setStateListener(_ stateListener: StakingBalanceModelStateListener?) {
        self.stateListener = stateListener
    }

    func stakeMoreValidators(using _: Locale) -> [DataValidating] {
        []
    }

    func stakeLessValidators(using _: Locale) -> [DataValidating] {
        []
    }

    func revokeValidators(using _: Locale) -> [DataValidating] {
        []
    }

    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    private(set) var collator: ParachainStakingCandidateInfo
    private(set) var delegation: ParachainStakingDelegation

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        collator: ParachainStakingCandidateInfo,
        delegation: ParachainStakingDelegation
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.dataValidatingFactory = dataValidatingFactory
        self.collator = collator
        self.delegation = delegation
    }
}

extension StakingBalanceParachainViewModelState: StakingBalanceParachainStrategyOutput {}
