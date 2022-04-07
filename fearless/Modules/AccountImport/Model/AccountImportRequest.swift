import Foundation
import IrohaCrypto

struct MetaAccountImportMnemonicRequest {
    let mnemonic: String
    let username: String
    let substrateDerivationPath: String
    let ethereumDerivationPath: String
    let cryptoType: CryptoType
}

struct MetaAccountImportSeedRequest {
    let substrateSeed: String
    let ethereumSeed: String?
    let username: String
    let substrateDerivationPath: String
    let ethereumDerivationPath: String?
    let cryptoType: CryptoType
}

struct MetaAccountImportKeystoreRequest {
    let substrateKeystore: String
    let ethereumKeystore: String?
    let substratePassword: String
    let ethereumPassword: String?
    let username: String
    let cryptoType: CryptoType
}

struct ChainAccountImportMnemonicRequest {
    let mnemonic: IRMnemonicProtocol
    let username: String
    let derivationPath: String
    let cryptoType: CryptoType
    let isEthereum: Bool
}

struct ChainAccountImportSeedRequest {
    let seed: String
    let username: String
    let derivationPath: String
    let cryptoType: CryptoType
    let isEthereum: Bool
}

struct ChainAccountImportKeystoreRequest {
    let keystore: String
    let password: String
    let username: String
    let cryptoType: CryptoType
    let isEthereum: Bool
}
