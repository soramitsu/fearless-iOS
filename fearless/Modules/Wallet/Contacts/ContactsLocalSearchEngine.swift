import Foundation
import CommonWallet
import IrohaCrypto
import FearlessUtils

final class ContactsLocalSearchEngine: ContactsLocalSearchEngineProtocol {
    let contactViewModelFactory: ContactsFactoryWrapperProtocol
    let networkType: SNAddressType

    private lazy var addressFactory = SS58AddressFactory()

    init(networkType: SNAddressType, contactViewModelFactory: ContactsFactoryWrapperProtocol) {
        self.contactViewModelFactory = contactViewModelFactory
        self.networkType = networkType
    }

    func search(query: String,
                parameters: ContactModuleParameters,
                locale: Locale,
                delegate: ContactViewModelDelegate?,
                commandFactory: WalletCommandFactoryProtocol) -> [ContactViewModelProtocol]? {
        do {
            let peerId = try addressFactory.accountId(fromAddress: query, type: networkType)
            let accountIdData = try Data(hexString: parameters.accountId)

            guard peerId != accountIdData  else {
                return []
            }

            let searchData = SearchData(accountId: peerId.toHex(),
                                        firstName: query,
                                        lastName: "")

            guard let viewModel = contactViewModelFactory
                .createContactViewModelFromContact(searchData,
                                                   parameters: parameters,
                                                   locale: locale,
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
