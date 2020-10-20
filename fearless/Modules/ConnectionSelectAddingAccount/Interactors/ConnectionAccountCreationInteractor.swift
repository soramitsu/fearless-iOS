import UIKit
import IrohaCrypto
import RobinHood

final class ConnectionAccountCreationInteractor {
    weak var presenter: AccountCreateInteractorOutputProtocol!

    let mnemonicCreator: IRMnemonicCreatorProtocol
    let connection: ConnectionItem

    init(mnemonicCreator: IRMnemonicCreatorProtocol, connection: ConnectionItem) {
        self.mnemonicCreator = mnemonicCreator
        self.connection = connection
    }
}

extension ConnectionAccountCreationInteractor: AccountCreateInteractorInputProtocol {
    func setup() {
        do {
            let mnemonic = try mnemonicCreator.randomMnemonic(.entropy128)

            let metadata = AccountCreationMetadata(mnemonic: mnemonic.allWords(),
                                                   availableAddressTypes: [connection.type],
                                                   defaultAddressType: connection.type,
                                                   availableCryptoTypes: CryptoType.allCases,
                                                   defaultCryptoType: .sr25519)
            presenter.didReceive(metadata: metadata)
        } catch {
            presenter.didReceiveMnemonicGeneration(error: error)
        }
    }
}
