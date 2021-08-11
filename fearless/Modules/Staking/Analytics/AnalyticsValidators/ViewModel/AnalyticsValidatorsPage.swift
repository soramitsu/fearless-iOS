import Foundation
import SoraFoundation

enum AnalyticsValidatorsPage {
    case activity
    case rewards
}

extension AnalyticsValidatorsPage {
    func title(for _: Locale) -> String {
        switch self {
        case .activity:
            return "activity"
        case .rewards:
            return "rewards"
        }
    }
}
