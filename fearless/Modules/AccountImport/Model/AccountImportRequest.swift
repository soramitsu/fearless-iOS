import Foundation

struct MetaAccountImportMnemonicRequest {
    let mnemonic: String
    let username: String
    let substrateDerivationPath: String
    let ethereumDerivationPath: String
    let cryptoType: CryptoType
}

struct MetaAccountImportSeedRequest {
    let seed: String
    let username: String
    let substrateDerivationPath: String
    let ethereumDerivationPath: String
    let cryptoType: CryptoType
}

struct MetaAccountImportKeystoreRequest {
    let keystore: String
    let password: String
    let username: String
    let cryptoType: CryptoType
}

struct ChainAccountImportMnemonicRequest {
    let mnemonic: String
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
