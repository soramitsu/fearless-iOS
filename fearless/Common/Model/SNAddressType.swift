import Foundation
import FearlessUtils

enum SNAddressType: UInt16 {
    case polkadotMain = 0
    case polkadotSecondary = 1
    case kusamaMain = 2
    case kusamaSecondary = 3
    case genericSubstrate = 42
    case moonbeam = 1284
    case moonriver = 1285
    case moonbaseAlpha = 1287
}
