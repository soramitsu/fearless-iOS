import Rswift
import SSFModels

enum AccountCreateChainType {
    case substrate
    case ethereum
    case both
    case universal
}

extension AccountCreateChainType {
    var includeSubstrate: Bool {
        switch self {
        case .substrate, .both:
            return true
        case .ethereum, .universal:
            return false
        }
    }

    var includeEthereum: Bool {
        switch self {
        case .ethereum, .both:
            return true
        case .substrate, .universal:
            return false
        }
    }
}

enum AccountCreationStep {
    case substrate
    case ethereum(data: SubstrateStepData)

    struct SubstrateStepData {
        let sourceType: AccountImportSource
        let source: String
        let username: String
        let password: String
        let cryptoType: CryptoType
        let derivationPath: String
    }
}
