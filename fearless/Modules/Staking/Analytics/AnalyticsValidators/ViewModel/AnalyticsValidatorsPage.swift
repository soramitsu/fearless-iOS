import Foundation
import SoraFoundation

enum AnalyticsValidatorsPage {
    case activity
    case rewards
}

extension AnalyticsValidatorsPage {
    func title(for locale: Locale) -> String {
        switch self {
        case .activity:
            return R.string.localizable
                .stakingAnalyticsActivity(preferredLanguages: locale.rLanguages).uppercased()
        case .rewards:
            return R.string.localizable
                .stakingRewardsTitle(preferredLanguages: locale.rLanguages).uppercased()
        }
    }
}
