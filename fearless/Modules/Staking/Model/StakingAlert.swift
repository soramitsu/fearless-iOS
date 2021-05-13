import Foundation
import UIKit.UIImage

enum StakingAlert {
    case stakingIsInactive
}

extension StakingAlert {
    var icon: UIImage? {
        switch self {
        case .stakingIsInactive:
            return R.image.iconWarning()
        }
    }

    func title(for _: Locale) -> String {
        switch self {
        case .stakingIsInactive:
            return "Change your validators." // TODO
        }
    }

    func description(for _: Locale) -> String {
        switch self {
        case .stakingIsInactive:
            return "None of your validators were elected by network."
        }
    }
}
