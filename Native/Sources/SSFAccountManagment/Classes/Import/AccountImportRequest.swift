import Foundation
import IrohaCrypto
import SSFModels
import SSFUtils

public struct MetaAccountImportMnemonicRequest {
    let mnemonic: IRMnemonicProtocol
    let username: String
    let substrateDerivationPath: String
    let ethereumDerivationPath: String
    let cryptoType: CryptoType
    let defaultChainId: ChainModel.Id?
}

public struct MetaAccountImportSeedRequest {
    let substrateSeed: String
    let ethereumSeed: String?
    let username: String
    let substrateDerivationPath: String
    let ethereumDerivationPath: String?
    let cryptoType: CryptoType
}

public struct MetaAccountImportKeystoreRequest {
    let substrateKeystore: String
    let ethereumKeystore: String?
    let substratePassword: String
    let ethereumPassword: String?
    let username: String
    let cryptoType: CryptoType
}

public enum MetaAccountImportRequestSource {
    public struct MnemonicImportRequestData {
        let mnemonic: String
        let substrateDerivationPath: String
        let ethereumDerivationPath: String

        public init(
            mnemonic: String,
            substrateDerivationPath: String,
            ethereumDerivationPath: String
        ) {
            self.mnemonic = mnemonic
            self.substrateDerivationPath = substrateDerivationPath
            self.ethereumDerivationPath = ethereumDerivationPath
        }
    }

    public struct SeedImportRequestData {
        let substrateSeed: String
        let ethereumSeed: String?
        let substrateDerivationPath: String
        let ethereumDerivationPath: String?
    }

    public struct KeystoreImportRequestData {
        let substrateKeystore: String
        let ethereumKeystore: String?
        let substratePassword: String
        let ethereumPassword: String?
    }

    case mnemonic(data: MnemonicImportRequestData)
    case seed(data: SeedImportRequestData)
    case keystore(data: KeystoreImportRequestData)
}

public struct MetaAccountImportRequest {
    let source: MetaAccountImportRequestSource
    let username: String
    let cryptoType: CryptoType
    let defaultChainId: ChainModel.Id?

    public init(
        source: MetaAccountImportRequestSource,
        username: String,
        cryptoType: CryptoType,
        defaultChainId: ChainModel.Id?
    ) {
        self.source = source
        self.username = username
        self.cryptoType = cryptoType
        self.defaultChainId = defaultChainId
    }
}

public struct ChainAccountImportMnemonicRequest {
    let mnemonic: IRMnemonicProtocol
    let username: String
    let derivationPath: String
    let cryptoType: CryptoType
    let isEthereum: Bool
    let meta: MetaAccountModel
    let chainId: ChainModel.Id
}

public struct ChainAccountImportSeedRequest {
    let seed: String
    let username: String
    let derivationPath: String
    let cryptoType: CryptoType
    let isEthereum: Bool
    let meta: MetaAccountModel
    let chainId: ChainModel.Id
}

public struct ChainAccountImportKeystoreRequest {
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
