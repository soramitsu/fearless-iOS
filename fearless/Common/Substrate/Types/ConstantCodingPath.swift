import Foundation

struct ConstantCodingPath {
    let moduleName: String
    let constantName: String
}

extension ConstantCodingPath {
    static var slashDeferDuration: ConstantCodingPath {
        ConstantCodingPath(moduleName: "Staking", constantName: "SlashDeferDuration")
    }

    static var maxNominatorRewardedPerValidator: ConstantCodingPath {
        ConstantCodingPath(moduleName: "Staking", constantName: "MaxNominatorRewardedPerValidator")
    }

    static var lockUpPeriod: ConstantCodingPath {
        ConstantCodingPath(moduleName: "Staking", constantName: "BondingDuration")
    }

    static var eraLength: ConstantCodingPath {
        ConstantCodingPath(moduleName: "Staking", constantName: "SessionsPerEra")
    }

    static var maxNominations: ConstantCodingPath {
        ConstantCodingPath(moduleName: "Staking", constantName: "MaxNominations")
    }

    static var existentialDeposit: ConstantCodingPath {
        ConstantCodingPath(moduleName: "Balances", constantName: "ExistentialDeposit")
    }

    static var paraLeasingPeriod: ConstantCodingPath {
        ConstantCodingPath(moduleName: "Slots", constantName: "LeasePeriod")
    }

    static var babeBlockTime: ConstantCodingPath {
        ConstantCodingPath(moduleName: "Babe", constantName: "ExpectedBlockTime")
    }

    static var sessionLength: ConstantCodingPath {
        ConstantCodingPath(moduleName: "Babe", constantName: "EpochDuration")
    }

    static var minimumPeriodBetweenBlocks: ConstantCodingPath {
        ConstantCodingPath(moduleName: "Timestamp", constantName: "MinimumPeriod")
    }

    static var minimumContribution: ConstantCodingPath {
        ConstantCodingPath(moduleName: "Crowdloan", constantName: "MinContribution")
    }

    static var blockWeights: ConstantCodingPath {
        ConstantCodingPath(moduleName: "System", constantName: "BlockWeights")
    }

    static var blockHashCount: ConstantCodingPath {
        ConstantCodingPath(moduleName: "System", constantName: "BlockHashCount")
    }
}
