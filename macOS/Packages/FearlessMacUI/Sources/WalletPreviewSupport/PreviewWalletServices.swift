import Foundation
import WalletCore

/// In-memory implementations of every WalletCore service with sample data,
/// for SwiftUI previews, the demo app, snapshot rendering and tests. Nothing
/// here touches the network, the keychain or the disk, and no real key is
/// ever derived.
public enum PreviewWalletServices {
    /// The app password of the sample vault.
    public static let samplePassword = "Preview-Only-2026"

    /// The BIP-39 English word list the preview uses.
    public static var wordList: [String] { PreviewBIP39.words }

    public static func make(scenario: PreviewScenario = .standard) -> WalletServices {
        let store = PreviewStore(scenario: scenario)
        return WalletServices(
            vault: PreviewVaultService(store: store),
            wallets: PreviewWalletService(store: store),
            catalog: PreviewCatalogService(store: store),
            nodes: PreviewNodeService(store: store),
            balances: PreviewBalanceService(store: store),
            prices: PreviewPriceService(store: store),
            transfers: PreviewTransferService(store: store),
            activity: PreviewActivityService(store: store)
        )
    }

    /// The public test phrase the preview hands out for a length. These are
    /// published test vectors: anyone can spend from them.
    public static func samplePhrase(_ length: MnemonicLength) -> [String] {
        PreviewBIP39.mnemonic(fromEntropy: PreviewBIP39.testEntropy(for: length))
    }
}
