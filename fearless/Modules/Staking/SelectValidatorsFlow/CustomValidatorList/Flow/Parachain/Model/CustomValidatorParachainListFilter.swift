import Foundation

struct CustomValidatorParachainListFilter: Equatable {
    var allowsNoIdentity: Bool
    var allowsOversubscribed: Bool
    var sortedBy: CustomValidatorParachainListSort

    enum CustomValidatorParachainListSort: Int, CaseIterable {
        case estimatedReward
        case effectiveAmountBonded
        case ownStake
        case delegations
        case minimumBond
    }

    internal init(
        allowsNoIdentity: Bool = true,
        allowsOversubscribed: Bool = true,
        sortedBy: CustomValidatorParachainListSort = .estimatedReward
    ) {
        self.allowsNoIdentity = allowsNoIdentity
        self.allowsOversubscribed = allowsOversubscribed
        self.sortedBy = sortedBy
    }

    static func recommendedFilter() -> CustomValidatorParachainListFilter {
        CustomValidatorParachainListFilter(
            allowsNoIdentity: false,
            allowsOversubscribed: false
        )
    }

    static func defaultFilter() -> CustomValidatorParachainListFilter {
        CustomValidatorParachainListFilter(
            allowsNoIdentity: true,
            allowsOversubscribed: true
        )
    }

    static func == (lhs: CustomValidatorParachainListFilter, rhs: CustomValidatorParachainListFilter) -> Bool {
        lhs.allowsNoIdentity == rhs.allowsNoIdentity &&
            lhs.allowsOversubscribed == rhs.allowsOversubscribed &&
            lhs.sortedBy == rhs.sortedBy
    }
}
