struct CustomValidatorRelaychainListFilter: Equatable {
    enum ValidatorClusterLimit: Equatable {
        case unlimited
        case limited(amount: Int)
    }

    enum CustomValidatorListSort: Int, CaseIterable {
        case estimatedReward
        case totalStake
        case ownStake
    }

    var allowsNoIdentity: Bool
    var allowsSlashed: Bool
    var allowsOversubscribed: Bool
    var allowsClusters: ValidatorClusterLimit
    var sortedBy: CustomValidatorListSort

    internal init(
        allowsNoIdentity: Bool = true,
        allowsSlashed: Bool = true,
        allowsOversubscribed: Bool = true,
        allowsClusters: ValidatorClusterLimit = .unlimited,
        sortedBy: CustomValidatorListSort = .estimatedReward
    ) {
        self.allowsNoIdentity = allowsNoIdentity
        self.allowsSlashed = allowsSlashed
        self.allowsOversubscribed = allowsOversubscribed
        self.allowsClusters = allowsClusters
        self.sortedBy = sortedBy
    }

    static func recommendedFilter() -> CustomValidatorRelaychainListFilter {
        CustomValidatorRelaychainListFilter(
            allowsNoIdentity: false,
            allowsSlashed: false,
            allowsOversubscribed: false,
            allowsClusters: .limited(amount: StakingConstants.targetsClusterLimit)
        )
    }

    static func defaultFilter() -> CustomValidatorRelaychainListFilter {
        CustomValidatorRelaychainListFilter(
            allowsNoIdentity: true,
            allowsSlashed: true,
            allowsOversubscribed: true,
            allowsClusters: .unlimited
        )
    }

    static func == (lhs: CustomValidatorRelaychainListFilter, rhs: CustomValidatorRelaychainListFilter) -> Bool {
        lhs.allowsNoIdentity == rhs.allowsNoIdentity &&
            lhs.allowsSlashed == rhs.allowsSlashed &&
            lhs.allowsOversubscribed == rhs.allowsOversubscribed &&
            lhs.allowsClusters == rhs.allowsClusters &&
            lhs.sortedBy == rhs.sortedBy
    }
}
