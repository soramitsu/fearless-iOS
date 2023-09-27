import Foundation
import IrohaCrypto
import SSFModels

struct MetaAccountImportMnemonicRequest {
    let mnemonic: IRMnemonicProtocol
    let username: String
    let substrateDerivationPath: String
    let ethereumDerivationPath: String
    let cryptoType: CryptoType
    let defaultChainId: ChainModel.Id?
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

enum MetaAccountImportRequestSource {
    struct MnemonicImportRequestData {
        let mnemonic: IRMnemonicProtocol
        let substrateDerivationPath: String
        let ethereumDerivationPath: String
    }

    struct SeedImportRequestData {
        let substrateSeed: String
        let ethereumSeed: String?
        let substrateDerivationPath: String
        let ethereumDerivationPath: String?
    }

    struct KeystoreImportRequestData {
        let substrateKeystore: String
        let ethereumKeystore: String?
        let substratePassword: String
        let ethereumPassword: String?
    }

    case mnemonic(data: MnemonicImportRequestData)
    case seed(data: SeedImportRequestData)
    case keystore(data: KeystoreImportRequestData)
}

struct MetaAccountImportRequest {
    let source: MetaAccountImportRequestSource
    let username: String
    let cryptoType: CryptoType
    let defaultChainId: ChainModel.Id?
}

struct ChainAccountImportMnemonicRequest {
    let mnemonic: IRMnemonicProtocol
    let username: String
    let derivationPath: String
    let cryptoType: CryptoType
    let isEthereum: Bool
    let meta: MetaAccountModel
    let chainId: ChainModel.Id
}

struct ChainAccountImportSeedRequest {
    let seed: String
    let username: String
    let derivationPath: String
    let cryptoType: CryptoType
    let isEthereum: Bool
    let meta: MetaAccountModel
    let chainId: ChainModel.Id
}

struct ChainAccountImportKeystoreRequest {
    let keystore: String
    let password: String
    let username: String
    let cryptoType: CryptoType
    let isEthereum: Bool
    let meta: MetaAccountModel
    let chainId: ChainModel.Id
}

enum UniqueChainImportRequestSource {
    struct MnemonicImportRequestData {
        let mnemonic: IRMnemonicProtocol
        let derivationPath: String
    }

    struct SeedImportRequestData {
        let seed: String
        let derivationPath: String
    }

    struct KeystoreImportRequestData {
        let keystore: String
        let password: String
    }

    case mnemonic(data: MnemonicImportRequestData)
    case seed(data: SeedImportRequestData)
    case keystore(data: KeystoreImportRequestData)
}

struct UniqueChainImportRequest {
    let source: UniqueChainImportRequestSource
    let username: String
    let cryptoType: CryptoType
    let meta: MetaAccountModel
    let chain: ChainModel
}
