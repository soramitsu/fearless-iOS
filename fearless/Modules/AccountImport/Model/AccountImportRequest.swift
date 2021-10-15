import Foundation

struct AccountImportMnemonicRequest {
    let mnemonic: String
    let username: String
    let networkType: Chain
    let derivationPath: String
    let cryptoType: CryptoType
}

struct AccountImportSeedRequest {
    let seed: String
    let username: String
    let networkType: Chain
    let derivationPath: String
    let cryptoType: CryptoType
}

struct AccountImportKeystoreRequest {
    let keystore: String
    let password: String
    let username: String
    let networkType: Chain
    let cryptoType: CryptoType
}

@available(*, deprecated, message: "Use AccountImportMnemonicRequest instead")
struct ChainAccountImportMnemonicRequest {
    let mnemonic: String
    let username: String
    let networkType: Chain
    let derivationPath: String
    let cryptoType: MultiassetCryptoType
}

@available(*, deprecated, message: "Use AccountImportSeedRequest instead")
struct ChainAccountImportSeedRequest {
    let seed: String
    let username: String
    let networkType: Chain
    let derivationPath: String
    let cryptoType: MultiassetCryptoType
}

@available(*, deprecated, message: "Use AccountImportKeystoreRequest instead")
struct ChainAccountImportKeystoreRequest {
    let keystore: String
    let password: String
    let username: String
    let networkType: Chain
    let cryptoType: MultiassetCryptoType
}
