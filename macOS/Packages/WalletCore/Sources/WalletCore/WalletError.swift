import Foundation

/// Errors crossing the engine/UI boundary. Messages are user-facing.
public enum WalletError: Error, Hashable, Sendable, LocalizedError {
    case vaultNotInitialized
    case vaultLocked
    case wrongPassword
    case passwordTooWeak
    case biometricsUnavailable
    case biometricsCancelled
    case invalidMnemonic
    case invalidSeed
    case invalidJSON(String)
    case wrongJSONPassword
    case invalidAddress(String)
    case duplicateWallet(existing: WalletID)
    case walletNotFound
    case watchOnly
    case unsupportedChain
    case unsupportedAsset
    case network(String)
    case transferRejected(String)
    case storage(String)
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .vaultNotInitialized: return "Set an app password first."
        case .vaultLocked: return "Fearless is locked. Unlock it to continue."
        case .wrongPassword: return "That password is not correct."
        case .passwordTooWeak: return "Choose a stronger password: at least 8 characters mixing letters, numbers or symbols."
        case .biometricsUnavailable: return "Touch ID is not available for Fearless on this Mac."
        case .biometricsCancelled: return "Authentication was cancelled."
        case .invalidMnemonic: return "That recovery phrase is not valid."
        case .invalidSeed: return "That seed is not valid. Enter 32 bytes as hex."
        case .invalidJSON(let reason): return "That JSON backup cannot be read: \(reason)"
        case .wrongJSONPassword: return "The JSON backup password is not correct."
        case .invalidAddress(let reason): return reason
        case .duplicateWallet: return "This wallet is already on this Mac."
        case .walletNotFound: return "This wallet no longer exists."
        case .watchOnly: return "Watch-only wallets cannot sign."
        case .unsupportedChain: return "This network is not supported yet."
        case .unsupportedAsset: return "Sending this asset is not supported yet."
        case .network(let reason): return "Network problem: \(reason)"
        case .transferRejected(let reason): return "The network rejected the transfer: \(reason)"
        case .storage(let reason): return "Could not save wallet data: \(reason)"
        case .unknown(let reason): return reason
        }
    }
}
