import Foundation
import BigInt
import SSFModels

final class CustomValidatorParachainListComposer {
    private let filter: CustomValidatorParachainListFilter
    private let chainAsset: ChainAsset

    init(
        filter: CustomValidatorParachainListFilter,
        chainAsset: ChainAsset
    ) {
        self.filter = filter
        self.chainAsset = chainAsset
    }
}

extension CustomValidatorParachainListComposer {
    typealias RecommendableType = ParachainStakingCandidateInfo

    func compose(from validators: [ParachainStakingCandidateInfo], stakeAmount: Decimal) -> [ParachainStakingCandidateInfo] {
        var filtered = validators

        if !filter.allowsNoIdentity {
            filtered = filtered.filter {
                $0.hasIdentity
            }
        }

        if !filter.allowsOversubscribed {
            filtered = filtered.filter {
                let lowestTopDelegationAmountDecimal = Decimal.fromSubstrateAmount(
                    $0.metadata?.lowestTopDelegationAmount ?? BigUInt.zero,
                    precision: Int16(chainAsset.asset.precision)
                ) ?? 0.0

                if $0.oversubscribed {
                    return stakeAmount > lowestTopDelegationAmountDecimal
                }

                return true
            }
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
