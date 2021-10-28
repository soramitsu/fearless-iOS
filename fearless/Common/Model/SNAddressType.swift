import Foundation
import FearlessUtils

enum SNAddressType: UInt8 {
    case polkadotMain = 0
    case polkadotSecondary = 1
    case kusamaMain = 2
    case kusamaSecondary = 3
    case genericSubstrate = 42
    #if F_DEV
        case moonbeam = 69
    #endif

    var prefix: UInt8 {
        switch self {
        #if F_DEV
            case .moonbeam:
                return 0
        #endif
        default:
            return rawValue
        }
    }
}
