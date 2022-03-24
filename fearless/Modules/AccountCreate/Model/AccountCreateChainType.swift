import Rswift
enum AccountCreateChainType {
    case substrate
    case ethereum
    case both
}

extension AccountCreateChainType {
    var includeSubstrate: Bool {
        switch self {
        case .substrate, .both:
            return true
        case .ethereum:
            return false
        }
    }

    var includeEthereum: Bool {
        switch self {
        case .ethereum, .both:
            return true
        case .substrate:
            return false
        }
    }
}

enum AccountCreationStep {
    case first
    case second(data: FirstStepData)

    struct FirstStepData {
        let sourceType: AccountImportSource
        let source: String
        let username: String
        let password: String
        let cryptoType: CryptoType
        let derivationPath: String
    }
}
