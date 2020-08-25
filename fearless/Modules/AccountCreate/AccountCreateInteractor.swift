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

            let availableAddressTypes: [SNAddressType] = [.kusamaMain, .polkadotMain, .genericSubstrate]

            let defaultConnection = ConnectionItem.defaultConnection

            let networkType = SNAddressType(rawValue: defaultConnection.type) ?? .kusamaMain

            let metadata = AccountCreationMetadata(mnemonic: mnemonic.allWords(),
                                                   availableAddressTypes: availableAddressTypes,
                                                   defaultAddressType: networkType,
                                                   availableCryptoTypes: CryptoType.allCases,
                                                   defaultCryptoType: .sr25519)
            presenter.didReceive(metadata: metadata)
        } catch {
            presenter.didReceiveMnemonicGeneration(error: error)
        }
    }
}
