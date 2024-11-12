import Rswift
import SSFModels

enum AccountCreateChainType {
    case substrate
    case ethereum
    case both
    case ton
}

extension AccountCreateChainType {
    var includeSubstrate: Bool {
        switch self {
        case .substrate, .both:
            return true
        case .ethereum, .ton:
            return false
        }
    }

    var includeEthereum: Bool {
        switch self {
        case .ethereum, .both, .ton:
            return true
        case .substrate:
            return false
        }
    }
}

enum AccountCreationStep {
    case ton
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
