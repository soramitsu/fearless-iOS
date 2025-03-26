import Foundation
import SoraFoundation

enum AddERC20TokenError: Error, LocalizedError {
    case invalidAddress
    case invalidTokenData
    case tokenAlreadyExists
    
    var errorDescription: String? {
        let locale = LocalizationManager.shared.selectedLocale
        
        switch self {
        case .invalidAddress:
            return R.string.localizable.addTokenInvalidAddress(preferredLanguages: locale.rLanguages)
        case .invalidTokenData:
            return R.string.localizable.addTokenInvalidData(preferredLanguages: locale.rLanguages)
        case .tokenAlreadyExists:
            return R.string.localizable.addTokenAlreadyExists(preferredLanguages: locale.rLanguages)
        }
    }
}
