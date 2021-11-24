import Foundation
import SoraFoundation

enum LockType: String {
    case staking
    case vesting
    case democracy = "democrac"

    static var locksOrder: [Self] = [.vesting, .staking, .democracy]

    var displayType: LocalizableResource<String> {
        LocalizableResource<String> { locale in
            switch self {
            case .vesting:
                return R.string.localizable.walletAccountLocksVesting(
                    preferredLanguages: locale.rLanguages
                )
            case .staking:
                return R.string.localizable.stakingTitle(
                    preferredLanguages: locale.rLanguages
                )
            case .democracy:
                return R.string.localizable.walletAccountLocksDemocracy(
                    preferredLanguages: locale.rLanguages
                )
            }
        }
    }
}
