import Foundation

enum ConstantCodingPath: CaseIterable {
    var moduleName: String {
        path.moduleName
    }

    var constantName: String {
        path.constantName
    }

    var path: (moduleName: String, constantName: String) {
        switch self {
        case .slashDeferDuration:
            return (moduleName: "Staking", constantName: "SlashDeferDuration")
        case .maxNominatorRewardedPerValidator:
            return (moduleName: "Staking", constantName: "maxExposurePageSize")
        case .lockUpPeriod:
            return (moduleName: "Staking", constantName: "BondingDuration")
        case .eraLength:
            return (moduleName: "Staking", constantName: "SessionsPerEra")
        case .maxNominations:
            return (moduleName: "Staking", constantName: "MaxNominations")
        case .existentialDeposit:
            return (moduleName: "Balances", constantName: "ExistentialDeposit")
        case .equilibriumExistentialDeposit:
            return (moduleName: "eqBalances", constantName: "ExistentialDeposit")
        case .paraLeasingPeriod:
            return (moduleName: "Slots", constantName: "LeasePeriod")
        case .babeBlockTime:
            return (moduleName: "Babe", constantName: "ExpectedBlockTime")
        case .sessionLength:
            return (moduleName: "Babe", constantName: "EpochDuration")
        case .minimumPeriodBetweenBlocks:
            return (moduleName: "Timestamp", constantName: "MinimumPeriod")
        case .minimumContribution:
            return (moduleName: "Crowdloan", constantName: "MinContribution")
        case .blockWeights:
            return (moduleName: "System", constantName: "BlockWeights")
        case .blockHashCount:
            return (moduleName: "System", constantName: "BlockHashCount")
        case .revokeDelegationDelay:
            return (moduleName: "ParachainStaking", constantName: "RevokeDelegationDelay")
        case .minDelegation:
            return (moduleName: "ParachainStaking", constantName: "MinDelegation")
        case .rewardPaymentDelay:
            return (moduleName: "ParachainStaking", constantName: "RewardPaymentDelay")
        case .maxDelegationsPerDelegator:
            return (moduleName: "ParachainStaking", constantName: "MaxDelegationsPerDelegator")
        case .maxTopDelegationsPerCandidate:
            return (moduleName: "ParachainStaking", constantName: "MaxTopDelegationsPerCandidate")
        case .maxBottomDelegationsPerCandidate:
            return (moduleName: "ParachainStaking", constantName: "MaxBottomDelegationsPerCandidate")
        case .defaultTip:
            return (moduleName: "Balances", constantName: "DefaultTip")
        case .candidateBondLessDelay:
            return (moduleName: "ParachainStaking", constantName: "CandidateBondLessDelay")
        case .nominationPoolsPalletId:
            return (moduleName: "NominationPools", constantName: "PalletId")
        case .historyDepth:
            return (moduleName: "Staking", constantName: "HistoryDepth")
        case .leaseOffset:
            return (moduleName: "Slots", constantName: "LeaseOffset")
        }
    }

    case slashDeferDuration
    case maxNominatorRewardedPerValidator
    case lockUpPeriod
    case eraLength
    case maxNominations
    case existentialDeposit
    case equilibriumExistentialDeposit
    case paraLeasingPeriod
    case babeBlockTime
    case sessionLength
    case minimumPeriodBetweenBlocks
    case minimumContribution
    case blockWeights
    case blockHashCount
    case revokeDelegationDelay
    case minDelegation
    case rewardPaymentDelay
    case maxDelegationsPerDelegator
    case maxTopDelegationsPerCandidate
    case maxBottomDelegationsPerCandidate
    case defaultTip
    case candidateBondLessDelay
    case nominationPoolsPalletId
    case historyDepth
    case leaseOffset
}
