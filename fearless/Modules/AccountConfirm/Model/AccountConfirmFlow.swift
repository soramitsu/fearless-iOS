import IrohaCrypto

enum AccountConfirmFlow {
    case wallet(MetaAccountImportMnemonicRequest)
    case chain(ChainAccountImportMnemonicRequest)

    var mnemonic: IRMnemonicProtocol {
        switch self {
        case let .wallet(request):
            return request.mnemonic
        case let .chain(request):
            return request.mnemonic
        }
    }
}
