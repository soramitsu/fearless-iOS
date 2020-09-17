import UIKit
import IrohaCrypto
import RobinHood

final class AccountCreateInteractor {
    weak var presenter: AccountCreateInteractorOutputProtocol!

    let mnemonicCreator: IRMnemonicCreatorProtocol

    init(mnemonicCreator: IRMnemonicCreatorProtocol) {
        self.mnemonicCreator = mnemonicCreator
    }
}

extension AccountCreateInteractor: AccountCreateInteractorInputProtocol {
    func setup() {
        do {
            let mnemonic = try mnemonicCreator.randomMnemonic(.entropy128)

            let availableAddressTypes: [SNAddressType] = SNAddressType.supported

            let defaultConnection = ConnectionItem.defaultConnection

            let metadata = AccountCreationMetadata(mnemonic: mnemonic.allWords(),
                                                   availableAddressTypes: availableAddressTypes,
                                                   defaultAddressType: defaultConnection.type,
                                                   availableCryptoTypes: CryptoType.allCases,
                                                   defaultCryptoType: .sr25519)
            presenter.didReceive(metadata: metadata)
        } catch {
            presenter.didReceiveMnemonicGeneration(error: error)
        }
    }
}
