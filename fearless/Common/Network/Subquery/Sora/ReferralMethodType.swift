import Foundation

enum ReferralMethodType: String {
    case bond = "reserve"
    case unbond = "unreserve"
    case setReferrer
    case setReferral

    init(fromRawValue: String) {
        self = ReferralMethodType(rawValue: fromRawValue) ?? .bond
    }
}
