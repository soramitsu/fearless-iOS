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
                accountId: String,
                assetId: String,
                delegate: ContactViewModelDelegate?) -> [ContactViewModelProtocol]? {
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
                                                   delegate: delegate) else {
                return nil
            }

            return [viewModel]
        } catch {
            return nil
        }

    }
}
