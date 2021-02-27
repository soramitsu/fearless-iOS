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
}
