import UIKit
import IrohaCrypto
import RobinHood

extension SelectConnection {
    final class AccountCreateInteractor: AccountCreateInteractorInputProtocol {
        weak var presenter: AccountCreateInteractorOutputProtocol!

        let mnemonicCreator: IRMnemonicCreatorProtocol
        let connection: ConnectionItem

        init(mnemonicCreator: IRMnemonicCreatorProtocol, connection: ConnectionItem) {
            self.mnemonicCreator = mnemonicCreator
            self.connection = connection
        }

        func setup() {
            do {
                let mnemonic = try mnemonicCreator.randomMnemonic(.entropy128)

                let metadata = AccountCreationMetadata(mnemonic: mnemonic.allWords(),
                                                       availableNetworks: [connection.type.chain],
                                                       defaultNetwork: connection.type.chain,
                                                       availableCryptoTypes: CryptoType.allCases,
                                                       defaultCryptoType: .sr25519)
                presenter.didReceive(metadata: metadata)
            } catch {
                presenter.didReceiveMnemonicGeneration(error: error)
            }
        }
    }
}
