import Foundation

enum StakingRebondOption: CaseIterable {
    case all
    case last
    case customAmount
}

extension StakingRebondOption {
    func titleForLocale(_: Locale?) -> String {
        switch self {
        case .all:
            return "Rebond all"
        case .last:
            return "Rebond last"
        case .customAmount:
            return "Rebond custom amount"
        }
    }
}
