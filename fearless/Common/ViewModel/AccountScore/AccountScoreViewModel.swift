import UIKit

enum AccountScoreRate {
    case low
    case medium
    case high

    init(from score: Decimal) {
        if score < 0.25 {
            self = .low
        } else if score < 0.75 {
            self = .medium
        } else {
            self = .high
        }
    }

    var color: UIColor? {
        switch self {
        case .low:
            return R.color.colorRed()
        case .medium:
            return R.color.colorOrange()
        case .high:
            return R.color.colorGreen()
        }
    }
}

struct AccountScoreViewModel {
    let accountScoreLabelText: String
    let rate: AccountScoreRate
}
