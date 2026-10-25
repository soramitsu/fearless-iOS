import Foundation

enum SelectedWalletStoreState: Equatable {
    case unresolved
    case empty
    case ready
    case unsupportedOnly
    case unavailable
}

enum SelectedWalletSettingsError: LocalizedError {
    case duplicateWalletIdentifier
    case unsupportedWalletIdentifierConflict

    var errorDescription: String? {
        switch self {
        case .duplicateWalletIdentifier:
            return "The wallet store contains duplicate identifiers"
        case .unsupportedWalletIdentifierConflict:
            return "A supported wallet conflicts with an unsupported stored wallet"
        }
    }
}
