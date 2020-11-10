import UIKit
import IrohaCrypto
import RobinHood

final class AccountCreateInteractor {
    weak var presenter: AccountCreateInteractorOutputProtocol!

    let mnemonicCreator: IRMnemonicCreatorProtocol
    let supportedAddressTypes: [SNAddressType]
    let defaultAddressType: SNAddressType

    init(mnemonicCreator: IRMnemonicCreatorProtocol,
         supportedAddressTypes: [SNAddressType],
         defaultAddressType: SNAddressType) {
        self.mnemonicCreator = mnemonicCreator
        self.supportedAddressTypes = supportedAddressTypes
        self.defaultAddressType = defaultAddressType
    }
}

extension AccountCreateInteractor: AccountCreateInteractorInputProtocol {
    func setup() {
        do {
            let mnemonic = try mnemonicCreator.randomMnemonic(.entropy128)

            let metadata = AccountCreationMetadata(mnemonic: mnemonic.allWords(),
                                                   availableAddressTypes: supportedAddressTypes,
                                                   defaultAddressType: defaultAddressType,
                                                   availableCryptoTypes: CryptoType.allCases,
                                                   defaultCryptoType: .sr25519)
            presenter.didReceive(metadata: metadata)
        } catch {
            presenter.didReceiveMnemonicGeneration(error: error)
        }
    }
}
