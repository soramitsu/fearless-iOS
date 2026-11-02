import Foundation

public enum StorageCodingPath: Equatable, CaseIterable, StorageCodingPathProtocol {
    public var moduleName: String {
        path.moduleName
    }

    public var itemName: String {
        path.itemName
    }

    public var path: (moduleName: String, itemName: String) {
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
        case .eqOraclePricePoint:
            return (moduleName: "Oracle", itemName: "PricePoints")
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
    case eqOraclePricePoint
}
