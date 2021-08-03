import Foundation

enum StakingRebondOption: CaseIterable {
    case all
    case last
    case customAmount
}

extension StakingRebondOption {
    func titleForLocale(_ locale: Locale?) -> String {
        switch self {
        case .all:
            return R.string.localizable.stakingRebondAll(preferredLanguages: locale?.rLanguages)
        case .last:
            return R.string.localizable.stakingRebondLast(preferredLanguages: locale?.rLanguages)
        case .customAmount:
            return R.string.localizable.stakingRebondCustomAmount(preferredLanguages: locale?.rLanguages)
        }
    }
}
