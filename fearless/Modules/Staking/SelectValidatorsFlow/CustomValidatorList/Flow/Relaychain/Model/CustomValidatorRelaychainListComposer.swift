import Foundation

class CustomValidatorRelaychainListComposer {
    let filter: CustomValidatorRelaychainListFilter

    init(
        filter: CustomValidatorRelaychainListFilter
    ) {
        self.filter = filter
    }
}

extension CustomValidatorRelaychainListComposer: RecommendationsComposing {
    typealias RecommendableType = SelectedValidatorInfo

    func compose(from validators: [RecommendableType]) -> [RecommendableType] {
        var filtered = validators

        if !filter.allowsNoIdentity {
            filtered = filtered.filter {
                $0.hasIdentity || $0.myNomination != nil
            }
        }

        if !filter.allowsOversubscribed {
            filtered = filtered.filter {
                !$0.oversubscribed || $0.myNomination != nil
            }
        }

        if !filter.allowsSlashed {
            filtered = filtered.filter {
                !$0.hasSlashes || $0.myNomination != nil
            }
        }

        let sorted: [RecommendableType]

        switch filter.sortedBy {
        case .estimatedReward:
            sorted = filtered.sorted(by: { $0.stakeReturn >= $1.stakeReturn })
        case .totalStake:
            sorted = filtered.sorted(by: { $0.totalStake >= $1.totalStake })
        case .ownStake:
            sorted = filtered.sorted(by: { $0.ownStake >= $1.ownStake })
        }

        guard case let .limited(clusterSizeLimit) = filter.allowsClusters else { return sorted }

        return processClusters(
            items: sorted,
            clusterSizeLimit: clusterSizeLimit,
            resultSize: sorted.count
        )
    }
}
