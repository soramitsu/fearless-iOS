import Foundation

enum StorageCodingPath: Equatable, CaseIterable {
    var moduleName: String {
        path.moduleName
    }

    var itemName: String {
        path.itemName
    }

    var path: (moduleName: String, itemName: String) {
        switch self {
        case .account:
            return (moduleName: "System", itemName: "Account")
        case .tokens:
            return (moduleName: "Tokens", itemName: "Accounts")
        case .eqBalances:
            return (moduleName: "EqBalances", itemName: "Account")
        case .events:
            return (moduleName: "System", itemName: "Events")
        case .activeEra:
            return (moduleName: "Staking", itemName: "ActiveEra")
        case .currentEra:
            return (moduleName: "Staking", itemName: "CurrentEra")
        case .erasStakers:
            return (moduleName: "Staking", itemName: "ErasStakers")
        case .erasPrefs:
            return (moduleName: "Staking", itemName: "ErasValidatorPrefs")
        case .controller:
            return (moduleName: "Staking", itemName: "Bonded")
        case .stakingLedger:
            return (moduleName: "Staking", itemName: "Ledger")
        case .nominators:
            return (moduleName: "Staking", itemName: "Nominators")
        case .validatorPrefs:
            return (moduleName: "Staking", itemName: "Validators")
        case .totalIssuance:
            return (moduleName: "Balances", itemName: "TotalIssuance")
        case .identity:
            return (moduleName: "Identity", itemName: "IdentityOf")
        case .superIdentity:
            return (moduleName: "Identity", itemName: "SuperOf")
        case .slashingSpans:
            return (moduleName: "Staking", itemName: "SlashingSpans")
        case .unappliedSlashes:
            return (moduleName: "Staking", itemName: "UnappliedSlashes")
        case .minNominatorBond:
            return (moduleName: "Staking", itemName: "MinNominatorBond")
        case .counterForNominators:
            return (moduleName: "Staking", itemName: "CounterForNominators")
        case .maxNominatorsCount:
            return (moduleName: "Staking", itemName: "MaxNominatorsCount")
        case .payee:
            return (moduleName: "Staking", itemName: "Payee")
        case .totalValidatorReward:
            return (moduleName: "Staking", itemName: "ErasValidatorReward")
        case .rewardPointsPerValidator:
            return (moduleName: "Staking", itemName: "ErasRewardPoints")
        case .validatorExposureClipped:
            return (moduleName: "Staking", itemName: "ErasStakersClipped")
        case .eraStartSessionIndex:
            return (moduleName: "Staking", itemName: "ErasStartSessionIndex")
        case .currentSessionIndex:
            return (moduleName: "Session", itemName: "CurrentIndex")
        case .electionPhase:
            return (moduleName: "ElectionProviderMultiPhase", itemName: "CurrentPhase")
        case .parachains:
            return (moduleName: "Paras", itemName: "Parachains")
        case .parachainSlotLeases:
            return (moduleName: "Slots", itemName: "Leases")
        case .crowdloanFunds:
            return (moduleName: "Crowdloan", itemName: "Funds")
        case .blockNumber:
            return (moduleName: "System", itemName: "Number")
        case .currentSlot:
            return (moduleName: "Babe", itemName: "CurrentSlot")
        case .genesisSlot:
            return (moduleName: "Babe", itemName: "GenesisSlot")
        case .balanceLocks:
            return (moduleName: "Balances", itemName: "Locks")
        case .candidatePool:
            return (moduleName: "ParachainStaking", itemName: "CandidatePool")
        case .selectedCandidates:
            return (moduleName: "ParachainStaking", itemName: "SelectedCandidates")
        case .candidateInfo:
            return (moduleName: "ParachainStaking", itemName: "CandidateInfo")
        case .topDelegations:
            return (moduleName: "ParachainStaking", itemName: "TopDelegations")
        case .atStake:
            return (moduleName: "ParachainStaking", itemName: "AtStake")
        case .delegatorState:
            return (moduleName: "ParachainStaking", itemName: "DelegatorState")
        case .round:
            return (moduleName: "ParachainStaking", itemName: "Round")
        case .delegationScheduledRequests:
            return (moduleName: "ParachainStaking", itemName: "DelegationScheduledRequests")
        case .collatorCommission:
            return (moduleName: "ParachainStaking", itemName: "CollatorCommission")
        case .bottomDelegations:
            return (moduleName: "ParachainStaking", itemName: "BottomDelegations")
        case .staked:
            return (moduleName: "ParachainStaking", itemName: "Staked")
        case .currentBlock:
            return (moduleName: "System", itemName: "Number")
        case .bondedPools:
            return (moduleName: "NominationPools", itemName: "BondedPools")
        case .stakingPoolMetadata:
            return (moduleName: "NominationPools", itemName: "Metadata")
        case .stakingPoolMinJoinBond:
            return (moduleName: "NominationPools", itemName: "MinJoinBond")
        case .stakingPoolMinCreateBond:
            return (moduleName: "NominationPools", itemName: "MinCreateBond")
        case .stakingPoolMembers:
            return (moduleName: "NominationPools", itemName: "PoolMembers")
        case .stakingPoolMaxPools:
            return (moduleName: "NominationPools", itemName: "MaxPools")
        case .stakingPoolMaxPoolMembersPerPool:
            return (moduleName: "NominationPools", itemName: "MaxPoolMembersPerPool")
        case .stakingPoolMaxPoolMembers:
            return (moduleName: "NominationPools", itemName: "MaxPoolMembers")
        case .stakingPoolCounterForBondedPools:
            return (moduleName: "NominationPools", itemName: "CounterForBondedPools")
        case .stakingPoolRewards:
            return (moduleName: "NominationPools", itemName: "RewardPools")
        case .stakingPoolLastPoolId:
            return (moduleName: "NominationPools", itemName: "LastPoolId")
        case .polkaswapTbcPool:
            return (moduleName: "NominationPools", itemName: "RewardPools")
        case .polkaswapXykPool:
            return (moduleName: "MulticollateralBondingCurvePool", itemName: "CollateralReserves")
        case .polkaswapDexManagerDesInfos:
            return (moduleName: "DexManager", itemName: "DexInfos")
        case .eqOraclePricePoint:
            return (moduleName: "Oracle", itemName: "PricePoints")
        case .assetsAccount:
            return (moduleName: "Assets", itemName: "Account")
        case .assetsAssetDetail:
            return (moduleName: "Assets", itemName: "Asset")
        case .vestingSchedule:
            return (moduleName: "Vesting", itemName: "VestingSchedules")
        case .tokensLocks:
            return (moduleName: "Tokens", itemName: "Locks")
        case .vestingVesting:
            return (moduleName: "Vesting", itemName: "Vesting")
        case .erasRewardPoints:
            return (moduleName: "Staking", itemName: "ErasRewardPoints")
        case .erasTotalStake:
            return (moduleName: "Staking", itemName: "ErasTotalStake")
        case .erasValidatorReward:
            return (moduleName: "Staking", itemName: "ErasValidatorReward")
        }
    }

    case account
    case tokens
    case eqBalances
    case events
    case activeEra
    case currentEra
    case erasStakers
    case erasPrefs
    case controller
    case stakingLedger
    case nominators
    case validatorPrefs
    case totalIssuance
    case identity
    case superIdentity
    case slashingSpans
    case unappliedSlashes
    case minNominatorBond
    case counterForNominators
    case maxNominatorsCount
    case payee
    case totalValidatorReward
    case rewardPointsPerValidator
    case validatorExposureClipped
    case eraStartSessionIndex
    case currentSessionIndex
    case electionPhase
    case parachains
    case parachainSlotLeases
    case crowdloanFunds
    case blockNumber
    case currentSlot
    case genesisSlot
    case balanceLocks
    case candidatePool
    case selectedCandidates
    case candidateInfo
    case topDelegations
    case atStake
    case delegatorState
    case round
    case delegationScheduledRequests
    case collatorCommission
    case bottomDelegations
    case staked
    case currentBlock
    case bondedPools
    case stakingPoolMetadata
    case stakingPoolMinJoinBond
    case stakingPoolMinCreateBond
    case stakingPoolMembers
    case stakingPoolMaxPools
    case stakingPoolMaxPoolMembersPerPool
    case stakingPoolMaxPoolMembers
    case stakingPoolCounterForBondedPools
    case stakingPoolRewards
    case stakingPoolLastPoolId
    case polkaswapXykPool
    case polkaswapTbcPool
    case polkaswapDexManagerDesInfos
    case eqOraclePricePoint
    case assetsAccount
    case assetsAssetDetail
    case vestingSchedule
    case tokensLocks
    case vestingVesting
    case erasRewardPoints
    case erasTotalStake
    case erasValidatorReward
}
