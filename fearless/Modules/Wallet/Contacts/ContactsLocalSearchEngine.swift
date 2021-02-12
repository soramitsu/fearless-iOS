import Foundation
import CommonWallet
import IrohaCrypto
import FearlessUtils
import RobinHood
import SoraFoundation

class ContactsViewModelDelegateProxy: ContactViewModelDelegate {
    let callee: ContactViewModelDelegate?
    let localizationManager: LocalizationManagerProtocol = LocalizationManager.shared
    let logger = Logger.shared

    init(callee: ContactViewModelDelegate?) {
        self.callee = callee
    }

    func didSelect(contact: ContactViewModelProtocol) {
        callee?.didSelect(contact: contact)
    }
}

final class ContactsLocalSearchEngine: ContactsLocalSearchEngineProtocol {
    let contactViewModelFactory: ContactsFactoryWrapperProtocol
    let networkType: SNAddressType

    private lazy var addressFactory = SS58AddressFactory()

    init(networkType: SNAddressType, contactViewModelFactory: ContactsFactoryWrapperProtocol) {
        self.contactViewModelFactory = contactViewModelFactory
        self.networkType = networkType
    }

    func search(query: String,
                accountId: String,
                assetId: String,
                delegate: ContactViewModelDelegate?,
                commandFactory: WalletCommandFactoryProtocol) -> [ContactViewModelProtocol]? {
        do {
            let peerId = try addressFactory.accountId(fromAddress: query, type: networkType)
            let accountIdData = try Data(hexString: accountId)

            guard peerId != accountIdData  else {
                return []
            }

            let searchData = SearchData(accountId: peerId.toHex(),
                                        firstName: query,
                                        lastName: "")

            guard let viewModel = contactViewModelFactory
                    .createContactViewModelFromContact(searchData,
                                                       accountId: accountId,
                                                       assetId: assetId,
                                                       delegate: delegate,
                                                       commandFactory: commandFactory) else {
                return nil
            }

            return [viewModel]
        } catch {
            return nil
        }

    }
}
