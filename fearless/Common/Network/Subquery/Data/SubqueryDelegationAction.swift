import Foundation

enum SubqueryDelegationAction: Int, Decodable {
    case stake = 0
    case unstake = 1
    case reward = 2
    case delegate = 3
    case unknown

    func title(locale: Locale) -> String? {
        switch self {
        case .stake:
            return R.string.localizable.stakingStake(
                preferredLanguages: locale.rLanguages
            )
        case .unstake:
            return R.string.localizable.stakingUnbond_v190(
                preferredLanguages: locale.rLanguages
            )
        case .reward:
            return R.string.localizable.stakingReward(
                preferredLanguages: locale.rLanguages
            )
        case .delegate:
            return R.string.localizable.parachainStakingDelegate(
                preferredLanguages: locale.rLanguages
            )
        case .unknown:
            return nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let value = try container.decode(Int.self)
        self = .init(rawValue: value) ?? .unknown
    }
}
