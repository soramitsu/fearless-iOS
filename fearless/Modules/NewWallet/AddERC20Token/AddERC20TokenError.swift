import Foundation
import SoraFoundation

enum AddERC20TokenError: Error, LocalizedError {
    case invalidAddress
    case invalidTokenData
    
    func errorDescription(locale: Locale) -> String? {
        switch self {
        case .invalidAddress:
            return R.string.localizable.addTokenInvalidAddress(preferredLanguages: locale.rLanguages)
        case .invalidTokenData:
            return R.string.localizable.addTokenInvalidData(preferredLanguages: locale.rLanguages)
        }
    }
}
