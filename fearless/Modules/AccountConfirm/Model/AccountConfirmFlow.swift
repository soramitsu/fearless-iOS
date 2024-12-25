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
            case let .regular(metaAccountImportMnemonicRequest):
                return metaAccountImportMnemonicRequest.mnemonic.allWords()
            case let .ton(metaAccountImportTonMnemonicRequest):
                return metaAccountImportTonMnemonicRequest.mnemonic.components(separatedBy: " ")
            }
        case let .chain(request):
            return request.mnemonic.allWords()
        }
    }
}
