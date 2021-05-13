import Foundation

protocol RecommendationsComposing {
    func compose(from validators: [ElectedValidatorInfo]) -> [ElectedValidatorInfo]
}

final class RecommendationsComposer: RecommendationsComposing {
    let resultSize: Int
    let clusterSizeLimit: Int

    init(resultSize: Int, clusterSizeLimit: Int) {
        self.resultSize = resultSize
        self.clusterSizeLimit = clusterSizeLimit
    }

    func compose(from validators: [ElectedValidatorInfo]) -> [ElectedValidatorInfo] {
        let filtered = validators
            .filter { $0.hasIdentity && !$0.hasSlashes && !$0.oversubscribed && !$0.blocked }
            .sorted(by: { $0.stakeReturn >= $1.stakeReturn })

        var clusterCounters: [AccountAddress: UInt] = [:]

        var recommended = [ElectedValidatorInfo]()

        for validator in filtered {
            let clusterKey = validator.identity?.parentAddress ?? validator.address
            let clusterCounter = clusterCounters[clusterKey] ?? 0

            if clusterCounter < clusterSizeLimit {
                clusterCounters[clusterKey] = clusterCounter + 1
                recommended.append(validator)
            }

            if recommended.count >= resultSize {
                break
            }
        }

        return recommended
    }
}
