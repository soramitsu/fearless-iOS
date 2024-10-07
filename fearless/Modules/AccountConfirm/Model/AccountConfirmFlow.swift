import IrohaCrypto
import SSFAccountManagment

enum AccountConfirmFlowWalletEcosystemRequest {
    case regular(MetaAccountImportMnemonicRequest)
    case ton(MetaAccountImportTonMnemonicRequest)
}

enum AccountConfirmFlow {
    case wallet(AccountConfirmFlowWalletEcosystemRequest)
    case chain(ChainAccountImportMnemonicRequest)

    var mnemonicAllWordls: [String] {
        switch self {
        case let .wallet(ecosystem):
            switch ecosystem {
            case .regular(let metaAccountImportMnemonicRequest):
                return metaAccountImportMnemonicRequest.mnemonic.allWords()
            case .ton(let metaAccountImportTonMnemonicRequest):
                return metaAccountImportTonMnemonicRequest.mnemonic.components(separatedBy: " ")
            }
        case let .chain(request):
            return request.mnemonic.allWords()
        }
    }
}
