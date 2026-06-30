import Foundation

struct TonDerivedAccount: Equatable {
    let derivationPath: String
    let privateKey: Data
    let chainCode: Data
    let publicKey: Data
    let publicKeyHex: String
    let accountHash: Data
    let addressBounceable: String
    let addressNonBounceable: String
    let testnetNonBounceable: String
}

enum TonKeyDerivation {
    static func deriveAccount(
        mnemonic: String,
        passphrase: String = "",
        derivationPath: String = UniversalWalletDerivationPaths.tonDefault
    ) throws -> TonDerivedAccount {
        let ed25519 = try SolanaKeyDerivation.deriveAccount(
            mnemonic: mnemonic,
            passphrase: passphrase,
            derivationPath: derivationPath
        )
        let addresses = try TonAddressCodec.v4R2Addresses(publicKey: ed25519.publicKey)

        return TonDerivedAccount(
            derivationPath: derivationPath,
            privateKey: ed25519.privateKey,
            chainCode: ed25519.chainCode,
            publicKey: ed25519.publicKey,
            publicKeyHex: ed25519.publicKey.hexString,
            accountHash: addresses.accountHash,
            addressBounceable: addresses.bounceable,
            addressNonBounceable: addresses.nonBounceable,
            testnetNonBounceable: addresses.testnetNonBounceable
        )
    }
}

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
