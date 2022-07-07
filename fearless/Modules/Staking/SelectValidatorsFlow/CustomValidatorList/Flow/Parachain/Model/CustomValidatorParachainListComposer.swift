import Foundation
import BigInt

class CustomValidatorParachainListComposer {
    let filter: CustomValidatorParachainListFilter

    init(
        filter: CustomValidatorParachainListFilter
    ) {
        self.filter = filter
    }
}

extension CustomValidatorParachainListComposer {
    typealias RecommendableType = ParachainStakingCandidateInfo

    func compose(from validators: [ParachainStakingCandidateInfo]) -> [ParachainStakingCandidateInfo] {
        var filtered = validators

        if !filter.allowsNoIdentity {
            filtered = filtered.filter {
                $0.hasIdentity
            }
        } else {
            filtered = validators
        }

        if !filter.allowsOversubscribed {
            filtered = filtered.filter {
                !$0.oversubscribed
            }
        } else {
            filtered = validators
        }

        let sorted: [ParachainStakingCandidateInfo]

        switch filter.sortedBy {
        case .estimatedReward:
            sorted = filtered.sorted(by: { $0.subqueryData?.apr ?? 0.0 >= $1.subqueryData?.apr ?? 0.0 })
        case .effectiveAmountBonded:
            sorted = filtered.sorted(by: { $0.metadata?.totalCounted ?? BigUInt.zero >= $1.metadata?.totalCounted ?? BigUInt.zero })
        case .ownStake:
            sorted = filtered.sorted(by: { $0.metadata?.bond ?? BigUInt.zero >= $1.metadata?.bond ?? BigUInt.zero })
        case .delegations:
            sorted = filtered.sorted(by: { $0.metadata?.delegationCount ?? 0 > $1.metadata?.delegationCount ?? 0 })
        case .minimumBond:
            sorted = filtered.sorted(by: { $0.metadata?.lowestBottomDelegationAmount ?? BigUInt.zero >= $1.metadata?.lowestBottomDelegationAmount ?? BigUInt.zero })
        }

        return sorted
    }
}
