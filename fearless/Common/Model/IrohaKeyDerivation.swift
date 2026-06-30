import Foundation

struct IrohaDerivedAccount: Equatable {
    let derivationPath: String
    let privateKey: Data
    let chainCode: Data
    let publicKey: Data
    let publicKeyHex: String
    let canonicalHex: String
}

struct IrohaDerivedAddress: Equatable {
    let account: IrohaDerivedAccount
    let chainDiscriminant: Int
    let i105: String
}

enum IrohaKeyDerivation {
    static func deriveAccount(
        mnemonic: String,
        passphrase: String = "",
        derivationPath: String = UniversalWalletDerivationPaths.irohaDefault
    ) throws -> IrohaDerivedAccount {
        let ed25519 = try SolanaKeyDerivation.deriveAccount(
            mnemonic: mnemonic,
            passphrase: passphrase,
            derivationPath: derivationPath
        )
        let publicKeyHex = ed25519.publicKey.hexString

        return IrohaDerivedAccount(
            derivationPath: derivationPath,
            privateKey: ed25519.privateKey,
            chainCode: ed25519.chainCode,
            publicKey: ed25519.publicKey,
            publicKeyHex: publicKeyHex,
            canonicalHex: try IrohaAddressCodec.canonicalHex(publicKeyHex: publicKeyHex)
        )
    }

    static func deriveAddress(
        mnemonic: String,
        passphrase: String = "",
        derivationPath: String = UniversalWalletDerivationPaths.irohaDefault,
        chainDiscriminant: Int = UniversalWalletRegistry.taira.chainDiscriminant
    ) throws -> IrohaDerivedAddress {
        let account = try deriveAccount(
            mnemonic: mnemonic,
            passphrase: passphrase,
            derivationPath: derivationPath
        )

        return IrohaDerivedAddress(
            account: account,
            chainDiscriminant: chainDiscriminant,
            i105: try IrohaAddressCodec.encode(
                publicKeyHex: account.publicKeyHex,
                chainDiscriminant: chainDiscriminant
            )
        )
    }
}

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
