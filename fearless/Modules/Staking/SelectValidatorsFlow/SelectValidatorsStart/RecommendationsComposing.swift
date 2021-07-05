import Foundation

protocol Recommendable {
    var identity: AccountIdentity? { get }
    var stakeReturn: Decimal { get }
    var totalStake: Decimal { get }
    var ownStake: Decimal { get }
    var hasIdentity: Bool { get }
    var oversubscribed: Bool { get }
    var hasSlashes: Bool { get }
    var blocked: Bool { get }
}

protocol RecommendationsComposing {
    associatedtype RecommendableType: Recommendable
    func compose(from validators: [RecommendableType]) -> [RecommendableType]
}

final class RecommendationsComposer: RecommendationsComposing {
    typealias RecommendableType = ElectedValidatorInfo

    let resultSize: Int
    let clusterSizeLimit: Int

    init(resultSize: Int, clusterSizeLimit: Int) {
        self.resultSize = resultSize
        self.clusterSizeLimit = clusterSizeLimit
    }

    func compose(from validators: [RecommendableType]) -> [RecommendableType] {
        let filtered = validators
            .filter { $0.hasIdentity && !$0.hasSlashes && !$0.oversubscribed && !$0.blocked }
            .sorted(by: { $0.stakeReturn >= $1.stakeReturn })

        var clusterCounters: [AccountAddress: UInt] = [:]

        var recommended: [RecommendableType] = []

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
